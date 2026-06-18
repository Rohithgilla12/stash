# Stash — Slice 2: Notes (Design)

**Date:** 2026-06-18
**Status:** Self-approved (autonomous overnight run; decisions documented for later review)
**Scope:** SQLite-backed notes, the hub **Notes tab** (list + create + delete), and a separate
**Notes editor window** (title + body, color, text/todo kinds). Desktop sticky `NSWindow`s and
the ⌥Space toggle are deferred to Slice 3 (but the `on_desktop` field is persisted now).

## Decisions (made autonomously)

- Build the Notes **data layer + tab + editor window** as one coherent slice. This slightly
  reorders the CLAUDE.md build order (which lists sticky notes before SQLite notes) because the
  stickies in Slice 3 render the same note data — building the data + editor first is cleaner.
- The Notes editor is a **separate SwiftUI `Window` scene** (id `"notes"`), opened from the hub
  via `@Environment(\.openWindow)`. Fixed size ~560×520 (learning from Slice 1: give windows a
  determinate size so `ScrollView`/`List` content renders).
- A single shared `AppEnvironment` (already exists) gains a `NotesViewModel`, injected into both
  the `MenuBarExtra` content and the `Window` scene (both reference the App's `@State env`).
- Note colors are the README sticky pastels: yellow `#fdf0c2`, peach `#fcdcc6`, blue `#d4e4f2`,
  mint `#d9ecda` (accents `#c8642f / #b97a4a / #5b86b8 / #5e8a52`).

## Schema change (contract with mcp-server)

Current `notes` columns: `id, title, body, color, updated_at`. Add (nullable / defaulted):
- `kind TEXT NOT NULL DEFAULT 'text'` — `'text' | 'todo'`
- `items TEXT NOT NULL DEFAULT '[]'` — JSON `[{t,done}]` for todo notes
- `accent TEXT`
- `on_desktop INTEGER NOT NULL DEFAULT 0`
- `created_at INTEGER NOT NULL DEFAULT 0`

GRDB migration `v3_notes_fields` adds these with guarded `ALTER TABLE ADD COLUMN` (idempotent,
lossless). Mirror the same columns in `mcp-server/src/db.ts`'s `notes` `CREATE TABLE`.

## Components / files (new)

- `Data/NoteKind.swift` — `enum NoteKind: String, Codable, Sendable { case text, todo }`
- `Data/Note.swift` — `struct Note: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable, Equatable`
  with `id, title, body, color, accent, kind, items ([ChecklistItem]), onDesktop, createdAt, updatedAt`;
  `databaseTableName = "notes"`; snake_case CodingKeys (`on_desktop`, `created_at`, `updated_at`).
  `struct ChecklistItem: Codable, Sendable, Equatable { var t: String; var done: Bool }`.
- `Notes/NotesStore.swift` — `actor NotesStore { all(); create() -> Note; upsert(Note); delete(id) }`.
- `Notes/NotesViewModel.swift` — `@MainActor @Observable` holding `notes: [Note]`, `selectedId: String?`;
  live `ValueObservation`; `startObserving()`, `newNote()`, `update(Note)`, `delete(Note)`.
- `Notes/NotesTab.swift` — hub tab: "+ New note" + list (color chip + title + body/first-item snippet).
  Clicking a note sets `selectedId` and opens the Notes window.
- `Notes/NotesWindow.swift` — the editor window root: sidebar note list + editor pane
  (title `TextField`; for `.text` a body `TextEditor`; for `.todo` an editable checklist with
  "+ Add task"); color swatches; a "Pin to desktop" toggle (persists `on_desktop`); "kind" toggle.
- Modify `App/AppEnvironment.swift` — construct `NotesStore` + `NotesViewModel`, start observing.
- Modify `StashApp.swift` — add the `Window("Notes", id: "notes")` scene; wire the Notes tab.
- Modify `mcp-server/src/db.ts` — notes schema sync.

## Persistence / behavior

- All notes persist to the shared `stash.db` `notes` table; the editor writes through `NotesStore`
  and the UI updates live via `ValueObservation` (same pattern as Clipboard).
- "+ New note" creates an empty `.text` note and opens the editor focused on it.
- Editing title/body/items/color/onDesktop writes straight through (debounced not required for v1).

## Testing

- `Note` codec round-trip (incl. `items` JSON, snake_case keys).
- Migration test: an old minimal `notes` table upgrades to add the 5 columns losslessly.
- `NotesStore`: create/upsert/delete/all against in-memory DB.
- `NotesViewModel`: startObserving populates `notes` from existing rows (the integration test that
  Slice 1 lacked — added here as a pattern).
- **Visual verification:** build, open the hub Notes tab and the Notes window, screenshot both,
  confirm list + editor render (no zero-height collapse).

## Out of scope (Slice 3+)

Desktop sticky `NSWindow`s, ⌥Space toggle, note sharing, rich text, CloudKit sync.
