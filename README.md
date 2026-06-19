# Stash — a warm macOS menu-bar productivity app

**Stash** is a native macOS menu-bar app. One panel ("the hub") holds everything:
clipboard history (with link/image previews), notes, a full to-do app, text-expansion
snippets (+ emoji `:rocket:`), Raycast-style window management, a Pomodoro Focus timer,
and an AI tab. Notes also live on the desktop as paper sticky notes that toggle with
⌥Space. There's a Paste-style clipboard browser (⌃⌥V), a `stash://` URL scheme, and an
**MCP server** so Claude & Claude Code can read/write your tasks/notes/clipboard —
e.g. "plan my day".

## Install (beta)

**Requires macOS 14 (Sonoma) or later.**

1. Download the latest **`Stash-x.x.x.dmg`** from the
   **[Releases page](https://github.com/Rohithgilla12/stash/releases/latest)**.
2. Open the DMG and drag **Stash** into **Applications**.
3. Launch it — Stash lives in your **menu bar** (the tray icon), not the Dock.
4. The first time you use **window snapping** (⌃⌥ arrows) or the **text expander**,
   grant **Accessibility** when prompted (System Settings → Privacy & Security →
   Accessibility). That's the only permission it needs.

The build is signed with a Developer ID and **notarized by Apple**, so it opens without
Gatekeeper warnings. Power-user extras: the `stash://` URL scheme (drive any action from
Karabiner / Raycast / Shortcuts) and the [MCP server](mcp-server/SETUP.md).

### Build from source

```bash
brew install xcodegen
cd StashApp && xcodegen generate
xcodebuild -scheme StashApp -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
# or open StashApp.xcodeproj in Xcode
```

To produce a signed + notarized DMG yourself, run `scripts/release.sh` (one-time setup
notes are at the top of the script).

## About the design files
The HTML file in this bundle (`Stash Prototype.dc.html`) is a **design reference / interactive
prototype** showing the intended look and behaviour. It is **not production code to ship**.
The task is to **recreate these designs in the target environment** — for the real product that
means **native macOS (Swift + SwiftUI)**, because the app needs a menu-bar item, global
hotkeys, always-on-top sticky windows, OS-level text injection, and the Accessibility API —
none of which a web wrapper handles well. Use the prototype for exact layout, copy, colors,
spacing, and interaction behaviour; build the UI with SwiftUI and the platform APIs below.

The `mcp-server/` folder, by contrast, **is** runnable reference code (TypeScript) you can use
directly or port.

## Fidelity
**High-fidelity.** Final colors, typography, spacing, and interactions are all in the prototype.
Recreate the UI faithfully. Open `Stash Prototype.dc.html` in a browser to click through every
state (tabs, search, pin, snippet expansion, window snapping, ⌥Space, Generate my day, subtasks).

---

## Screens / views

All surfaces render over a warm "desktop" (sand gradient `linear-gradient(165deg,#f1dac0,#e6c5a5,#d6aa84)`
with a soft light radial top-left). A faux macOS menu bar (height 30px, translucent
`rgba(250,247,242,.72)` + blur) sits on top.

### 1. Menu-bar hub (the core surface)
- Opened by clicking the Stash icon in the menu bar (terracotta rounded square, 22px).
- A frosted panel anchored top-right: width **456px**, `background:rgba(252,250,246,.93)`,
  `backdrop-filter:blur(36px) saturate(1.5)`, border `1px rgba(0,0,0,.07)`, radius **16px**,
  shadow `0 30px 76px rgba(40,28,14,.35)`. A small caret points up to the icon.
- **Search field** (rounded, `rgba(0,0,0,.05)` fill) at top.
- **Tab bar:** Clipboard · Notes · To‑dos · Snippets · Windows · AI. Active tab = solid
  terracotta `#c8642f` white text, radius 9px; inactive = `#7a746a`.
- Content area is **scrollable** (max-height ~600px). Footer row shows context + Preferences.

**Clipboard tab** — `PINNED` then `RECENT` sections. Each row: 30px type tile, title + sub
(time · app), a pin dot (filled terracotta when pinned), and a type badge. Links, images and
GIFs render a **58×38 preview thumbnail** instead of a badge (page mock for links, striped
placeholder + PNG/GIF badge for media). Search filters live; clicking a row copies; clicking
the dot toggles pin (moves between sections).

**Notes tab** — list of notes (color chip + title + snippet). Click opens the **Notes window**.
"+ New note" creates one.

**To‑dos tab** — quick view: a "Generate my day" button (terracotta gradient card), a
natural-language quick-add field, a "Today · N open" header with "Open all tasks ↗", and the
day's task rows. See Tasks below for row anatomy.

**Snippets tab** — a live text-expansion demo (Espanso-style): a textarea where typing a
trigger expands it inline, plus the snippet list. Triggers use `:` prefix
(`:sig`, `:addr`, `:ty`, `:cal`, dynamic `:date`, `:shrug`). Clicking a snippet inserts it.

**Windows tab** — Raycast-style snapping grouped as HALVES / QUARTERS / THIRDS / FULL SCREEN.
Each card: a 38×25 mini-diagram of the target region + name + hotkey (`⌃⌥←`, `⌃⌥U`, etc.).
Active target is highlighted terracotta. Clicking snaps the demo "Safari" window (animated).

**AI tab** —
- `MCP SERVER` card: green pulsing status dot, `stash-mcp` running on localhost, "Connected",
  the exposed tool chips (`create_task`, `list_tasks`, …), and a **"Generate my day"** button.
- `USAGE THIS CYCLE`: provider meters (Claude / Codex / Stash AI) — name, plan, % left, a
  progress bar, reset note.
- `ACTIVE SESSIONS` (herdr-style): live coding-agent rows — repo + branch, status dot
  (running pulses green / waiting amber / idle gray), token count + elapsed that **tick live**.

### 2. Notes window
Frosted window (~520×520), traffic-light title bar, "Saved" indicator. Left sidebar = note list
(active highlighted). Right = editable title (input) + body (textarea) or, for to-do notes, an
editable checklist with "+ Add task". Footer: "Pin to desktop" toggle + Share. Edits persist.

### 3. Tasks window (the full to-do app)
Frosted window (~560×580), traffic lights, "MCP connected" (pulsing dot). Sidebar smart lists
(Today / Upcoming / All / Completed with counts), PROJECTS, and TAGS chips — each filters.
Main pane: filter title + open count, a natural-language add field, the task list, and a footer
("Synced with Claude via MCP" + a mini "Generate my day" button).

**Task row anatomy:** priority dot (high `#c8642f` / med `#d8a13a` / low `#b3a99b`), checkbox
(18px, filled terracotta with white check when done), title (strikethrough + gray when done),
a `✶ Claude` badge if Claude created it, a row of tag chips + project label, a `↻ Daily` chip
for recurring tasks, a `☑ 1/3` subtask-progress chip (click to expand an inline subtask
checklist with "+ Add subtask"), and a due pill (Today = terracotta, else neutral).

### 4. Desktop sticky notes
Paper notes scattered on the desktop (warm pastels, slight rotation, soft shadow, a pin dot at
top). To-do notes show a checklist; text notes show body. **⌥Space** (or the bottom pill) fades
them all out/in together. Clicking a sticky opens it in the Notes window. Stickies are driven by
the same note data, so edits sync.

---

## Interactions & behavior
- **Open/close hub:** click menu-bar icon (toggles). Esc closes open windows.
- **Tabs:** instant switch, no animation. Search filters the Clipboard list live.
- **Copy / pin:** row click = copy (toast "Copied to clipboard"); dot click = toggle pin.
- **Snippet expansion:** on each keystroke, if the field text ends with a known trigger, replace
  that trigger with its expansion (dynamic ones like `:date` resolve at expansion time). Toast
  "Expanded :trigger". This mirrors how the real OS-level expander should behave.
- **Window snap:** clicking a snap card animates the demo window to the target frame
  (`transition: all .34s cubic-bezier(.4,0,.2,1)`), toast "Snapped: <name>".
- **⌥Space:** global toggle for stickies (opacity + translateY/scale, .3s).
- **Generate my day:** clears prior Claude tasks, then inserts 5 tasks one-by-one on a stagger
  (~480ms each) with a `taskin` fade animation and a `✶ Claude` badge; toast updates.
- **Recurring task complete:** checks off, toast "Repeats daily — resets for next time", then
  auto-unchecks ~1.1s later (next occurrence).
- **Subtasks:** progress chip toggles an inline checklist; toggling a subtask updates progress.
- **Live sessions:** running agents' token counts climb and elapsed increments every ~1.6s.
- **Notes/tasks editing:** controlled inputs write straight to state and persist.

## State management
Prototype keeps everything in one component's state; for the app, back it with the SQLite store
(see `mcp-server/src/db.ts` schema — the same DB the MCP server uses).
- `tasks[]` — {id, title, done, priority, due, project, tags[], repeat, subs[{t,done}], source}
- `notes[]` — {id, title, body|items[], color, accent, kind:'text'|'todo', onDesktop}
- `clip[]` — {id, kind, title, sub, pinned}
- `snippets[]` — {trigger, label, expand | dynamic}
- UI: active tab, hub open, notes/tasks window open, active note id, task filter
  (type + value), expanded task id, search query, sticky visibility, snap target, "generating".
- **Persistence:** notes and tasks are saved (prototype uses localStorage keys
  `stash.notes.v2` / `stash.tasks.v3`); the app should use SQLite + CloudKit sync.

## Design tokens
- **Accent (terracotta):** `#c8642f`. Tints: `rgba(200,100,47,.08–.13)`. Generate gradient: `#fbe9dd → #f6dccb`.
- **Text:** primary `#2c2925`, secondary `#6b655c`, tertiary/muted `#9a948a` / `#a39a8c` / `#b3a99b`.
- **Desktop:** `linear-gradient(165deg,#f1dac0,#e6c5a5,#d6aa84)`.
- **Frosted panel/window:** `rgba(252,250,246,.92–.95)`, blur 34–36 saturate 1.4–1.5.
- **Sticky pastels:** yellow `#fdf0c2`, peach `#fcdcc6`, blue `#d4e4f2`, mint `#d9ecda` (accents `#c8642f/#b97a4a/#5b86b8/#5e8a52`).
- **Priority:** high `#c8642f`, med `#d8a13a`, low `#b3a99b`.
- **Tag chip colors** (bg, fg): eng `#e7eef7/#4a72a8`, design `#ece6f5/#7a5fb0`, urgent `#f6dcd0/#b5532a`, personal `#e3eee0/#4f7a45`, data `#eef0e6/#7a7d4a`, marketing `#f6ead8/#a8742f`, admin `#eceae6/#7a746a`.
- **Status dots:** running `#3fa45b` (pulse), waiting `#d8a13a`, idle `#a39a8c`.
- **Radii:** panel 16, window 14, rows/cards 9–11, chips 6–7. **Type:** `-apple-system / SF Pro`; headers `ui-rounded` (SF Pro Rounded); mono `ui-monospace`.

## Platform APIs (for the native build)
| Feature | API |
|---|---|
| Menu-bar hub | `NSStatusItem` + `NSPopover` hosting SwiftUI |
| Global hotkeys (⌥Space, snap keys) | `RegisterEventHotKey` / `HotKey` package |
| Clipboard history | poll `NSPasteboard.general.changeCount`; store text/image/file + thumbnails |
| Sticky notes | borderless `NSWindow` at `.floating` level, draggable; toggle together |
| Text expansion | Accessibility permission + `CGEventTap` keydown buffer → backspaces + paste expansion |
| Window management | Accessibility API (`AXUIElement`) read/set focused window frame; rects from `NSScreen.visibleFrame` + gap |
| Store / sync | SQLite (GRDB) + CloudKit |
| AI credits | Anthropic / OpenAI usage endpoints with user keys |
| Agent sessions | herdr CLI (`HERDR_BIN_PATH`) or a herdr plugin; or tail Claude Code logs |
| MCP server | see `mcp-server/` — launch as a child process of the app over stdio |

## Files
- `Stash Prototype.dc.html` — the full interactive design reference (open in a browser).
- `mcp-server/` — runnable TypeScript MCP server (tasks/notes/clipboard tools) + its README.
- `.mcp.json` — Claude Code project config that registers the server.
- `CLAUDE.md` — project instructions for Claude Code.
