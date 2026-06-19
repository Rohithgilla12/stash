# Stash — Paste-style clipboard browser (⌃⌥V)

**Goal:** A global hotkey (⌃⌥V) pops up a full-width, keyboard-navigable strip of large clipboard cards (à la Paste.app). Arrow keys move selection, Enter pastes into the previously-focused app, Esc closes, typing filters. Permission-free trigger (RegisterEventHotKey); auto-paste is best-effort (works when Accessibility is granted, otherwise the item lands on the clipboard).

## Design (warm, per .impeccable.md)
- A frosted warm panel (`Tokens.panelFill`, rounded 18, soft shadow) centered horizontally, sitting in the lower third of the main screen, ~min(1100, screen*0.86) wide × ~300 tall.
- Top: a search field (reuses the clipboard query feel). Middle: a horizontal `ScrollView` of `PasteCardView`s. Bottom: a hint bar "↵ Paste   ⎋ Close   ← → Navigate" in tertiary.
- `PasteCardView` (~200×220, rounded 12): kind-aware big preview (full wrapped text in `Font.ui(12)`; image large; **color swatch** fills the card for hex; link shows domain + url), a top type `Chip`, a footer meta line (`ClipPresentation.metaLine`). Selected card: `Tokens.accent` 2pt ring + subtle scale (1.0→1.03) + brighter surface. Reuse `ClipPresentation`/`Tokens`/`Components`.

## Plan
### Task P1: PasteBrowserController (AppKit panel + hotkey + paste)
`StashApp/Sources/StashApp/PasteBrowser/PasteBrowserController.swift` — `@MainActor final class`:
- A custom `final class KeyablePanel: NSPanel { override var canBecomeKey: Bool { true } }`.
- Owns: the panel, a `GlobalHotKey?` (keyCode 9 = V, modifiers `UInt32(controlKey | optionKey)`), `private weak var previousApp: NSRunningApplication?`, and a callback to fetch current items + a paste closure.
- `registerHotKey()` → toggle on ⌃⌥V. `toggle()`: if visible → hide; else capture `NSWorkspace.shared.frontmostApplication` into previousApp, build/refresh the SwiftUI content (`PasteBrowserView`) hosted in an `NSHostingView`, size+center the panel in the lower third of `NSScreen.main`, `makeKeyAndOrderFront`, activate the app so the panel is key.
- `paste(_ item: ClipItem)`: write the item to `NSPasteboard.general` (text, or image from previewPath); `hide()`; `previousApp?.activate()`; then after ~80ms post ⌘V (CGEvent keyDown/up of keyCode 9 with `.maskCommand`, to `.cghidEventTap`) — best-effort. 
- `hide()`: orderOut; reactivate previousApp.
- The controller exposes `var items: [ClipItem]` (kept synced) and is given an `onPaste`/uses its own paste.

### Task P2: PasteBrowserView + PasteCardView (SwiftUI)
`StashApp/Sources/StashApp/PasteBrowser/PasteBrowserView.swift` + `PasteCardView.swift`:
- `PasteBrowserView`: takes `items: [ClipItem]`, `onPaste: (ClipItem) -> Void`, `onClose: () -> Void`. `@State selection: Int`, `@State query: String`. Filters items by query. Horizontal `ScrollViewReader` + `ScrollView(.horizontal)` of cards; selected card scrolls into view. Keyboard via `.onKeyPress`: `.leftArrow`/`.rightArrow` move selection (clamp), `.return` → `onPaste(filtered[selection])`, `.escape` → `onClose()`. A focusable container (`@FocusState` + `.focusable()` + `.focused`) so key presses are received; request focus on appear. Search `TextField` bound to `query` (typing filters; keep arrow/enter working — if the field steals keys, put the key handling on the outer container and let typing append to query, OR keep a visible TextField that is focused and handle arrows/enter via `.onKeyPress` on it). Bottom hint bar.
- `PasteCardView`: per the design above.

### Task P3: Wire into AppEnvironment
`App/AppEnvironment.swift`: construct `PasteBrowserController`; in `start()` `registerHotKey()`; keep `controller.items` synced from the clipboard `ValueObservation`/`viewModel.items` (the clipboard VM already observes — push items to the controller too, OR give the controller a snapshot fetch via the store). Simplest: the controller holds a closure `itemsProvider: () -> [ClipItem]` returning `clipboardViewModel.items`, called on each toggle so it's always fresh.

## Constraints
Swift 6 strict concurrency (`@MainActor`); reuse `GlobalHotKey`, `ClipPresentation`, `Tokens`, `Components`, `ClipboardViewModel`. After changes `cd StashApp && xcodegen generate`; BUILD must succeed; full suite stays 136. No banner comments. Commit trailer. Permission-free trigger; auto-paste best-effort. The controller will visually verify (trigger ⌃⌥V, screenshot, paste into TextEdit).
