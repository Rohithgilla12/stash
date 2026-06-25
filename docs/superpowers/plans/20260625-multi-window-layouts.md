# Multi-Window Layouts (Window Presets Phase 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Save the current arrangement of app windows as a named layout and recall it — repositioning each running app's main window, and launching+placing any that aren't running.

**Architecture:** Reuse the Phase-1 `WindowSnapper` (AX `setFrame`, `resolveScreen`, `ScreenGeometry`) + GRDB store pattern + hotkey/deeplink plumbing. Add a `SavedLayout`/`LayoutEntry` model + `SavedLayoutStore`, capture/recall methods on `WindowSnapper`, a "Layouts" section in the Windows tab, and per-layout hotkey + `stash://layout?name=` deeplink.

**Tech Stack:** Swift 6 (strict concurrency, `@MainActor`/actor), AppKit + Accessibility (AXUIElement), GRDB, SwiftUI, Swift Testing.

## Global Constraints

- **One main window per app** (capture `kAXMainWindowAttribute`, fallback first `kAXWindowsAttribute`); exclude Stash + non-`.regular` apps.
- **Recall launches missing apps** best-effort (`NSWorkspace.openApplication`), waits for the window (≈0.3s poll, ≈5s/16-try cap), then places; on timeout → skipped. **Clamp** every placed frame to the target display's `visibleFrame` (AX) so nothing lands off-screen; fall back to `NSScreen.main` if the stored display index is gone.
- Frames stored as **absolute AX coords + displayIndex**.
- Persist via **GRDB** `saved_layouts` table; `SavedLayoutStore` is an `actor` (mirror `WindowPresetStore`).
- Model name is **`SavedLayout`** (the existing `WindowLayout` enum is snap-frame math — do not reuse).
- **Swift 6:** build + tests are NOT sufficient for concurrency — **launch-run the built app** on every runtime task (a prior off-main `@MainActor` closure shipped a launch crash). Off-main waits (launch poll) must NOT block the cooperative pool; AX mutations re-enter the main actor.
- Accessibility-gated (`AXIsProcessTrusted()`); reuse `AccessibilityAuthorizer.requestOnce()`. No banner comments. No employer name. Reuse `Tokens`/`Typography`/`Components`.
- `cd StashApp && xcodegen generate` before building. Release: `xcodebuild -scheme StashApp -configuration Release -derivedDataPath .build-release build CODE_SIGNING_ALLOWED=NO`. Suite: `xcodebuild test -scheme StashApp -destination 'platform=macOS' -derivedDataPath .build CODE_SIGNING_ALLOWED=NO 2>&1 | grep "Test run with"` (was 248). Launch-run snippet: `B4=$(ls ~/Library/Logs/DiagnosticReports/ | grep -ic stash); .build-release/Build/Products/Release/StashApp.app/Contents/MacOS/StashApp >/tmp/r.log 2>&1 & P=$!; sleep 6; kill -0 $P 2>/dev/null && echo ALIVE || echo CRASHED; [ "$(ls ~/Library/Logs/DiagnosticReports/ | grep -ic stash)" = "$B4" ] && echo "no new crash" || echo "NEW CRASH"; pkill -f Release/StashApp.app`. Commit trailer (MUST end every msg): `Claude-Session: https://claude.ai/code/session_015v4jqLe8vCM5hYdh17AHWe`. Plain `git commit`; don't git add the generated Info.plist.

**Phase-1 reuse (consume):** `WindowSnapper` (`@MainActor`) has private `setFrame(_ window: AXUIElement, _ frame: CGRect)`, `resolveScreen(displayMode:displayIndex:windowAXFrame:) -> NSScreen?`, and uses `ScreenGeometry.axFrame(fromAppKit:primaryHeight:)`. `WindowPresetStore` (actor) is the store template. `AppEnvironment` owns `snapper`, `windowPresets` (GRDB observation), `registerPresetHotKeys()`, `applyHotkeys()`, `handleDeeplink` `case "snap":`. `WindowsTab` has a Presets section + editor to mirror.

---

### Task 1: SavedLayout model + store + migration + clamp helper (persistence + pure, tested)

**Files:** Create `Windows/SavedLayout.swift`, `Data/SavedLayoutStore.swift`, `Windows/WindowGeometry.swift`; Modify `Data/Database.swift`; Test `Tests/StashAppTests/SavedLayoutTests.swift`, `Tests/StashAppTests/WindowGeometryTests.swift`.

**Interfaces produced:** `LayoutEntry`, `SavedLayout` (+ `entries` encode/decode), `SavedLayoutStore` (actor `all/upsert/delete`), `WindowGeometry.clamp(_:to:) -> CGRect`. Migration `v9_saved_layouts`.

