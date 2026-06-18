# Stash Slice 4 — Tasks + MCP wiring (Spec + Plan)

**Goal:** App-side Tasks: a `TaskItem` GRDB record matching the existing `tasks` schema in `mcp-server/src/db.ts`, a `TasksStore` + `@MainActor @Observable TasksViewModel` with live observation, a hub **To-dos tab**, a full **Tasks window**, and a verified end-to-end MCP path (`create_task` over stdio → row in shared stash.db → app sees it live).

**Why headless-friendly:** the data layer + MCP path are fully testable without a display; the UI mirrors the Notes/Clipboard slices (low rendering risk, no zero-height collapse because hub has fixed `panelHeight` and the Tasks window gets a determinate frame). Visual confirmation of the two UI surfaces is best-effort (dev Mac may be locked) but not a blocker.

## Decisions
- The app must create the `tasks` table itself (idempotent, matching db.ts) so it works whether the app or the MCP server runs first.
- "Generate my day" needs Claude via MCP (app can't call Claude directly) — the To-dos tab button is a documented STUB for this slice (real behavior arrives with the AI tab); it shows a tooltip "Ask Claude via MCP to plan your day". Quick-add + lists + completion are fully functional.
- Light enums for the string columns: `TaskPriority {high,med,low}`, `TaskDue {Today,Tomorrow,Upcoming}`, `TaskSource {you,claude}` (rawValue == column string, matching the MCP server's values).

## Global Constraints
Same as prior slices. Tests: Swift Testing, full suite via `cd StashApp && xcodebuild test -scheme StashApp -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO`. `xcodegen generate` after adding files. Commit trailer `Claude-Session: https://claude.ai/code/session_015v4jqLe8vCM5hYdh17AHWe`. No banner comments. Reuse Tokens + the Clipboard/Notes patterns. `repeat` is a Swift keyword — the column is `repeat`; the Swift property is `repeatRule` with CodingKey `"repeat"`, and any raw SQL referencing it uses backticks.

---

### Task T1: TaskItem record + v4_tasks migration (TDD)
**Files:** Create `Data/TaskItem.swift`; modify `Data/Database.swift` (add `v4_tasks` migration after v3); Test `Tests/StashAppTests/TaskItemTests.swift`.

`TaskItem` matches db.ts `tasks` exactly:
```swift
enum TaskPriority: String, Codable, Sendable { case high, med, low }
enum TaskDue: String, Codable, Sendable { case Today, Tomorrow, Upcoming }
enum TaskSource: String, Codable, Sendable { case you, claude }

struct TaskItem: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable, Equatable {
    var id: String
    var title: String
    var done: Bool
    var priority: TaskPriority?
    var due: TaskDue?
    var project: String
    var tags: [String]            // JSON text column "tags"
    var repeatRule: String?       // column "repeat"
    var subs: [ChecklistItem]     // JSON text column "subs"  (reuse ChecklistItem {t,done})
    var source: TaskSource
    var createdAt: Int64
    var updatedAt: Int64
    static let databaseTableName = "tasks"
    enum CodingKeys: String, CodingKey {
        case id, title, done, priority, due, project, tags
        case repeatRule = "repeat"
        case subs, source
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```
Migration `v4_tasks` (create-if-absent, matching db.ts column names/defaults; use the GRDB table builder; for the `repeat` column use `t.column("repeat", .text)`):
```swift
m.registerMigration("v4_tasks") { db in
    if try !db.tableExists("tasks") {
        try db.create(table: "tasks") { t in
            t.column("id", .text).primaryKey()
            t.column("title", .text).notNull()
            t.column("done", .integer).notNull().defaults(to: 0)
            t.column("priority", .text)
            t.column("due", .text)
            t.column("project", .text).notNull().defaults(to: "Inbox")
            t.column("tags", .text).notNull().defaults(to: "[]")
            t.column("repeat", .text)
            t.column("subs", .text).notNull().defaults(to: "[]")
            t.column("source", .text).notNull().defaults(to: "you")
            t.column("created_at", .integer).notNull()
            t.column("updated_at", .integer).notNull()
        }
    }
}
```
Tests: (a) round-trip a TaskItem with tags+subs+priority+due+source through an in-memory migrated DB; (b) a row inserted with the RAW MCP-style SQL (matching db.ts INSERT: source 'claude', tags/subs JSON) decodes into a TaskItem correctly (proves contract parity with the server). RED→GREEN→commit `feat(app): add TaskItem record + tasks migration`.

---

### Task T2: TasksStore actor (TDD)
**Files:** Create `Tasks/TasksStore.swift`; Test `Tests/StashAppTests/TasksStoreTests.swift`.
`actor TasksStore { init(pool: any DatabaseWriter); func all() throws -> [TaskItem] (order created_at DESC, id DESC); func upsert(_:) throws; func setDone(id:String, done:Bool) throws; func delete(id:String) throws; func create(title:String, due:TaskDue, now:Int64, id:String) throws -> TaskItem }` (create defaults: project "Inbox", source .you, tags [], subs []). Mirror NotesStore. Tests: create→all; setDone toggles; delete; ordering. RED→GREEN→commit `feat(app): add TasksStore`.

---

### Task T3: TasksViewModel + quick-add parsing (TDD)
**Files:** Create `Tasks/TasksViewModel.swift`; Test `Tests/StashAppTests/TasksViewModelTests.swift`.
`@MainActor @Observable final class TasksViewModel { var tasks: [TaskItem] = []; var filter: TaskFilter = .today; init(db:store:); func startObserving(); func add(_ rawTitle:String) async; func toggle(_:) async; func delete(_:) async; var visible: [TaskItem] { ... filter today/upcoming/all/done ... } }`. `enum TaskFilter { case today, upcoming, all, done }`. Filtering matches list_tasks logic in server.ts: today = due==Today && !done; upcoming = (Tomorrow||Upcoming) && !done; done = done; all = !done. A pure `nonisolated static func matchesFilter(_ t: TaskItem, _ f: TaskFilter) -> Bool` (unit-tested). Observation mirrors NotesViewModel; live-observation populate test (polling). `add` creates a task (due defaults Today). RED→GREEN→commit `feat(app): add TasksViewModel`.

---

### Task T4: To-dos tab (hub) + AppEnvironment wiring (build)
**Files:** Create `Tasks/TodosTab.swift`; modify `App/AppEnvironment.swift` (+`tasksViewModel`, start observing), `StashApp.swift` (route `.todos` → TodosTab; add Tasks window scene in T5).
To-dos tab: a quick-add `TextField` (submit → `model.add`), a "Today · N open" header, the day's task rows (priority dot, checkbox toggling done, title with strikethrough when done, due pill, `✶ Claude` badge when source==.claude), an "Open all tasks ↗" button (opens the Tasks window), and a "Generate my day" stub button (tooltip only). Rows styled per README task-row anatomy, using Tokens (priority high `#c8642f`/med `#d8a13a`/low `#b3a99b`). Build + suite green. Commit `feat(app): add To-dos tab`.

---

### Task T5: Tasks window (full) (build)
**Files:** Create `Tasks/TasksWindow.swift`; modify `StashApp.swift` (add `Window("Tasks", id:"tasks")` with determinate `.frame(minWidth:560, minHeight:580...)` + `.windowResizability(.contentSize)`; To-dos tab "Open all tasks" → `openWindow(id:"tasks")`).
Tasks window: sidebar smart lists (Today/Upcoming/All/Completed with counts) bound to `model.filter`; main pane = filter title + open count + quick-add + the filtered task list (full row anatomy incl. tag chips + project label + `↻ Daily` chip when repeatRule != nil + a `☑ k/n` subtask-progress chip that expands an inline checklist). Determinate window frame (no collapse). Build + suite green. Commit `feat(app): add Tasks window`.

---

### Task T6: MCP end-to-end verification (headless)
**Files:** Create `mcp-server/test-e2e.mjs` (a small stdio client) OR use a shell here-doc; no app change required beyond ensuring `.mcp.json` is correct (it already points at `./mcp-server/dist/server.js`).
Steps:
1. `cd mcp-server && npm install && npm run build` (produces dist/server.js).
2. Drive the server over stdio with a JSON-RPC `initialize` then `tools/call` `create_task {title:"E2E plan item", due:"Today", priority:"high", tags:["eng"]}` (MCP stdio protocol). Capture the response.
3. Query `sqlite3 "$HOME/Library/Application Support/Stash/stash.db" "SELECT title,source,due,priority,tags FROM tasks WHERE title='E2E plan item';"` — confirm exactly one row with `source='claude'`, `due='Today'`, `priority='high'`, `tags='["eng"]'`. This proves the MCP→shared-DB→(app observation) contract end to end.
4. Also call `list_tasks {filter:"today"}` and confirm the task is returned.
Document the exact stdio transcript + sqlite output in the report. Commit any helper script: `test(mcp): add end-to-end stdio verification for create_task/list_tasks`.

---

## Notes
- Mirror NotesStore/NotesViewModel/NotesTab/NotesWindow for shape — the patterns are established and reviewed.
- The `repeat` column is a Swift keyword; property is `repeatRule` + CodingKey `"repeat"`; raw SQL uses backticks around `repeat`.
- The MCP server's `rowToTask` and tools already exist; T6 only verifies, it does not modify server tool logic.
