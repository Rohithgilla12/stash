# Custom Window Presets + Multi-Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users define named custom window-snap presets (size %/pt + anchor + offset + target display), trigger them from the Windows tab / a global hotkey / a `stash://snap?preset=` deeplink, and make snapping multi-display aware.

**Architecture:** A pure frame-computation function (tested) + a GRDB-persisted `WindowPreset` model + store; `WindowSnapper` extended to resolve a target `NSScreen` and apply frames on any display; the Windows tab gains a Presets section + editor; presets register optional hotkeys and a deeplink — all reusing existing `WindowSnapper`/`GlobalHotKey`/`handleDeeplink` plumbing.

**Tech Stack:** Swift 6 (strict concurrency, `@MainActor`), SwiftUI + AppKit, Accessibility (AXUIElement), GRDB.

## Global Constraints

- **Multi-display only; NOT macOS Spaces** (no public API — out of scope).
- **Phase 1 only** (custom presets + multi-display). Multi-window layouts are a later, separate plan.
- Persist via **GRDB** (`window_presets` table), consistent with tasks/notes/snippets.
- Percentages stored as **0.0–1.0 fractions** internally (editor shows 0–100%).
- Swift 6 `@MainActor`; **build + tests are NOT sufficient for concurrency — launch-run the built app** to confirm no crash (a prior off-main `@MainActor` closure shipped a launch crash).
- No banner comments. Reuse existing `Tokens`/`Typography`/`Components`. `cd StashApp && xcodegen generate` before building. Builds: `xcodebuild -scheme StashApp -configuration Release -derivedDataPath .build-release build CODE_SIGNING_ALLOWED=NO`. Tests: `xcodebuild test -scheme StashApp -destination 'platform=macOS' -derivedDataPath .build CODE_SIGNING_ALLOWED=NO 2>&1 | grep "Test run with"` (was 222).
- Commit trailer (MUST end every commit msg): `Claude-Session: https://claude.ai/code/session_015v4jqLe8vCM5hYdh17AHWe`. Plain `git commit` (no `-c user.email`). Don't git add the generated Info.plist.

---

### Task 1: WindowPreset model + pure frame computation + tests

**Files:**
- Create: `StashApp/Sources/StashApp/Windows/WindowPreset.swift`
- Modify: `StashApp/Sources/StashApp/Windows/WindowLayout.swift` (add a preset overload)
- Test: `StashApp/Tests/StashAppTests/WindowPresetLayoutTests.swift`

**Interfaces:**
- Produces: `WindowPreset` (GRDB-ready struct, `databaseTableName = "window_presets"`), enums `PresetSizeMode`, `PresetAnchor`, and `WindowLayout.frame(for preset: WindowPreset, in rect: CGRect) -> CGRect`. Persistence (table/store) is Task 2; AX/screen use is Task 3.

- [ ] **Step 1: Create `WindowPreset.swift`**

```swift
import GRDB
import Foundation

enum PresetSizeMode: String, Codable, Sendable { case percent, points }

enum PresetAnchor: String, Codable, CaseIterable, Sendable {
    case center, left, right, top, bottom, topLeft, topRight, bottomLeft, bottomRight
}

// displayMode: "active" (display under the focused window) | "main" | "index" (the displayIndex-th NSScreen)
struct WindowPreset: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable, Equatable {
    var id: String
    var name: String
    var widthMode: PresetSizeMode
    var width: Double          // percent → 0...1 fraction; points → literal pt
    var heightMode: PresetSizeMode
    var height: Double
    var anchor: PresetAnchor
    var xOffset: Double
    var yOffset: Double
    var displayMode: String    // "active" | "main" | "index"
    var displayIndex: Int      // used when displayMode == "index"
    var hotkeyKeyCode: Int?
    var hotkeyModifiers: Int?
    var createdAt: Int64

    static let databaseTableName = "window_presets"
}
```

- [ ] **Step 2: Write the failing tests** — `WindowPresetLayoutTests.swift`

