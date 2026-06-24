# Custom Window Presets + Multi-Display — Design Spec

**Date:** 2026-06-24
**Goal:** Let users define their own named window-snap presets (custom size/anchor/offset, on a chosen display) — triggerable from the Windows tab, a global hotkey, or a `stash://` deeplink — and make snapping multi-display aware.
**Status:** Design approved in dialogue; pending spec review → plan.

---

## Context

Stash already has a Windows tab (`Windows/WindowsTab.swift`) with built-in snap targets (`SnapTarget`: halves/quarters/thirds/full) computed by `WindowLayout.frame(for:in:gap:)` and applied by `WindowSnapper` via the Accessibility API. As of the last fix, the tab snaps the **last active non-Stash app's** focused window, and `WindowSnapper` tracks that app.

**Current limitation:** `WindowSnapper` hardcodes `NSScreen.main` (the code comments note multi-display as a follow-up), so snapping always lands on the main display.

Inspired by Raycast's two features: **Custom Window Management Commands** (a single window → size %/pt + anchor + offset) and **Layouts** (multi-window save/recall). We are building the **custom-preset** model first; multi-window layouts are Phase 2 (separate plan).

## Decisions (locked in dialogue)

| Decision | Choice |
|---|---|
| "Multiple desktops" means | **Multiple displays / monitors** (public AppKit + AX). NOT macOS Spaces (no public API; out of scope). |
| Scope now | **Phase 1: custom snap presets + multi-display.** Phase 2 (multi-window layouts) is a later, separate plan. |
| Persistence | **GRDB** (SQLite) — a `window_presets` table, consistent with tasks/notes/snippets/clipboard. |
| Built-in targets | Upgraded to snap on **the display the window is on** (fixes the main-only limitation), plus a **"Move to next display"** action. |
| Triggers | Each preset: optional **global hotkey** + **`stash://snap?preset=<name>`** deeplink, reusing existing plumbing. |

## Phase 1 design

### Data model — `WindowPreset`
A `Codable, FetchableRecord, PersistableRecord` row in a new `window_presets` table:

| field | type | meaning |
|---|---|---|
| `id` | text (PK, UUID) | stable id |
| `name` | text | e.g. "Coding", "Centered Big" |
| `widthMode` | text (`percent`/`points`) | how `width` is interpreted |
| `width` | double | % of display (0–1 or 0–100 — pick one, see below) or points |
| `heightMode` | text | same |
| `height` | double | |
| `anchor` | text enum | `center`,`left`,`right`,`top`,`bottom`,`topLeft`,`topRight`,`bottomLeft`,`bottomRight` |
| `xOffset` | double | nudge in points (applied after anchoring) |
| `yOffset` | double | nudge in points |
| `display` | text | `active` (display under the focused window) · `main` · `index:N` (the Nth NSScreen) |
| `hotkeyKeyCode` / `hotkeyModifiers` | int? | optional global hotkey |
| `createdAt` | int64 | ordering |

Decision to confirm in plan: store percentages as **0.0–1.0** (fraction) internally; the editor shows 0–100%.

### Frame computation — pure + tested
A pure function (extend `WindowLayout` or a new `PresetLayout`):
```
static func frame(for preset: WindowPreset, in displayVisibleRect: CGRect) -> CGRect
```
- Resolve width/height: `percent` → `displayVisibleRect.size * fraction`; `points` → literal pt (clamped to the display).
- Place by `anchor` within `displayVisibleRect` (e.g. `center` → centered; `topLeft` → at the rect's top-left; `right` → right-aligned, vertically centered).
- Apply `xOffset`/`yOffset`.
- Output rect is in the **same coordinate space as the input** (we feed it the display's visibleFrame in AX coords, like the existing flow).
This is the unit-tested core (no AX/screen dependency).

### `WindowSnapper` — multi-display
- Add display resolution: `func screen(for display: PresetDisplay, focusedWindowFrame: CGRect?) -> NSScreen?` — `active` = the `NSScreen` containing the focused window's frame (max-overlap), `main` = `NSScreen.main`, `index:N` = `NSScreen.screens[N]` (guard bounds).
- `snap(_ target: SnapTarget)` and a new `snap(_ preset: WindowPreset)`: resolve the target screen, compute that screen's `visibleFrame`, convert to **global AX coords** via `ScreenGeometry` (works for any screen, not just main — AX coords are global with the primary display's top-left as origin), compute the frame, set `kAXPosition`/`kAXSize`. Keep the `AXIsProcessTrusted()` guard + last-active-app targeting.
- Built-in `SnapTarget` snapping now uses the **active** display (the one under the focused window) instead of `NSScreen.main`.
- New action `moveToNextDisplay()` — moves the focused window to the next `NSScreen`, preserving relative position (or full-screen on arrival; pick simplest in plan).
- **Concurrency:** `WindowSnapper` is `@MainActor`; keep the NSWorkspace observer pattern that already exists. Any new callbacks must be main-actor-safe (we shipped a crash from an off-main `@MainActor` closure — verify by launch-running the build).

### `WindowPresetStore` (GRDB)
- A store with `all() -> [WindowPreset]`, `create/update/delete`, and GRDB `ValueObservation` so the Windows tab list stays live.
- New migration `vN_window_presets` creating the table.

### Windows tab UI
- New **Presets** section below the built-in groups: a tile per preset (name + a mini-diagram of the frame) → click snaps the last-active window via `snapper.snap(preset)`.
- A **"+ New preset"** tile → an editor sheet: name; width + unit (%/pt); height + unit; a 3×3 + center **anchor picker**; x/y offset steppers; a **display picker** (Active / Main / Display 1…N from `NSScreen.screens`); optional **hotkey recorder**. Edit/delete existing presets (hover actions or a row menu).
- If `!snapper.isTrusted`, show the existing "Enable Accessibility" affordance.

### Triggers
- **Hotkey:** presets with a hotkey register via the existing `GlobalHotKey`/`SnapHotKey` machinery (unique ids), dispatched to `snapper.snap(preset)`. Re-register on preset changes; gate by the existing global-hotkeys-enabled toggle.
- **Deeplink:** `stash://snap?preset=<name>` (and/or `?presetId=<id>`) handled in `AppEnvironment.handleDeeplink` → look up the preset → `snapper.snap(preset)`.

## Testing / verification

- **Unit tests** (Swift Testing) for the pure frame computation: percent vs points; each anchor; offsets; clamping; a representative display rect. (No AX/NSScreen needed.)
- **Store tests** if practical (in-memory GRDB): create/update/delete round-trip.
- Clean **Release** build + full suite green.
- **Launch-run the built app** (Debug + Release) to confirm no concurrency crash (the snapper observer + hotkey registration) — build+tests are NOT sufficient for concurrency, per the recent crash.
- Manual: define a preset, snap a real window to it on a secondary display.

## Out of scope (this plan)

- **macOS Spaces / virtual desktops** — no public API; not attempted.
- **Phase 2: multi-window layouts** (save/recall multiple apps' windows) — separate spec/plan; will reuse this snapper + display resolution + persistence.
- Syncing presets via CloudKit / MCP.

## Open choices for the plan

1. Percent storage as 0–1 fraction (recommended) vs 0–100.
2. `moveToNextDisplay` behavior: preserve relative frame (recommended) vs reset to full on the new display.
3. Hotkey recorder UI: build a minimal recorder vs reuse/extend any existing one.
