# Stash Slice 6a — Snippets (engine + store + in-app demo)

**Goal:** Text-expansion snippets: a `Snippet` record, a pure `ExpansionEngine` (static + dynamic triggers), a `SnippetsStore` (seeded defaults), a `SnippetsViewModel`, and the hub **Snippets tab** with the in-app live-expansion demo (typing a trigger in the app's own field expands it inline). Fully verifiable headlessly (engine + store via tests). The system-wide expander (CGEventTap, needs Accessibility) is Slice 6b — DEFERRED.

## Schema (snippets)
New `snippets` table (app-owned; mirror in db.ts for a complete schema record):
```
trigger    TEXT PRIMARY KEY,   -- e.g. ':sig'
label      TEXT NOT NULL,
expand     TEXT,               -- static expansion (NULL for dynamic)
dynamic    TEXT,               -- generator key e.g. 'date'|'shrug' (NULL for static)
created_at INTEGER NOT NULL DEFAULT 0
```
App migration `v5_snippets` creates it (guarded). Add the same `CREATE TABLE IF NOT EXISTS snippets (...)` to `mcp-server/src/db.ts` for schema completeness (server has no snippet tools — just keep the file documenting all tables).

## Global Constraints
Same as prior slices. Swift Testing; full suite; `xcodegen generate`; commit trailer `Claude-Session: https://claude.ai/code/session_015v4jqLe8vCM5hYdh17AHWe`; no banner comments; reuse Tokens; mirror Notes/Tasks patterns; determinate sizes (Snippets tab lives in fixed-height hub — safe).

---

### Task S1: Snippet record + migration + db.ts sync + ExpansionEngine (TDD)
**Files:** Create `Data/Snippet.swift`, `Snippets/ExpansionEngine.swift`; modify `Data/Database.swift` (+`v5_snippets`), `mcp-server/src/db.ts`; Test `Tests/StashAppTests/SnippetTests.swift`, `Tests/StashAppTests/ExpansionEngineTests.swift`.

`struct Snippet: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable, Equatable { var trigger: String; var label: String; var expand: String?; var dynamic: String?; var createdAt: Int64; var id: String { trigger }; static let databaseTableName = "snippets"; CodingKeys created_at }`.

`enum ExpansionEngine` (pure, `now` injected for testability):
- `static func resolve(_ s: Snippet, now: Date) -> String` — static → `s.expand ?? ""`; dynamic → switch `s.dynamic`: `"date"` → medium-style date string from `now`; `"time"` → short time; `"shrug"` → `¯\\_(ツ)_/¯`; default → `s.expand ?? ""`.
- `static func match(buffer: String, snippets: [Snippet], now: Date) -> (matchLength: Int, replacement: String)?` — if `buffer` ends with any snippet's `trigger` (longest trigger wins), return `(trigger.count, resolve(snippet, now))`; else nil.
- `static func expanded(buffer: String, snippets: [Snippet], now: Date) -> (text: String, expandedTrigger: String)?` — convenience: applies match by replacing the trailing trigger, returns the new full text + the trigger that fired (for the toast); nil if no match.

Tests (ExpansionEngineTests): static trigger at end of buffer expands; dynamic `:date` resolves to a non-empty string containing the injected year; `:shrug` → the kaomoji; longest-trigger-wins when one trigger is a prefix of another; no match → nil; trigger only fires at the END of the buffer (not mid-text). SnippetTests: round-trip a static + a dynamic snippet through a migrated in-memory DB.
RED→GREEN→commit `feat(app): add Snippet model + expansion engine`. (db.ts edit: verify `cd mcp-server && npm run build`.)

---

### Task S2: SnippetsStore (seeded) + SnippetsViewModel (TDD)
**Files:** Create `Snippets/SnippetsStore.swift`, `Snippets/SnippetsViewModel.swift`; Test `Tests/StashAppTests/SnippetsStoreTests.swift`.
`actor SnippetsStore { init(pool: any DatabaseWriter); func all() throws -> [Snippet] (order trigger ASC); func upsert(_:) throws; func delete(trigger:) throws; func seedDefaultsIfEmpty(now: Int64) throws }`. Defaults (only if table empty): `:sig`→"— Rohith" (label "Signature"), `:addr` (label "Address", a placeholder address), `:ty`→"Thank you!" , `:cal`→"Let's find a time: ", `:date` dynamic 'date', `:shrug` dynamic 'shrug'.
`@MainActor @Observable final class SnippetsViewModel { var snippets: [Snippet] = []; var demoText: String = ""; var lastExpanded: String?; init(db:store:); func startObserving(); func seed() async; func onDemoChange() // runs ExpansionEngine on demoText, applies expansion + sets lastExpanded; func insert(_ s: Snippet) // appends resolved text to demoText }`. The demo expansion uses `ExpansionEngine.expanded(buffer: demoText, snippets: snippets, now: Date())`.
Tests: store seed populates 6; all ordered; upsert/delete; VM live-observation populate (polling); VM onDemoChange expands a trigger in demoText (set demoText to "hello :shrug", call onDemoChange, assert demoText now ends with the kaomoji and lastExpanded == ":shrug"). RED→GREEN→commit `feat(app): add SnippetsStore + SnippetsViewModel`.

---

### Task S3: Snippets tab (in-app live demo) + wiring (build + best-effort visual)
**Files:** Create `Snippets/SnippetsTab.swift`; modify `App/AppEnvironment.swift` (+`snippetsViewModel`, seed + startObserving in start()), `StashApp.swift` (route `.snippets`).
SnippetsTab: a demo `TextField`/`TextEditor` bound to `model.demoText` with `.onChange(of: model.demoText) { model.onDemoChange() }` (expands inline as you type a known trigger); a transient "Expanded :trigger" toast (from `model.lastExpanded`); and the snippet list below (trigger chip + label + expand preview; tap → `model.insert(snippet)`). Use Tokens. Route `case .snippets: SnippetsTab(model: env.snippetsViewModel)`.
Build + full suite green. App launches without crash (report). Commit `feat(app): add Snippets tab with live expansion demo`.

## Notes
- Mirror Notes/Tasks store+VM shapes. Engine is pure — inject `now` everywhere for tests.
- Snippets tab content is inside the fixed-height hub panel → no collapse risk.