- [ ] **Step 1: `Windows/SavedLayout.swift`**
```swift
import GRDB
import Foundation

struct LayoutEntry: Codable, Sendable, Equatable {
    let bundleId: String
    let appName: String
    let x: Double; let y: Double; let width: Double; let height: Double  // AX global coords
    let displayIndex: Int
    var frame: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

struct SavedLayout: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable, Equatable {
    var id: String
    var name: String
    var entriesJSON: String
    var hotkeyKeyCode: Int?
    var hotkeyModifiers: Int?
    var createdAt: Int64

    static let databaseTableName = "saved_layouts"
    enum CodingKeys: String, CodingKey {
        case id, name
        case entriesJSON = "entries_json"
        case hotkeyKeyCode = "hotkey_key_code"
        case hotkeyModifiers = "hotkey_modifiers"
        case createdAt = "created_at"
    }

    var entries: [LayoutEntry] {
        (try? JSONDecoder().decode([LayoutEntry].self, from: Data(entriesJSON.utf8))) ?? []
    }
    static func encode(_ entries: [LayoutEntry]) -> String {
        guard let data = try? JSONEncoder().encode(entries),
              let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }
}
```

- [ ] **Step 2: `Windows/WindowGeometry.swift`** (pure clamp)
```swift
import CoreGraphics

enum WindowGeometry {
    /// Clamp `frame` to fit inside `visible` (AX coords): shrink to fit, then nudge fully on-screen.
    static func clamp(_ frame: CGRect, to visible: CGRect) -> CGRect {
        let w = min(frame.width, visible.width)
        let h = min(frame.height, visible.height)
        var x = frame.minX, y = frame.minY
        if x < visible.minX { x = visible.minX }
        if y < visible.minY { y = visible.minY }
        if x + w > visible.maxX { x = visible.maxX - w }
        if y + h > visible.maxY { y = visible.maxY - h }
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
```

- [ ] **Step 3: Write failing tests** — `WindowGeometryTests` (in-bounds unchanged; oversized shrinks; off-right nudged left; off-top-left nudged into bounds) and `SavedLayoutTests` (entries round-trip: build `[LayoutEntry]` → `SavedLayout.encode` → assign `entriesJSON` → read `.entries` back equal; store `upsert`/`all` ordered by created_at / `delete`, in-memory `DatabaseQueue` with the v9 table created inline).
```swift
// WindowGeometryTests
@Test func inBoundsUnchanged() {
    let v = CGRect(x: 0, y: 0, width: 1000, height: 800)
    #expect(WindowGeometry.clamp(CGRect(x: 100, y: 100, width: 400, height: 300), to: v) == CGRect(x: 100, y: 100, width: 400, height: 300))
}
@Test func oversizeShrinks() {
    let v = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let c = WindowGeometry.clamp(CGRect(x: 0, y: 0, width: 5000, height: 5000), to: v)
    #expect(c.width == 1000 && c.height == 800)
}
@Test func offRightNudgesLeft() {
    let v = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let c = WindowGeometry.clamp(CGRect(x: 900, y: 100, width: 400, height: 300), to: v)
    #expect(c.maxX == 1000 && c.width == 400)
}
// SavedLayoutTests
@Test func entriesRoundTrip() {
    let e = [LayoutEntry(bundleId: "com.apple.Safari", appName: "Safari", x: 0, y: 0, width: 800, height: 600, displayIndex: 0)]
    var l = SavedLayout(id: "1", name: "Work", entriesJSON: SavedLayout.encode(e), hotkeyKeyCode: nil, hotkeyModifiers: nil, createdAt: 1)
    #expect(l.entries == e)
}
```

- [ ] **Step 4: Implement `Data/SavedLayoutStore.swift`** (mirror `WindowPresetStore`)
```swift
import Foundation
import GRDB

actor SavedLayoutStore {
    private let pool: any DatabaseWriter
    init(pool: any DatabaseWriter) { self.pool = pool }
    func all() throws -> [SavedLayout] {
        try pool.read { try SavedLayout.order(Column("created_at"), Column("id")).fetchAll($0) }
    }
    func upsert(_ layout: SavedLayout) throws { try pool.write { try layout.save($0) } }
    func delete(id: String) throws { try pool.write { try SavedLayout.deleteOne($0, key: id) } }
}
```

- [ ] **Step 5: Add migration in `Database.swift`** (after `v8_window_presets`)
```swift
        m.registerMigration("v9_saved_layouts") { db in
            if try !db.tableExists("saved_layouts") {
                try db.create(table: "saved_layouts") { t in
                    t.column("id", .text).primaryKey()
                    t.column("name", .text).notNull()
                    t.column("entries_json", .text).notNull().defaults(to: "[]")
                    t.column("hotkey_key_code", .integer)
                    t.column("hotkey_modifiers", .integer)
                    t.column("created_at", .integer).notNull()
                }
            }
        }
```

