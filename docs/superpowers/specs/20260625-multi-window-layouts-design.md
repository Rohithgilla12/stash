# Multi-Window Layouts (Window Presets Phase 2) — Design Spec

**Date:** 2026-06-25
**Goal:** Save the current arrangement of app windows as a named layout and recall it to reposition them all at once (launching any that aren't running).
**Status:** Design from dialogue; pending spec review → plan.

---

## Context

Phase 1 shipped custom single-window snap presets + a multi-display `WindowSnapper` (screen resolution + AX `setFrame`) + GRDB persistence + per-item hotkeys/deeplinks. Phase 2 reuses all of that and adds the multi-window capture/recall the spec deferred. Inspired by Raycast's "Save Current Windows as Layout".

## Decisions (from dialogue)

| Decision | Choice |
|---|---|
| Capture granularity | **One main window per app** (each visible regular app's main/frontmost window). Not every window. |
| Recall, app not running | **Launch the app best-effort** (NSWorkspace), wait for its main window (short timeout + retry), then place it. |
| Persistence | **GRDB** `saved_layouts` table (entries as a JSON-encoded column); a `SavedLayoutStore` actor (mirrors `WindowPresetStore`). |
| Frame storage | **Absolute AX frame + display index**; on recall, resolve the display, fall back to main if gone, and **clamp to the display's visible bounds** so windows never land off-screen. |
| Triggers | Per-layout optional global **hotkey** + **`stash://layout?name=<name>`** deeplink (reuse Phase-1 plumbing). |
| Naming | `SavedLayout` / `LayoutEntry` (the existing `WindowLayout` is the snap-frame math — don't reuse that name). |

## Data model

`LayoutEntry` (Codable, Sendable): `bundleId: String`, `appName: String`, `x/y/width/height: Double` (AX global coords), `displayIndex: Int`.
`SavedLayout` (GRDB `Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable`): `id: String`, `name: String`, `entriesJSON: String` (JSON of `[LayoutEntry]`), `hotkeyKeyCode: Int?`, `hotkeyModifiers: Int?`, `createdAt: Int64`. `databaseTableName = "saved_layouts"`. A computed `entries: [LayoutEntry]` (decode/encode helper). Migration `v9_saved_layouts`.

## Capture — `WindowArranger.captureCurrent() -> [LayoutEntry]` (`@MainActor`)

- Enumerate `NSWorkspace.shared.runningApplications` where `activationPolicy == .regular` and `bundleIdentifier != Bundle.main.bundleIdentifier` (exclude Stash).
- For each app: `AXUIElementCreateApplication(pid)` → read `kAXMainWindowAttribute` (fallback: first of `kAXWindowsAttribute`). If no readable window, skip the app.
- Read the window's `kAXPositionAttribute`/`kAXSizeAttribute` (AX global frame). Resolve which display it's on (reuse Phase-1 `resolveScreen`-style max-overlap → `displayIndex` into `NSScreen.screens`).
- Build a `LayoutEntry` per app. (Requires Accessibility — gate on `AXIsProcessTrusted()`.)

## Recall — `WindowArranger.recall(_ layout: SavedLayout) async` (`@MainActor`)

For each `LayoutEntry`:
- Find the running app by `bundleId`. If found: get its main window (AX), set the frame (reuse Phase-1 `setFrame`), resolving the display by `displayIndex` (fallback `NSScreen.main`) and **clamping** the frame to that screen's `visibleFrame` (AX). 
- If NOT running: `NSWorkspace.shared.openApplication(at: <url for bundleId>, configuration:)`, then poll (≈ every 0.3s up to ≈5s) for the app's main window; once present, place it; on timeout, skip + record it as "couldn't place".
- All blocking waits happen off the main actor (detached/continuation, like Phase 1's keychain read) — never block the cooperative pool; AX mutations re-enter the main actor. Return a small summary (placed / launched / skipped counts) for a toast.

## UI (Windows tab — new "Layouts" section, below Presets)

- **"Save current windows…"** → a small name prompt (sheet or inline field) → `captureCurrent()` → persist a `SavedLayout` (new id, `createdAt = now`). If `captureCurrent()` is empty / not trusted, show the Accessibility affordance.
- A **list of saved layouts**: each row shows the name + a tiny app-count / icons; tap → `recall(layout)` (toast: "Placed N · launched M · skipped K"); hover/menu → Rename, Delete, set Hotkey (optional, deeplink works regardless).
- Reuse warm tokens + the existing section/tile styling. Keep the `!isTrusted` affordance.

## Triggers

- Per-layout optional global hotkey (reuse `GlobalHotKey` + the `globalHotkeysEnabled` gate + re-register on layout changes, exactly like Phase-1 presets).
- Deeplink: `AppEnvironment.handleDeeplink` gains `case "layout":` → `q("name")` → look up by name (case-insensitive) → `recall`.

## Testing / verification

- Unit tests: `LayoutEntry`/`SavedLayout` JSON round-trip (`entries` encode/decode); `SavedLayoutStore` CRUD (in-memory GRDB); a pure frame-clamp helper (`clamp(frame, to: visibleRect)`).
- AX capture/recall + launch-and-wait are I/O — build + **launch-run** (concurrency: launch + poll + AX; the recurring crash class) + manual.
- Manual: save a layout; rearrange windows; recall → they snap back; quit one app, recall → it launches + places; unplug a display → recalled windows clamp on-screen.
- Clean Release build + full suite green (was 248).

## Out of scope

- Every-window-per-app capture (only the main window).
- macOS Spaces / virtual desktops (no public API).
- Cloud/CloudKit sync of layouts.
- Capturing window z-order / minimized/fullscreen state (place frame only).

## Open choices for the plan

1. Name prompt UX: a tiny sheet (recommended) vs an inline "name + Save" row.
2. Launch-wait timeout: ~5s / 0.3s poll (recommended) — tune in the plan.
3. Whether to also store a per-entry app icon for the row (nice) vs resolve it live via `AppIconProvider` (recommended — no stale icons).
