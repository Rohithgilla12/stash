# Stash Slice 3 — Desktop sticky notes + ⌥Space

**Goal:** Notes flagged `on_desktop = true` appear as floating borderless paper sticky `NSWindow`s on the desktop (warm pastel, slight rotation, pin dot, title + body/checklist). A global **⌥Space** hotkey fades all stickies out/in together. Stickies are driven by the same note data, so edits sync; clicking a sticky opens it in the Notes editor window. No special permission required (`RegisterEventHotKey` + floating windows need neither Accessibility nor sandbox exceptions).

## Decisions
- A `StickyNotesManager` (`@MainActor`) observes `NotesViewModel.notes`, filters `on_desktop`, and diffs to create/update/close one borderless `NSWindow` per sticky. Windows are `.floating` level, non-activating, draggable, no titlebar.
- ⌥Space via a minimal Carbon `RegisterEventHotKey` wrapper (no new SPM dependency). Toggling sets all sticky windows' `alphaValue` (animated) and tracks a `visible` flag.
- Sticky position: persist later; for v1, lay them out in a cascade from the top-right of the main screen (deterministic, non-overlapping-ish). Position persistence is out of scope (no schema change this slice).
- Clicking a sticky body opens the Notes window for that note (via `OpenWindowAction.openActivating` + selecting the note). Keep it simple: a button/tap that calls into the notes VM + opens the window.

## Global Constraints
Same as prior slices. Swift 6 strict concurrency (`StickyNotesManager` is `@MainActor`). `xcodegen generate` after adding files. Commit trailer `Claude-Session: https://claude.ai/code/session_015v4jqLe8vCM5hYdh17AHWe`. No banner comments. Reuse Tokens + the README sticky pastels (yellow `#fdf0c2`/`#c8642f`, peach `#fcdcc6`/`#b97a4a`, blue `#d4e4f2`/`#5b86b8`, mint `#d9ecda`/`#5e8a52`). Determinate sticky window sizes (e.g. 220×220).

---

### Task K1: GlobalHotKey wrapper (⌥Space) + StickyLayout (TDD where possible)
**Files:** Create `Stickies/GlobalHotKey.swift`, `Stickies/StickyLayout.swift`; Test `Tests/StashAppTests/StickyLayoutTests.swift`.
- `GlobalHotKey`: a small class wrapping Carbon `RegisterEventHotKey` + `InstallEventHandler`. API: `init?(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void)` and `deinit` unregisters. For ⌥Space: keyCode `49` (space), modifiers `optionKey` (Carbon `UInt32(optionKey)`). The handler is invoked on the main thread. (Carbon boilerplate is fine — this is the standard, permission-free global-hotkey mechanism. Reference the well-known pattern: store an `EventHotKeyRef`, install a handler on `GetApplicationEventTarget()` for `kEventClassKeyboard`/`kEventHotKeyPressed`, dispatch to the stored handler via a hot-key id.)
- `StickyLayout` (PURE, testable): `static func frame(index: Int, in screen: CGRect, size: CGSize) -> CGRect` — cascades stickies from the top-right of `screen` down-left by a fixed step (e.g. 30pt), wrapping if needed; returns a `CGRect` (AppKit bottom-left origin within `screen`). Tests: index 0 sits near top-right (origin.x == screen.maxX - size.width - margin; origin.y == screen.maxY - size.height - margin), index 1 is offset by the step, all frames intersect the screen.
RED→GREEN→commit `feat(app): add global hotkey wrapper + sticky layout`.

---

### Task K2: StickyNoteView + StickyNotesManager (build + visual verify)
**Files:** Create `Stickies/StickyNoteView.swift`, `Stickies/StickyNotesManager.swift`; modify `App/AppEnvironment.swift` (own the manager; register ⌥Space in `start()`), and the Notes window's "Pin to desktop" already persists `on_desktop` (no change needed).
- `StickyNoteView`: a SwiftUI view for one `Note` — paper-pastel background (from `note.color`), slight rotation (deterministic by note id hash, ±3°), a pin dot at top, the title + (for `.text`) the body, or (for `.todo`) a compact checklist (read-only toggles that write through `NotesViewModel.update`). A tap anywhere (except the checklist) opens the editor.
- `StickyNotesManager` (`@MainActor`, `@Observable` not required): holds `private var windows: [String: NSWindow]` and `private(set) var visible = true`. Method `sync(notes: [Note])` — for notes with `on_desktop == true`: create a window if absent (borderless, `.floating` level, `isMovableByWindowBackground = true`, `backgroundColor = .clear`, hosting an `NSHostingView(rootView: StickyNoteView(...))`, framed via `StickyLayout.frame(index:in:size:)` on `NSScreen.main!.visibleFrame`), or update its hosting view's note; for windows whose note is no longer pinned/absent, close + remove. Method `toggleVisibility()` — animate all windows' `alphaValue` 1↔0 over 0.3s and flip `visible`. Method `setHotKey()` wiring the ⌥Space `GlobalHotKey` to `toggleVisibility()`.
- `AppEnvironment`: construct the manager; observe `notesViewModel.notes` (e.g. start a `Task`/`withObservationTracking` loop, or a small Combine-free observation) and call `manager.sync(notes:)`; register the ⌥Space hotkey in `start()`. Simplest observation: since `NotesViewModel` is `@Observable`, drive sync from a `ValueObservation` on the DB OR re-use the notes VM by polling its `notes` via `withObservationTracking` re-registration. Cleanest: give the manager its own GRDB `ValueObservation` of `Note.filter(Column("on_desktop") == true)` so it's independent of the UI VM.

**Visual verification (REQUIRED):** build, run, set a note's `on_desktop=1` in the DB (or via the Notes editor "Pin to desktop"), confirm a floating sticky appears on the desktop (screenshot the desktop), then trigger ⌥Space (`cliclick kd:alt t:" " ku:alt` or `cliclick kd:alt kp:space ku:alt`) and confirm the sticky fades out; trigger again to fade in. Screenshot both states.
Commit `feat(app): add desktop sticky notes with ⌥Space toggle`.

## Notes
- Borderless floating window recipe: `NSWindow(contentRect:styleMask:[.borderless], backing:.buffered, defer:false)`; `level = .floating`; `isOpaque = false`; `backgroundColor = .clear`; `hasShadow = true`; `isMovableByWindowBackground = true`; `collectionBehavior = [.canJoinAllSpaces, .stationary]`; `orderFrontRegardless()`.
- The manager owns NSWindows (AppKit) bridged from a SwiftUI app — fine. Keep all NSWindow work `@MainActor`.
- Keep StickyLayout + the hotkey keycodes pure/testable; the window plumbing is verified visually.