- [ ] **Step 6: Run tests → pass.** Clean Release build succeeds.
- [ ] **Step 7: Commit** — `git commit -m "feat(app): SavedLayout model + store + migration + clamp helper"`

---

### Task 2: WindowSnapper.captureCurrentLayout (AX enumeration)

**Files:** Modify `Windows/WindowSnapper.swift`.

**Interfaces produced:** `func captureCurrentLayout() -> [LayoutEntry]` (returns `[]` if not trusted); private `mainWindow(for app: NSRunningApplication) -> (AXUIElement, CGRect)?` and `displayIndex(forAXFrame: CGRect) -> Int`.

- [ ] **Step 1: Add `displayIndex(forAXFrame:)`** — the index into `NSScreen.screens` of the max-overlap screen (mirror `resolveScreen`'s "active" math but return the index; default 0).
- [ ] **Step 2: Add `mainWindow(for:)`** — `AXUIElementCreateApplication(app.processIdentifier)`; read `kAXMainWindowAttribute` (fallback: first element of `kAXWindowsAttribute`); read `kAXPositionAttribute`/`kAXSizeAttribute` via `AXValueGetValue` → `(AXUIElement, CGRect)`. Return nil if no readable window. (Same AX idioms as `focusedWindow()`.)
- [ ] **Step 3: Add `captureCurrentLayout()`**
```swift
    func captureCurrentLayout() -> [LayoutEntry] {
        guard AXIsProcessTrusted() else { AccessibilityAuthorizer.requestOnce(); return [] }
        var entries: [LayoutEntry] = []
        for app in NSWorkspace.shared.runningApplications
            where app.activationPolicy == .regular
            && app.bundleIdentifier != nil
            && app.bundleIdentifier != Bundle.main.bundleIdentifier {
            guard let (_, frame) = mainWindow(for: app) else { continue }
            entries.append(LayoutEntry(
                bundleId: app.bundleIdentifier!,
                appName: app.localizedName ?? app.bundleIdentifier!,
                x: frame.minX, y: frame.minY, width: frame.width, height: frame.height,
                displayIndex: displayIndex(forAXFrame: frame)
            ))
        }
        return entries
    }
```
- [ ] **Step 4: Build + suite + LAUNCH-RUN** (capture is AX I/O; the pure helpers are tested in Task 1 — add no new unit test unless you factor a pure helper). Release build SUCCEEDED; 248 pass; launch-run ALIVE + no new crash. Paste evidence.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): capture current window arrangement via Accessibility"`

---

### Task 3: WindowSnapper.recall (place running + launch-and-wait missing)

**Files:** Modify `Windows/WindowSnapper.swift`.

**Interfaces produced:** `struct LayoutRecallSummary: Sendable { let placed: Int; let launched: Int; let skipped: Int }`; `func recall(_ entries: [LayoutEntry]) async -> LayoutRecallSummary`.

- [ ] **Step 1: Add a `place(entry:on app:)` helper** — `mainWindow(for: app)` → resolve screen by `resolveScreen(displayMode: "index", displayIndex: entry.displayIndex, windowAXFrame: nil) ?? NSScreen.main`; `visibleAX = ScreenGeometry.axFrame(fromAppKit: screen.visibleFrame, primaryHeight: NSScreen.screens.first?.frame.height ?? screen.frame.height)`; `setFrame(window, WindowGeometry.clamp(entry.frame, to: visibleAX))`. Returns `Bool` (placed).
- [ ] **Step 2: Add `recall(_:)`**
```swift
    func recall(_ entries: [LayoutEntry]) async -> LayoutRecallSummary {
        guard AXIsProcessTrusted() else { AccessibilityAuthorizer.requestOnce(); return LayoutRecallSummary(placed: 0, launched: 0, skipped: entries.count) }
        var placed = 0, launched = 0, skipped = 0
        for entry in entries {
            if let app = runningApp(entry.bundleId) {
                if place(entry, on: app) { placed += 1 } else { skipped += 1 }
            } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: entry.bundleId) {
                launched += 1
                let app = await launchAndWaitForWindow(url: url, bundleId: entry.bundleId)  // ≈5s
                if let app, place(entry, on: app) { /* counted in launched */ } else { skipped += 1 }
            } else { skipped += 1 }
        }
        return LayoutRecallSummary(placed: placed, launched: launched, skipped: skipped)
    }
```
- [ ] **Step 3: Add `launchAndWaitForWindow(url:bundleId:)`** — `try? await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())`; then up to 16 iterations: `try? await Task.sleep(for: .milliseconds(300))` (suspends, does NOT block the pool) then `if let app = runningApp(bundleId), mainWindow(for: app) != nil { return app }`; return nil on timeout. `runningApp(_:) = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleId }`. Since `WindowSnapper` is `@MainActor`, the `await`s suspend + resume on main — no off-main `@MainActor` closure; the AX calls run on main.
- [ ] **Step 4: Build + suite + LAUNCH-RUN** (recall is AX + async launch/poll — concurrency-sensitive; verify ALIVE + no new crash). Paste evidence.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): recall a saved layout (place running + launch missing apps)"`

