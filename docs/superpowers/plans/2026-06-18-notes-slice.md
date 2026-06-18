# Stash Slice 2 — Notes Implementation Plan

> **For agentic workers:** implement task-by-task; each task is TDD where testable, ends with a commit. UI tasks end with a visual screenshot verification, not just a build.

**Goal:** SQLite-backed notes with a hub Notes tab (list/create/delete) and a separate Notes editor window (title+body, color, text/todo kinds), persisted to the shared stash.db and updating live.

**Architecture:** Mirrors the Clipboard slice — a `Note` GRDB record, a `NotesStore` actor, a `@MainActor @Observable NotesViewModel` with a live `ValueObservation`, hub `NotesTab`, and a separate SwiftUI `Window` scene for the editor opened via `@Environment(\.openWindow)`.

## Global Constraints
(Same as Slice 1 — see docs/superpowers/specs/2026-06-18-hub-clipboard-slice-design.md.) Plus:
- Tests: Swift Testing; run FULL suite `cd StashApp && xcodebuild test -scheme StashApp -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO`.
- After adding files: `cd StashApp && xcodegen generate`. Don't commit generated Info.plist.
- Commit trailer: `Claude-Session: https://claude.ai/code/session_015v4jqLe8vCM5hYdh17AHWe`.
- No banner comments. Reuse `Tokens`. Sticky pastels: yellow `#fdf0c2`/`#c8642f`, peach `#fcdcc6`/`#b97a4a`, blue `#d4e4f2`/`#5b86b8`, mint `#d9ecda`/`#5e8a52`.
- SwiftUI windows/popovers must have a determinate size so List/ScrollView content renders (Slice 1 lesson). Notes window: fixed ~560×520.
- Follow the existing Clipboard files as the pattern (ClipItem/ClipboardStore/ClipboardViewModel).

---

### Task N1: Note model + ChecklistItem + NoteKind + migration v3 (TDD)

**Files:** Create `Data/NoteKind.swift`, `Data/Note.swift`; modify `Data/Database.swift` (add migration); Test `Tests/StashAppTests/NoteModelTests.swift`.

**Interfaces produced:**
- `enum NoteKind: String, Codable, Sendable { case text, todo }`
- `struct ChecklistItem: Codable, Sendable, Equatable { var t: String; var done: Bool }`
- `struct Note: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable, Equatable` — `id: String`, `title: String`, `body: String`, `color: String?`, `accent: String?`, `kind: NoteKind`, `items: [ChecklistItem]` (stored as JSON text column `items`), `onDesktop: Bool` (col `on_desktop`), `createdAt: Int64` (col `created_at`), `updatedAt: Int64` (col `updated_at`). `databaseTableName = "notes"`. CodingKeys map snake_case. NOTE: `items` is a `[ChecklistItem]` but the column is TEXT JSON — implement with a manual `databaseValue`/`fromDatabaseValue` OR store via a computed `itemsJSON: String` column property and expose `items` as a non-persisted computed accessor. Simplest reliable approach: give `Note` a stored `items: [ChecklistItem]` and conform using GRDB's `Codable` with a custom column coding that JSON-encodes arrays — but GRDB Codable stores nested arrays as JSON automatically when the column is TEXT. Verify in the test; if GRDB doesn't auto-JSON the array, fall back to a stored `itemsJSON: String` persisted column + computed `items`.

