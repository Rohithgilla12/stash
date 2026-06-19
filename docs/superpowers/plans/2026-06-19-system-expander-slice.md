# Stash Slice 6b — System-wide text expander (CGEventTap)

**Goal:** When enabled, typing a snippet trigger (e.g. `:sig`) in ANY app expands it in place, using the already-tested `ExpansionEngine`. Built SAFELY.

## SAFETY (non-negotiable design constraints)
- **Listen-only tap.** Use `CGEventTapOptions.listenOnly` so the tap OBSERVES keyDown events and NEVER modifies/drops the event stream. Expansion is performed by separately POSTING new events (backspaces + the expansion text). A listen-only tap physically cannot mangle the user's typing.
- **Off by default.** A persisted `UserDefaults` flag `expanderEnabled` (default false). The tap is only installed when enabled. A toggle in the Snippets tab controls it.
- **Auto-reenable.** Handle `kCGEventTapDisabledByTimeout` / `...ByUserInput` by re-enabling the tap (macOS disables slow taps).
- **No expansion mid-password-ish:** out of scope to detect secure fields perfectly, but the trigger only fires on an exact known `:trigger` at a word boundary — incidental expansion is unlikely. (Honest limitation; note it.)
- Requires Accessibility permission (already granted). If not trusted when enabling, prompt (reuse `WindowSnapper.ensureTrusted` pattern or AX prompt).

## Global Constraints
Same as prior slices. Swift Testing; full suite; `xcodegen generate`; commit trailer `Claude-Session: https://claude.ai/code/session_015v4jqLe8vCM5hYdh17AHWe`; no banner comments; reuse `ExpansionEngine`/`Snippet`/Tokens. CGEventTap C callback uses an `Unmanaged` trampoline (like `GlobalHotKey`).

---

### Task E1: KeystrokeBuffer (pure, TDD)
**Files:** Create `Expansion/KeystrokeBuffer.swift`; Test `Tests/StashAppTests/KeystrokeBufferTests.swift`.
`struct KeystrokeBuffer` accumulates typed characters into a rolling buffer used for trigger matching:
- `mutating func append(_ s: String)` — append typed text (usually 1 char).
- `mutating func backspace()` — drop the last char (so the buffer tracks the user's deletes).
- `mutating func reset()` — clear (call on word-boundary keys: space, return, tab, arrows, escape, or a mouse click).
- `var value: String { get }` — current buffer (cap length, e.g. last 40 chars, to bound memory).
Tests: append builds the string; backspace removes last; reset clears; the buffer caps at 40 chars (appending more drops oldest). PURE. RED→GREEN→commit `feat(app): add keystroke buffer`.

---

### Task E2: SystemExpander (CGEventTap) + Snippets toggle + wiring (build + controlled live verify)
**Files:** Create `Expansion/SystemExpander.swift`; modify `Snippets/SnippetsTab.swift` (add an enable toggle bound to the VM), `Snippets/SnippetsViewModel.swift` (expose `expanderEnabled` persisted to UserDefaults + start/stop the expander), `App/AppEnvironment.swift` (own the `SystemExpander`, give it the current snippets; start it if `expanderEnabled`).
- `final class SystemExpander` (`@MainActor` for control methods; the C tap callback is a free function dispatching back):
  - `var snippets: [Snippet] = []` (kept in sync from the VM/observation).
  - `func setEnabled(_ on: Bool)` — install/remove the tap. Install: `CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: keyDown mask, callback: trampoline, userInfo: Unmanaged.passUnretained(self))`, add to the run loop, enable. Remove: disable + invalidate + remove run-loop source.
  - In the callback (on keyDown): get the unicode string via `event.keyboardGetUnicodeString`; if it's a boundary key (space/return/tab/arrows/esc) → `buffer.reset()` and return; if a normal char → `buffer.append(char)`, then `if let m = ExpansionEngine.match(buffer: buffer.value, snippets: snippets, now: Date())` → perform expansion: post `m.matchLength` backspaces (synthesize keyDown/keyUp of the delete key, keyCode 51) then post the expansion text via a CGEvent with `keyboardSetUnicodeString(...)`, and `buffer.reset()`. Use a small `usleep`/dispatch to sequence posts if needed. All event POSTS go to `.cghidEventTap`.
  - Handle `type == .tapDisabledByTimeout || .tapDisabledByUserInput` → re-enable the tap.
  - Dispatch from the C callback to the expansion logic on the main actor (the callback runs on the tap's run loop = main here).
- `SnippetsViewModel`: `var expanderEnabled: Bool` persisted to `UserDefaults.standard` (key "expanderEnabled"); on set, call the expander's `setEnabled`. Also keep `SystemExpander.snippets` in sync as `snippets` updates (the VM already observes them).
- `SnippetsTab`: a `Toggle("Expand snippets system-wide", isOn: $model.expanderEnabled)` near the top, with a short hint ("Requires Accessibility"). When toggled on and not trusted, prompt.
- `AppEnvironment`: construct `SystemExpander`; feed it snippets; if `expanderEnabled` persisted true, start it in `start()`.

## Verification (CONTROLLED — the expander is live on this machine)
- Build + full suite green (KeystrokeBuffer + reused ExpansionEngine tests cover the logic).
- Live test, carefully: enable the expander (via the toggle or by setting the UserDefault + relaunch), focus a NEW TextEdit document, type `hello :shrug ` and confirm `:shrug` expands to the kaomoji; type `:sig ` and confirm the signature appears. Screenshot. Then DISABLE the expander (toggle off / clear the UserDefault) so it is not left running. Because the tap is LISTEN-ONLY, normal typing is never dropped; only a completed trigger triggers injection.
Commit `feat(app): add system-wide text expander (off by default, listen-only)`.

## Notes
- The C `CGEventTapCallBack` is a free function; pass `self` via `userInfo` (`Unmanaged.passUnretained`), retrieve in the callback. Keep the tap's `CFMachPort` + run-loop source stored to remove cleanly.
- Posting backspaces then unicode text is the Espanso approach; sequence them so the target app processes the deletes before the insert.
- Keep the expander OFF by default and ensure `setEnabled(false)` fully tears down the tap.