---

### Task 4: AppEnvironment wiring + Windows-tab Layouts section + save prompt

**Files:** Modify `App/AppEnvironment.swift`, `Windows/WindowsTab.swift`; Create `Windows/SaveLayoutSheet.swift`.

**Interfaces produced:** `AppEnvironment.savedLayouts: [SavedLayout]` (GRDB observation), `func saveCurrentLayout(name: String)`, `func deleteLayout(id: String)`, `func recallLayout(_ layout: SavedLayout)`.

- [ ] **Step 1: AppEnvironment** — add `let savedLayoutStore = SavedLayoutStore(pool: <shared pool>)`; observed `var savedLayouts: [SavedLayout] = []` via GRDB `ValueObservation` (mirror the `windowPresets` observation, `await MainActor.run` to set). `func saveCurrentLayout(name: String)`: `let entries = snapper.captureCurrentLayout(); guard !entries.isEmpty else { return }; let layout = SavedLayout(id: UUID().uuidString, name: name, entriesJSON: SavedLayout.encode(entries), hotkeyKeyCode: nil, hotkeyModifiers: nil, createdAt: Int64(Date().timeIntervalSince1970*1000)); Task { try? await savedLayoutStore.upsert(layout) }`. `func deleteLayout(id:)`: `Task { try? await savedLayoutStore.delete(id: id) }`. `func recallLayout(_ layout:)`: `Task { _ = await snapper.recall(layout.entries) }` (or surface the summary to a toast via a published var).
- [ ] **Step 2: `SaveLayoutSheet.swift`** — a tiny sheet with a name `TextField` + Cancel/Save (default action), mirroring `WindowPresetEditor`'s style. On Save → `onSave(name)`.
- [ ] **Step 3: WindowsTab "Layouts" section** (below the Presets section) — a **"Save current windows…"** tile/button that presents `SaveLayoutSheet` → `env.saveCurrentLayout(name:)`; a list of `env.savedLayouts` rows (name + a small app-count or `AppIconProvider` icons from `entries`) → tap calls `env.recallLayout(layout)` + shows a toast; hover/menu → Rename (re-save with new name) / Delete. Keep the `!snapper.isTrusted` affordance. Pass what's needed from `StashApp.swift`'s `case .windows:` (mirror how presets are passed).
- [ ] **Step 4: Build + suite + LAUNCH-RUN.** Paste evidence. Manual: Save current windows → a layout appears; rearrange → Recall → windows return.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): Windows-tab Layouts section (save/recall current windows)"`

---

### Task 5: Per-layout hotkeys + stash://layout deeplink + final review

**Files:** Modify `App/AppEnvironment.swift`.

- [ ] **Step 1: Layout hotkeys** — add `private var layoutHotKeys: [GlobalHotKey] = []` + `func registerLayoutHotKeys()` mirroring `registerPresetHotKeys()`: for each `savedLayouts` entry with `hotkeyKeyCode`/`hotkeyModifiers`, `GlobalHotKey(keyCode:modifiers:handler: { [weak self] in guard let self, let l = self.savedLayouts.first(where: {$0.id == captured.id}) else { return }; Task { _ = await self.snapper.recall(l.entries) } })`. Call from `applyHotkeys()` (gated by `globalHotkeysEnabled`) and after the `savedLayouts` observation updates; clear on disable.
- [ ] **Step 2: Deeplink** — in `handleDeeplink`, add `case "layout":` → `if let name = q("name"), let l = savedLayouts.first(where: { $0.name.lowercased() == name.lowercased() }) { Task { _ = await snapper.recall(l.entries) } }`.
- [ ] **Step 3: Build + suite + LAUNCH-RUN.** Paste evidence.
- [ ] **Step 4: Commit** — `git commit -m "feat(app): per-layout hotkeys + stash://layout deeplink"`

---

## Final verification (after all tasks)
- Clean Release build + full suite green (248 + new WindowGeometry/SavedLayout tests).
- Launch-run (Debug + Release): alive, zero new crash reports.
- Manual: save a layout; rearrange windows; recall → they return; quit one app, recall → it launches + places; an out-of-range displayIndex / unplugged display → window clamps on-screen.
- Final whole-branch review (most-capable model), then `superpowers:finishing-a-development-branch` to merge.
