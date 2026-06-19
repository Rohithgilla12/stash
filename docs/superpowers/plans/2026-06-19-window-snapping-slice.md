# Stash Slice 5b — Real window snapping (Accessibility)

**Goal:** Apply the `WindowLayout` snap frames to the **focused window of the frontmost app** via the Accessibility API, driven by global snap hotkeys (⌃⌥←/→/↑/↓, ⌃⌥↩ full, ⌃⌥ U/I/J/K quarters). The pure `WindowLayout` engine (slice 5a) is reused; this adds the AX application layer + a tested coordinate conversion + permission handling.

**Needs Accessibility permission** (AXUIElement on other apps). First snap attempt prompts; the user grants it once in System Settings → Privacy & Security → Accessibility.

## Decisions
- Hotkey-driven (not card-driven): the frontmost app at hotkey time IS the target (the hotkey doesn't steal focus). The Windows-tab cards stay a demo (slice 5a).
- Coordinate conversion is a PURE function (`ScreenGeometry.axFrame(fromAppKit:primaryHeight:)`) — the main correctness risk, fully unit-tested. AX uses top-left origin of the PRIMARY display (y down); AppKit uses bottom-left (y up). Flip: `axY = primaryHeight - (appKitY + height)`; x unchanged.
- Reuse `GlobalHotKey` (slice 3) for each snap hotkey. `GlobalHotKey.init?` is failable — log (don't crash) if a combo is already claimed.

## Global Constraints
Same as prior slices. Swift Testing; full suite; `xcodegen generate`; commit trailer `Claude-Session: https://claude.ai/code/session_015v4jqLe8vCM5hYdh17AHWe`; no banner comments; reuse `WindowLayout`/`SnapTarget`/`GlobalHotKey`. `@MainActor` for the snapper; AX calls on main.

---

### Task S1: ScreenGeometry conversion + SnapHotKey mapping (TDD)
**Files:** Create `Windows/ScreenGeometry.swift`, `Windows/SnapHotKey.swift`; Test `Tests/StashAppTests/ScreenGeometryTests.swift`.
- `enum ScreenGeometry { static func axFrame(fromAppKit rect: CGRect, primaryHeight: CGFloat) -> CGRect }` — returns a rect with the same x/width/height but `y = primaryHeight - (rect.minY + rect.height)` (flip into AX top-left global space). PURE.
- `struct SnapHotKey { let target: SnapTarget; let keyCode: UInt32; let modifiers: UInt32 }` + `static let all: [SnapHotKey]` mapping each `SnapTarget` to a keycode + Carbon modifiers (`controlKey | optionKey` for all). Keycodes: left 123, right 124, down 125, up 126, return 36; U 32, I 34, J 38, K 40; for thirds use D 2, F 3, G 5 (leftThird/centerThird/rightThird) and leave leftTwoThirds/rightTwoThirds out of the global set (avoid hotkey sprawl) OR map them to E 14 / T 17. Keep `all` to the 4 halves + full + 4 quarters + 3 thirds (12 entries).
Tests (ScreenGeometryTests): a window at AppKit `(0,0,800,600)` on a 1440-tall primary → axY = 1440-(0+600)=840, so axFrame == (0,840,800,600); a top-aligned window AppKit `(0, 1440-600, 800,600)` → axY = 1440-((840)+... compute) verify top maps to ax y≈0; width/height/x unchanged. Also assert `SnapHotKey.all` has the expected count and no duplicate (keyCode,modifiers) pairs.
RED→GREEN→commit `feat(app): add AX coordinate conversion + snap hotkey map`.

---

### Task S2: WindowSnapper (AX) + wiring (build + permission-gated verify)
**Files:** Create `Windows/WindowSnapper.swift`; modify `App/AppEnvironment.swift` (own a `WindowSnapper`; register the snap hotkeys in `start()`).
- `@MainActor final class WindowSnapper`:
  - `var isTrusted: Bool { AXIsProcessTrusted() }`.
  - `func ensureTrusted()` — if not trusted, call `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeRetainedValue(): true])` to show the system prompt.
  - `func snap(_ target: SnapTarget)`:
    1. `guard AXIsProcessTrusted() else { ensureTrusted(); return }`.
    2. `guard let app = NSWorkspace.shared.frontmostApplication, app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }` (don't snap Stash itself).
    3. `let axApp = AXUIElementCreateApplication(app.processIdentifier)`; copy `kAXFocusedWindowAttribute` → the window element. Bail if none.
    4. Determine the window's screen: read its current AX position, convert back to AppKit to find which `NSScreen` it's on (or default to `NSScreen.main`). Use that screen's `visibleFrame` (AppKit) as the `WindowLayout` input. Compute `let target = WindowLayout.frame(for: target, in: visibleFrameTopLeftOrigin, gap: 8)`. NOTE: WindowLayout works in top-left origin already (slice 5a) — feed it the screen's usable area expressed in top-left global AX coords (origin = screen's top-left in AX space; size = visibleFrame size). Then set the window's `kAXPositionAttribute` (an `AXValue` of `CGPoint`) and `kAXSizeAttribute` (`AXValue` of `CGSize`). Use `ScreenGeometry`/the AX origin of the screen consistently — document the chosen reference frame in comments.
  - Use `AXValueCreate(.cgPoint, ...)` / `AXValueCreate(.cgSize, ...)` and `AXUIElementSetAttributeValue`.
- `AppEnvironment.start()`: create the snapper; for each `SnapHotKey.all`, register a `GlobalHotKey(keyCode:modifiers:) { [weak self] in self?.snapper.snap(hk.target) }`; keep the `GlobalHotKey` refs alive (store the array). Call `snapper.ensureTrusted()` once on first launch so the prompt appears.

**Verification:**
- Build + full suite stays green (S1 tests cover the math).
- Permission-gated live test: run the app; if `AXIsProcessTrusted()` is false, the controller will be told to grant Accessibility to the built app, then re-run. With permission: focus another app's window (e.g. a Finder/TextEdit window), press ⌃⌥← and confirm it snaps to the left half (screenshot before/after). If permission can't be granted in this session, report that the math is tested + build is green and snapping is pending a permission grant.
Commit `feat(app): add AX window snapper + global snap hotkeys`.

## Notes
- AX coordinate frame is the #1 risk — keep `ScreenGeometry` pure + tested, and document precisely which origin each step uses.
- `kAXTrustedCheckOptionPrompt` lives in `ApplicationServices`. `import ApplicationServices` (and `AppKit`).
- Multi-display: for v1, default to `NSScreen.main`; full multi-display handling can be a follow-up.