```swift
import Testing
import CoreGraphics
@testable import StashApp

@Suite struct WindowPresetLayoutTests {
    // A 1000×800 display at origin (top-left AX space).
    let rect = CGRect(x: 0, y: 0, width: 1000, height: 800)

    func preset(_ a: PresetAnchor, wMode: PresetSizeMode = .percent, w: Double = 0.5,
                hMode: PresetSizeMode = .percent, h: Double = 0.5,
                dx: Double = 0, dy: Double = 0) -> WindowPreset {
        WindowPreset(id: "t", name: "t", widthMode: wMode, width: w, heightMode: hMode, height: h,
                     anchor: a, xOffset: dx, yOffset: dy, displayMode: "active", displayIndex: 0,
                     hotkeyKeyCode: nil, hotkeyModifiers: nil, createdAt: 0)
    }

    @Test func percentCenter() {
        let f = WindowLayout.frame(for: preset(.center), in: rect)
        #expect(f == CGRect(x: 250, y: 200, width: 500, height: 400))
    }
    @Test func pointsTopLeft() {
        let f = WindowLayout.frame(for: preset(.topLeft, wMode: .points, w: 600, hMode: .points, h: 400), in: rect)
        #expect(f == CGRect(x: 0, y: 0, width: 600, height: 400))
    }
    @Test func rightAnchorRightAligns() {
        let f = WindowLayout.frame(for: preset(.right, w: 0.3), in: rect)
        #expect(f.maxX == 1000)
        #expect(f.width == 300)
    }
    @Test func bottomAnchorBottomAligns() {
        let f = WindowLayout.frame(for: preset(.bottom, h: 0.5), in: rect)
        #expect(f.maxY == 800)
    }
    @Test func offsetShifts() {
        let f = WindowLayout.frame(for: preset(.topLeft, wMode: .points, w: 200, hMode: .points, h: 200, dx: 20, dy: 30), in: rect)
        #expect(f.origin == CGPoint(x: 20, y: 30))
    }
    @Test func oversizeClampsToDisplay() {
        let f = WindowLayout.frame(for: preset(.center, wMode: .points, w: 5000, hMode: .points, h: 5000), in: rect)
        #expect(f.width == 1000)
        #expect(f.height == 800)
    }
}
```

- [ ] **Step 3: Run tests, expect failure** — `…grep "Test run with"` → fails (no `frame(for:in:)` overload).

- [ ] **Step 4: Implement the overload in `WindowLayout.swift`** (append inside `enum WindowLayout`)

```swift
    static func frame(for preset: WindowPreset, in rect: CGRect) -> CGRect {
        func resolve(_ mode: PresetSizeMode, _ value: Double, axis: CGFloat) -> CGFloat {
            let raw = mode == .percent ? axis * CGFloat(value) : CGFloat(value)
            return min(max(raw, 1), axis)   // clamp to the display
        }
        let w = resolve(preset.widthMode, preset.width, axis: rect.width)
        let h = resolve(preset.heightMode, preset.height, axis: rect.height)

        var x: CGFloat
        switch preset.anchor {
        case .center, .top, .bottom:            x = rect.minX + (rect.width - w) / 2
        case .left, .topLeft, .bottomLeft:      x = rect.minX
        case .right, .topRight, .bottomRight:   x = rect.maxX - w
        }
        var y: CGFloat
        switch preset.anchor {  // AX space: y increases downward, so .top == minY
        case .center, .left, .right:            y = rect.minY + (rect.height - h) / 2
        case .top, .topLeft, .topRight:         y = rect.minY
        case .bottom, .bottomLeft, .bottomRight: y = rect.maxY - h
        }
        return CGRect(x: x + CGFloat(preset.xOffset), y: y + CGFloat(preset.yOffset), width: w, height: h)
    }
```

- [ ] **Step 5: Run tests, expect pass.** Then **clean Release build** succeeds.

- [ ] **Step 6: Commit** — `git add StashApp/Sources/StashApp/Windows/WindowPreset.swift StashApp/Sources/StashApp/Windows/WindowLayout.swift StashApp/Tests/StashAppTests/WindowPresetLayoutTests.swift && git commit -m "feat(app): WindowPreset model + pure preset frame computation"`

---

### Task 2: GRDB migration + WindowPresetStore