**Steps (TDD):**
1. Write `NoteModelTests.swift`:
```swift
import Testing
import GRDB
@testable import StashApp

@Test func noteRoundTripsWithItems() throws {
    let q = try DatabaseQueue()
    try StashDatabase.migrator().migrate(q)
    var n = Note(id: "n1", title: "Groceries", body: "", color: "#fdf0c2", accent: "#c8642f",
                 kind: .todo, items: [ChecklistItem(t: "milk", done: false), ChecklistItem(t: "eggs", done: true)],
                 onDesktop: false, createdAt: 1, updatedAt: 1)
    try q.write { try n.insert($0) }
    let got = try q.read { try Note.fetchOne($0, key: "n1") }
    #expect(got?.title == "Groceries")
    #expect(got?.kind == .todo)
    #expect(got?.items.count == 2)
    #expect(got?.items[1].done == true)
}

@Test func notesMigrationAddsColumnsLosslessly() throws {
    let q = try DatabaseQueue()
    try q.write { db in
        try db.execute(sql: """
            CREATE TABLE notes (id TEXT PRIMARY KEY, title TEXT NOT NULL, body TEXT NOT NULL DEFAULT '', color TEXT, updated_at INTEGER NOT NULL);
            INSERT INTO notes (id,title,body,color,updated_at) VALUES ('a','hi','b',NULL,5);
        """)
    }
    try StashDatabase.migrator().migrate(q)
    let cols = try q.read { try $0.columns(in: "notes").map(\.name) }
    #expect(Set(cols).isSuperset(of: ["id","title","body","color","updated_at","kind","items","accent","on_desktop","created_at"]))
    let still = try q.read { try Note.fetchOne($0, key: "a") }
    #expect(still?.title == "hi")
    #expect(still?.kind == .text)   // default
}
```
2. Run full suite → RED (Note undefined).
3. Implement `NoteKind.swift`, `Note.swift` (use GRDB Codable; the `items: [ChecklistItem]` array on a TEXT column is auto-JSON-encoded by GRDB's Codable support — confirm via the test; if not, switch to a persisted `itemsJSON` String + computed `items`). For the migration in `Database.swift`, add:
```swift
m.registerMigration("v3_notes_fields") { db in
    if try !db.tableExists("notes") {
        try db.create(table: "notes") { t in
            t.column("id", .text).primaryKey()
            t.column("title", .text).notNull()
            t.column("body", .text).notNull().defaults(to: "")
            t.column("color", .text)
            t.column("updated_at", .integer).notNull().defaults(to: 0)
        }
    }
    let cols = try db.columns(in: "notes").map(\.name)
    if !cols.contains("kind") { try db.alter(table: "notes") { $0.add(column: "kind", .text).notNull().defaults(to: "text") } }
    if !cols.contains("items") { try db.alter(table: "notes") { $0.add(column: "items", .text).notNull().defaults(to: "[]") } }
    if !cols.contains("accent") { try db.alter(table: "notes") { $0.add(column: "accent", .text) } }
    if !cols.contains("on_desktop") { try db.alter(table: "notes") { $0.add(column: "on_desktop", .integer).notNull().defaults(to: 0) } }
    if !cols.contains("created_at") { try db.alter(table: "notes") { $0.add(column: "created_at", .integer).notNull().defaults(to: 0) } }
}
```
(Place after the existing clipboard migrations; the migrator runs registered migrations in order.)
4. Run full suite → GREEN. 5. Commit `feat(app): add Note model + notes schema migration`.

---

### Task N2: Mirror notes schema in mcp-server/db.ts

**Files:** Modify `mcp-server/src/db.ts` notes `CREATE TABLE`.
Add the 5 columns so a Node-first DB matches:
```ts
CREATE TABLE IF NOT EXISTS notes (
  id         TEXT PRIMARY KEY,
  title      TEXT NOT NULL,
  body       TEXT NOT NULL DEFAULT '',
  color      TEXT,
  updated_at INTEGER NOT NULL,
  kind       TEXT NOT NULL DEFAULT 'text',
  items      TEXT NOT NULL DEFAULT '[]',
  accent     TEXT,
  on_desktop INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL DEFAULT 0
);
```
Verify `cd mcp-server && npm run build` (tsc exit 0). Commit `feat(mcp): sync notes schema with app`.

---

### Task N3: NotesStore actor (TDD)

**Files:** Create `Notes/NotesStore.swift`; Test `Tests/StashAppTests/NotesStoreTests.swift`.
**Interface:** `actor NotesStore { init(pool: any DatabaseWriter); func all() throws -> [Note] (order updated_at DESC, id DESC); func upsert(_ n: Note) throws; func delete(id: String) throws; func create(now: Int64, id: String) throws -> Note }` — `create` inserts a blank `.text` note (title "", body "", default color yellow `#fdf0c2`/accent `#c8642f`) and returns it.
Tests: create→all returns 1; upsert updates title; delete removes; all ordered by updated_at desc. Mirror `ClipboardStore` patterns (use `any DatabaseWriter`, `pool.write`/`pool.read`). RED→GREEN→commit `feat(app): add NotesStore`.

---

### Task N4: NotesViewModel + live observation (TDD for the observation gap)

**Files:** Create `Notes/NotesViewModel.swift`; Test `Tests/StashAppTests/NotesViewModelTests.swift`.
**Interface:** `@MainActor @Observable final class NotesViewModel { var notes: [Note] = []; var selectedId: String?; init(db: StashDatabase, store: NotesStore); func startObserving(); func newNote() async -> Note?; func update(_ n: Note) async; func delete(_ n: Note) async; var selected: Note? { notes.first { $0.id == selectedId } } }`. Observation mirrors ClipboardViewModel (ValueObservation tracking `Note.order(Column("updated_at").desc, Column("id").desc).fetchAll`; `for try await` into `notes`; `#if DEBUG` log in catch).
Test (the integration test Slice 1 lacked): insert a note via store, create VM, `startObserving()`, then poll `notes` up to ~2s until it contains the note; assert it appears. Example polling helper:
```swift
@Test func startObservingPopulatesNotes() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = NotesStore(pool: db.pool)
    _ = try await store.create(now: 1, id: "n1")
    let vm = await NotesViewModel(db: db, store: store)
    await vm.startObserving()
    var ok = false
    for _ in 0..<40 { if await vm.notes.contains(where: { $0.id == "n1" }) { ok = true; break }; try? await Task.sleep(for: .milliseconds(50)) }
    #expect(ok)
}
```
RED→GREEN→commit `feat(app): add NotesViewModel with live observation`.

---

### Task N5: Notes tab (hub) + AppEnvironment wiring (build + visual verify)

**Files:** Create `Notes/NotesTab.swift`; modify `App/AppEnvironment.swift`, `StashApp.swift` (route `.notes` → `NotesTab`).
- `AppEnvironment`: build `NotesStore` + `NotesViewModel(db:store:)`, expose `notesViewModel`, call `notesViewModel.startObserving()` in `start()`.
- `NotesTab`: `@Bindable var model: NotesViewModel`, `@Environment(\.openWindow) var openWindow`. A "+ New note" button (`Task { if let n = await model.newNote() { model.selectedId = n.id; openWindow(id: "notes") } }`) and a list of notes (color chip swatch + title + 1-line snippet from body or first checklist item). Tapping a row sets `selectedId` and `openWindow(id: "notes")`. Use Tokens; rows styled like clipboard rows.
- `StashApp.swift`: in the hub switch, `case .notes: NotesTab(model: env.notesViewModel)`.
Build; then VISUAL verify: launch, open hub, click Notes tab, screenshot — confirm the notes list + "New note" render (no empty/collapsed area). Commit `feat(app): add Notes tab`.

---

### Task N6: Notes editor Window scene (build + visual verify)

**Files:** Create `Notes/NotesWindow.swift`; modify `StashApp.swift` (add `Window` scene).
- `StashApp.swift`: add a scene alongside MenuBarExtra:
```swift
Window("Notes", id: "notes") {
    NotesWindow(model: env.notesViewModel)
        .frame(minWidth: 560, idealWidth: 560, minHeight: 520, idealHeight: 520)
}
.windowResizability(.contentSize)
```
- `NotesWindow`: `@Bindable var model: NotesViewModel`. HSplit: left sidebar = note list (selectable, bound to `model.selectedId`); right = editor for `model.selected`:
  - Title `TextField` bound to a local editable copy; on change call `Task { await model.update(updatedNote) }`.
  - For `.text`: body `TextEditor`. For `.todo`: a `List`/VStack of `items` with toggles + "+ Add task".
  - A row of 4 color swatches (sets color+accent). A "Pin to desktop" `Toggle` bound to `onDesktop`.
  - Fixed determinate sizing (the window frame handles it).
  Keep editing simple: edit a `@State var draft: Note` seeded from `model.selected`, write through on field commit/change.
Build; VISUAL verify: launch, create a note, confirm the Notes window opens and shows the editor (sidebar + fields render). Screenshot. Commit `feat(app): add Notes editor window`.

---

## Notes for implementer
- `openWindow(id:)` requires the matching `Window(id:)` scene; both live in `StashApp`'s `body` and can capture the App's `@State env`.
- If GRDB Codable does not auto-encode `[ChecklistItem]` into the TEXT `items` column, switch `Note` to a persisted `itemsJSON: String` column property with a computed `items: [ChecklistItem]` (JSON encode/decode) — keep the public `items` accessor either way.
- Reuse the Clipboard files as the reference for store/viewmodel/observation shapes.
