# Stash — project guide for Claude Code

Stash is a native **macOS menu-bar productivity app**: clipboard history, sticky notes,
a full to-do app, text-expansion snippets, window management, and an AI tab. It ships an
**MCP server** so you (Claude / Claude Code) can plan the user's day.

## Read first
- `README.md` — full design + behaviour spec (the source of truth for UI).
- `Stash Prototype.dc.html` — open in a browser to see/click the intended design.
- `mcp-server/` — working MCP server reference (TypeScript + SQLite).

## Build target
Native **Swift + SwiftUI** for the app. Do **not** ship the HTML — recreate the designs in
SwiftUI using the platform APIs listed in `README.md` (menu-bar item, global hotkeys,
Accessibility for window management + text expansion, sticky `NSWindow`s).

## Conventions
- The SQLite schema in `mcp-server/src/db.ts` is the contract between app and server — keep them in sync.
- Accent color `#c8642f`; full token list in `README.md`. Type: SF Pro / SF Pro Rounded for headers.
- Persist tasks & notes; sync via CloudKit.

## The MCP server
- Tools: `create_task`, `list_tasks`, `complete_task`, `update_task`, `add_note`, `search_clipboard`.
- "Generate my day" = call `create_task` once per task (no dedicated tool).
- Register: `claude mcp add stash -- node ./mcp-server/dist/server.js` (after `npm run build`).

## Suggested build order
clipboard history + hub popover → sticky notes + ⌃⌥S → SQLite tasks/notes + Tasks window
→ window management → text expansion (event tap) → wire MCP server → AI tab (credits + sessions).