**Files:**
- Modify: `StashApp/Sources/StashApp/Data/Database.swift` (add migration after `v7_task_due_at`)
- Create: `StashApp/Sources/StashApp/Data/WindowPresetStore.swift`
- Test: `StashApp/Tests/StashAppTests/WindowPresetStoreTests.swift`

**Interfaces:**
- Consumes: `WindowPreset` (Task 1).
- Produces: `WindowPresetStore` with `init(pool: any DatabaseWriter)`, `func all() throws -> [WindowPreset]`, `func upsert(_:) throws`, `func delete(id:) throws`. Table `window_presets`.

- [ ] **Step 1: Add the migration in `Database.swift`** (register AFTER the `v7_task_due_at` block, same `m.registerMigration` pattern)

```swift
        m.registerMigration("v8_window_presets") { db in
            if try !db.tableExists("window_presets") {
                try db.create(table: "window_presets") { t in
                    t.column("id", .text).primaryKey()
                    t.column("name", .text).notNull()
                    t.column("widthMode", .text).notNull()
                    t.column("width", .double).notNull()
                    t.column("heightMode", .text).notNull()
                    t.column("height", .double).notNull()
                    t.column("anchor", .text).notNull()
                    t.column("xOffset", .double).notNull().defaults(to: 0)
                    t.column("yOffset", .double).notNull().defaults(to: 0)
                    t.column("displayMode", .text).notNull().defaults(to: "active")
                    t.column("displayIndex", .integer).notNull().defaults(to: 0)
                    t.column("hotkeyKeyCode", .integer)
                    t.column("hotkeyModifiers", .integer)
                    t.column("createdAt", .integer).notNull()
                }
            }
        }
```

