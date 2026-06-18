# Stash Slice 5a — Window management (rect engine + Windows tab demo)

**Goal:** A pure `WindowLayout` engine that computes target frames for snap regions (halves, quarters, thirds, full) given a screen rect + gap, plus the hub **Windows tab** with the Raycast-style snap grid and an animated demo window (like the prototype). Fully testable (engine). Applying frames to the real focused window via AXUIElement + global hotkeys is **Slice 5b — DEFERRED** (needs Accessibility permission + live session).

## Decisions
- `WindowLayout` works in a top-left-origin rect convention for the in-app demo (SwiftUI coordinates). For 5b (AppKit/AX screen coords are bottom-left), a conversion happens at the boundary — out of scope here; the engine is geometry-pure and convention is documented.
- Snap targets match the prototype groups: HALVES (left, right, top, bottom), QUARTERS (4 corners), THIRDS (left, center, right third; left-two-thirds, right-two-thirds), FULL.

## Global Constraints
Same as prior slices. Swift Testing; full suite; `xcodegen generate`; commit trailer `Claude-Session: https://claude.ai/code/session_015v4jqLe8vCM5hYdh17AHWe`; no banner comments; reuse Tokens; Windows tab is inside the fixed-height hub (no collapse).

---

### Task W1: SnapTarget + WindowLayout engine (TDD)
**Files:** Create `Windows/SnapTarget.swift`, `Windows/WindowLayout.swift`; Test `Tests/StashAppTests/WindowLayoutTests.swift`.
```swift
enum SnapTarget: String, CaseIterable, Identifiable, Sendable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centerThird, rightThird, leftTwoThirds, rightTwoThirds
    case fullScreen
    var id: String { rawValue }
    var label: String { ... "Left Half","Right Half","Top Half","Bottom Half","Top Left",... "Left Third","Center Third","Right Third","Left Two Thirds","Right Two Thirds","Full Screen" }
    var hotkey: String { ... e.g. leftHalf "⌃⌥←", rightHalf "⌃⌥→", topHalf "⌃⌥↑", bottomHalf "⌃⌥↓", fullScreen "⌃⌥↩", thirds "⌃⌥U/I/O" ... (reasonable Rectangle-style defaults) }
    var group: String { "Halves" | "Quarters" | "Thirds" | "Full Screen" }
}

enum WindowLayout {
    /// `screen` is the usable area (origin + size); `gap` is the inset applied between the window and screen edges/each other.
    static func frame(for target: SnapTarget, in screen: CGRect, gap: CGFloat) -> CGRect
}
```
Geometry (top-left origin; apply `gap` as a uniform inset so adjacent regions have a 2*gap visual gutter — i.e. each region is inset by `gap` on every side it doesn't share... keep it simple: compute the base region, then `.insetBy(dx: gap, dy: gap)`):
- fullScreen = whole screen inset by gap.
- leftHalf = left 50% width, full height; rightHalf = right 50%; topHalf = top 50% height; bottomHalf = bottom 50%.
- quarters = the four width/2 × height/2 corners.
- leftThird/centerThird/rightThird = width/3 columns, full height; leftTwoThirds = left 2/3; rightTwoThirds = right 1/3 offset (i.e. right two-thirds region).
Each result is the base rect `.insetBy(dx: gap, dy: gap)`.
Tests (use screen `CGRect(x:0,y:0,width:1000,height:800)`, gap `10`): leftHalf origin.x==10, width==500-20, height==800-20; rightHalf origin.x==500+10; topLeft is the top-left 500×400 inset; centerThird origin.x≈333+10, width≈333-20; fullScreen == 1000×800 inset by 10; leftTwoThirds width≈666-20; all 14 targets produce a frame inside the screen. Assert with small tolerance for the /3 divisions. RED→GREEN→commit `feat(app): add window snap layout engine`.

---

### Task W2: Windows tab (demo grid + animated preview) (build)
**Files:** Create `Windows/WindowsTab.swift`; modify `StashApp.swift` (route `.windows`). (No AppEnvironment data needed — this tab is self-contained demo state.)
WindowsTab: grouped snap cards (HALVES / QUARTERS / THIRDS / FULL SCREEN). Each card: a small mini-diagram (a 38×25 rounded rect with the target region highlighted in `Tokens.accent`, computed via `WindowLayout.frame(for:in:gap:)` scaled into the 38×25 box) + the `label` + the `hotkey` (monospaced). A `@State var activeTarget: SnapTarget?`. Clicking a card sets activeTarget and animates a demo "Safari" window (a labeled rounded rect inside a ~360×200 "screen" preview area) to `WindowLayout.frame(for: activeTarget, in: previewScreen, gap: 6)` with `.animation(.easeInOut(duration: 0.34))`. A toast "Snapped: \(label)". Route `case .windows: WindowsTab()`.
Build + full suite green (no new tests; engine already covered). App launches without crash. Commit `feat(app): add Windows tab with snap demo`.

## Notes
- The engine is the testable brain; the tab is a visual demo only (no real window control until 5b).
- Keep the mini-diagram + preview math driven by `WindowLayout` so they stay consistent with the engine.