- [ ] **Step 2: Write the failing test** — `WindowPresetStoreTests.swift` (in-memory GRDB; mirror how other store tests build a queue — use `DatabaseQueue()` + run the app's migrator, or create the table inline if the migrator isn't easily reachable in tests; prefer running `AppDatabase`'s migrator if a test helper exists).

```swift
import Testing
import GRDB
@testable import StashApp

@Suite struct WindowPresetStoreTests {
    func makeStore() throws -> WindowPresetStore {
        let q = try DatabaseQueue()
        try q.write { db in
            try db.create(table: "window_presets") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("widthMode", .text).notNull(); t.column("width", .double).notNull()
                t.column("heightMode", .text).notNull(); t.column("height", .double).notNull()
                t.column("anchor", .text).notNull()
                t.column("xOffset", .double).notNull().defaults(to: 0)
                t.column("yOffset", .double).notNull().defaults(to: 0)
                t.column("displayMode", .text).notNull().defaults(to: "active")
                t.column("displayIndex", .integer).notNull().defaults(to: 0)
                t.column("hotkeyKeyCode", .integer); t.column("hotkeyModifiers", .integer)
                t.column("createdAt", .integer).notNull()
            }
        }
        return WindowPresetStore(pool: q)
    }

    func sample(_ id: String, _ created: Int64) -> WindowPreset {
        WindowPreset(id: id, name: "P\(id)", widthMode: .percent, width: 0.5, heightMode: .percent,
                     height: 1.0, anchor: .left, xOffset: 0, yOffset: 0, displayMode: "active",
                     displayIndex: 0, hotkeyKeyCode: nil, hotkeyModifiers: nil, createdAt: created)
    }

    @Test func upsertAllDeleteRoundTrip() throws {
        let store = try makeStore()
        try store.upsert(sample("a", 1)); try store.upsert(sample("b", 2))
        #expect(try store.all().map(\.id) == ["a", "b"])           // ordered by createdAt
        try store.upsert(sample("a", 1))                            // upsert is idempotent
        #expect(try store.all().count == 2)
        try store.delete(id: "a")
        #expect(try store.all().map(\.id) == ["b"])
    }
}
```

- [ ] **Step 3: Run test, expect failure** (no `WindowPresetStore`).

- [ ] **Step 4: Implement `WindowPresetStore.swift`** (mirror `TasksStore`)

```swift
import GRDB

struct WindowPresetStore {
    let pool: any DatabaseWriter
    init(pool: any DatabaseWriter) { self.pool = pool }

    func all() throws -> [WindowPreset] {
        try pool.read { try WindowPreset.order(Column("createdAt")).fetchAll($0) }
    }
    func upsert(_ preset: WindowPreset) throws {
        try pool.write { try preset.save($0) }
    }
    func delete(id: String) throws {
        try pool.write { _ = try WindowPreset.deleteOne($0, key: id) }
    }
}
```

- [ ] **Step 5: Run tests, expect pass.** Clean Release build succeeds.

- [ ] **Step 6: Commit** — `…&& git commit -m "feat(app): window_presets migration + WindowPresetStore"`

---

### Task 3: WindowSnapper — multi-display + snap(preset) + move-to-next-display

**Files:**
- Modify: `StashApp/Sources/StashApp/Windows/WindowSnapper.swift`

**Interfaces:**
- Consumes: `WindowPreset`, `WindowLayout.frame(for:in:)` (Task 1), existing `ScreenGeometry.axFrame(fromAppKit:primaryHeight:)`, the existing `lastActiveApp` tracker + `isTrusted`.
- Produces: `func snap(_ preset: WindowPreset)`, `func moveToNextDisplay()`, and built-in `snap(_ target: SnapTarget)` now uses the **active** display (the screen under the focused window) instead of `NSScreen.main`.

- [ ] **Step 1: Add screen resolution + a shared apply path.** In `WindowSnapper`, factor the existing `snap(_:SnapTarget)` AX work into a private helper that, given a target `NSScreen` and a closure producing the frame from that screen's visible rect (in AX coords), sets `kAXPosition`/`kAXSize` on the last-active app's focused window. Keep the `AXIsProcessTrusted()` guard (else `AccessibilityAuthorizer.requestOnce()`) and the `lastActiveApp` targeting.

```swift
    // Resolve the NSScreen for a preset's display choice. `active` = the screen most
    // overlapping the focused window's frame; falls back to .main.
    private func resolveScreen(displayMode: String, displayIndex: Int, windowAXFrame: CGRect?) -> NSScreen? {
        switch displayMode {
        case "main": return NSScreen.main
        case "index":
            let screens = NSScreen.screens
            return displayIndex >= 0 && displayIndex < screens.count ? screens[displayIndex] : NSScreen.main
        default: // "active"
            guard let f = windowAXFrame else { return NSScreen.main }
            let primaryH = NSScreen.screens.first?.frame.height ?? 0
            // Compare in AX space: convert each screen's AppKit frame to AX, pick max overlap.
            return NSScreen.screens.max { a, b in
                let aa = ScreenGeometry.axFrame(fromAppKit: a.frame, primaryHeight: primaryH).intersection(f)
                let bb = ScreenGeometry.axFrame(fromAppKit: b.frame, primaryHeight: primaryH).intersection(f)
                return (aa.width * aa.height) < (bb.width * bb.height)
            } ?? NSScreen.main
        }
    }
```

- [ ] **Step 2: Read the focused window's current AX frame** (needed for "active" display + move-to-next). Add a helper that returns the focused `AXUIElement` of `lastActiveApp` and its current frame (read `kAXPositionAttribute`/`kAXSizeAttribute` via `AXValueGetValue`). Reuse the existing app/window lookup from `snap(_:SnapTarget)` (the `lastActiveApp` → `AXUIElementCreateApplication` → `kAXFocusedWindowAttribute` chain).

- [ ] **Step 3: Implement `snap(_ preset:)`**

```swift
    func snap(_ preset: WindowPreset) {
        guard AXIsProcessTrusted() else { AccessibilityAuthorizer.requestOnce(); return }
        guard let (window, currentAXFrame) = focusedWindow() else { return }       // helper from Step 2
        let screen = resolveScreen(displayMode: preset.displayMode,
                                   displayIndex: preset.displayIndex,
                                   windowAXFrame: currentAXFrame) ?? NSScreen.main
        guard let screen else { return }
        let primaryH = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let visibleAX = ScreenGeometry.axFrame(fromAppKit: screen.visibleFrame, primaryHeight: primaryH)
        let frame = WindowLayout.frame(for: preset, in: visibleAX)
        setFrame(window, frame)   // shared AX set helper (factored from existing snap)
    }
```

- [ ] **Step 4: Update built-in `snap(_:SnapTarget)`** to use the active display: resolve the screen via `resolveScreen(displayMode: "active", displayIndex: 0, windowAXFrame: currentAXFrame)` instead of `NSScreen.main`. The rest (`WindowLayout.frame(for: target, in: visibleAX, gap: 8)`) is unchanged.

- [ ] **Step 5: Implement `moveToNextDisplay()`** — resolve the current screen (active), pick the next `NSScreen.screens` entry (wrap around), and re-apply the window's current relative position on the new screen (simplest correct: place full-screen on the new display, or preserve the fractional rect — preserve fractional: compute the window's fraction of its current screen's visible rect, apply the same fraction on the next screen). Implement the fractional-preserve version.

- [ ] **Step 6: Build + tests + LAUNCH-RUN verification.**

Run: clean Release build → SUCCEEDED; full suite → all pass.
Then launch-run to prove no concurrency crash:
```bash
B4=$(ls ~/Library/Logs/DiagnosticReports/ | grep -ic stash)
.build-release/Build/Products/Release/StashApp.app/Contents/MacOS/StashApp >/tmp/r.log 2>&1 & P=$!
sleep 6; kill -0 $P 2>/dev/null && echo ALIVE || echo CRASHED
[ "$(ls ~/Library/Logs/DiagnosticReports/ | grep -ic stash)" = "$B4" ] && echo "no new crash" || echo "NEW CRASH"
pkill -f Release/StashApp.app
```
Expected: `ALIVE` + `no new crash`.

- [ ] **Step 7: Commit** — `…&& git commit -m "feat(app): multi-display snapping + snap(preset) + move-to-next-display"`

---

### Task 4: Windows tab — Presets section + editor + wiring

**Files:**
- Modify: `StashApp/Sources/StashApp/App/AppEnvironment.swift` (own `WindowPresetStore`; expose `presets` + the snapper; CRUD helpers; GRDB observation)
- Modify: `StashApp/Sources/StashApp/Windows/WindowsTab.swift` (Presets section + wire to snapper)
- Create: `StashApp/Sources/StashApp/Windows/WindowPresetEditor.swift` (the add/edit sheet)
- Modify: `StashApp/Sources/StashApp/StashApp.swift` (pass presets + CRUD + snapper to `WindowsTab`)

**Interfaces:**
- Consumes: `WindowPresetStore`, `WindowPreset`, `snapper.snap(preset)`.
- Produces: `AppEnvironment.windowPresets: [WindowPreset]` (observed, `@Observable`/published), `func saveWindowPreset(_:)`, `func deleteWindowPreset(id:)`. `WindowsTab(snapper:presets:onSave:onDelete:)`.

- [ ] **Step 1: AppEnvironment** — add `let windowPresetStore = WindowPresetStore(pool: …same pool as other stores…)`; an observed `windowPresets` array kept live via GRDB `ValueObservation` (mirror how tasks/notes observe; if the app uses a single shared `DatabaseWriter`, reuse it). Add `func saveWindowPreset(_ p: WindowPreset)` (upsert + the observation refreshes) and `func deleteWindowPreset(id: String)`. Expose the existing `snapper` (already `let` from a prior fix).

- [ ] **Step 2: `WindowPresetEditor.swift`** — a sheet (mirror `SnippetEditorSheet` in `SnippetsTab.swift` for style/state): fields for `name`; width value + a `%`/`pt` `Picker` (`PresetSizeMode`); height value + `%`/`pt`; an **anchor picker** (a 3×3 grid of toggle buttons mapping to `PresetAnchor`, center = the middle); `xOffset`/`yOffset` steppers; a **display Picker** (`Active`, `Main`, then `Display 1…NSScreen.screens.count` → `displayMode:"index", displayIndex:i`); and a **hotkey** field (Task 5 wires registration — here just capture `hotkeyKeyCode`/`hotkeyModifiers`, or leave the control present but inert until Task 5). On Save, build a `WindowPreset` (new UUID + `createdAt = Int64(Date().timeIntervalSince1970*1000)` for new; preserve for edits) and call `onSave`. Percent inputs shown 0–100, stored ÷100.

- [ ] **Step 3: WindowsTab Presets section** — add `let presets: [WindowPreset]`, `let onSave/onDelete/onSnapPreset` closures (or pass the env). Below the built-in `snapGrid`, add a "Presets" `groupSection`-style block: a tile per preset (name + a `miniDiagram`-style mock using `WindowLayout.frame(for: preset, in: diagramRect)`) whose tap calls `onSnapPreset(preset)` (→ `snapper.snap(preset)`); a trailing **"+ New"** tile opening the editor; hover/long-press for Edit/Delete. Keep the `!snapper.isTrusted` "Enable Accessibility" affordance.

- [ ] **Step 4: StashApp.swift** — update `case .windows:` to pass the presets + CRUD + snapper, e.g. `WindowsTab(snapper: env.snapper, presets: env.windowPresets, onSave: { env.saveWindowPreset($0) }, onDelete: { env.deleteWindowPreset(id: $0) })`.

- [ ] **Step 5: Build + tests + LAUNCH-RUN** (same verification block as Task 3, Step 6) → `ALIVE` + `no new crash`. Manually: add a preset, see its tile, snap a window to it on a second display.

- [ ] **Step 6: Commit** — `…&& git commit -m "feat(app): Windows-tab custom preset section + editor"`

---

### Task 5: Triggers — per-preset hotkeys + stash://snap?preset deeplink

**Files:**
- Modify: `StashApp/Sources/StashApp/App/AppEnvironment.swift` (register preset hotkeys; deeplink case)

**Interfaces:**
- Consumes: `windowPresets`, `snapper.snap(preset)`, existing `GlobalHotKey(keyCode: UInt32, modifiers: UInt32, handler:)` (failable) + the `globalHotkeysEnabled` gate + `handleDeeplink`.

- [ ] **Step 1: Register preset hotkeys** — add `private var presetHotKeys: [GlobalHotKey] = []` and `func registerPresetHotKeys()` mirroring `registerSnapHotKeys()`: for each preset with non-nil `hotkeyKeyCode`/`hotkeyModifiers`, create a `GlobalHotKey(keyCode: UInt32(code), modifiers: UInt32(mods), handler: { [weak self] in self?.snapper.snap(preset) })`. Clear + re-register whenever `windowPresets` changes (call from the observation callback) and respect `globalHotkeysEnabled` (only register when enabled — mirror how `applyHotkeys()` gates the others). On disable, set `presetHotKeys = []`.

- [ ] **Step 2: Deeplink** — extend the existing `case "snap":` in `handleDeeplink` so that if `q("preset")` is present, look it up by name (case-insensitive) in `windowPresets` and `snapper.snap(preset)`; otherwise keep the existing `target` behavior.

```swift
        case "snap":
            if let name = q("preset"),
               let preset = windowPresets.first(where: { $0.name.lowercased() == name.lowercased() }) {
                snapper.snap(preset)
            } else if let raw = q("target") ?? url.pathComponents.dropFirst(2).first,
                      let target = SnapTarget(rawValue: raw) {
                snapper.snap(target)
            }
```

- [ ] **Step 3: Build + tests + LAUNCH-RUN** (verification block) → `ALIVE` + `no new crash`. Manually: set a preset hotkey, trigger it; fire `open "stash://snap?preset=<name>"`.

- [ ] **Step 4: Commit** — `…&& git commit -m "feat(app): per-preset global hotkeys + stash://snap?preset deeplink"`

---

## Final verification (after all tasks)
- Clean Release build + full suite green (was 222 → +new preset-layout + store tests).
- Launch-run (Debug + Release): alive, zero new crash reports.
- Manual: create a preset (e.g. 65% left, full height, Display 2), snap via tile + hotkey + `stash://snap?preset=`; confirm built-ins now snap on the window's current display; confirm "move to next display".
- Note for the user: window snapping requires Accessibility; presets persist in the `window_presets` table.
