# Stash — Slice 1: Menu-bar Hub + Clipboard (Design)

**Date:** 2026-06-18
**Status:** Approved (design), pending implementation plan
**Scope:** First of several slices. Builds the native macOS app shell (menu-bar hub)
and the fully functional Clipboard tab. The other five tabs ship as styled placeholders.

## Why slices

Stash spans six independent subsystems (clipboard, sticky notes, to-dos, snippets,
window management, AI/MCP), each with distinct OS integration. They are too much for one
spec, so we build incrementally — each slice gets its own design → plan → implementation
cycle. This slice is the foundational shell every later tab lives inside, plus the first
real feature (Clipboard), per the build order in `CLAUDE.md`.

## Decisions locked in brainstorming

- **First slice:** Hub shell + Clipboard tab.
- **Clipboard content types:** full fidelity — text, links, and images/GIFs (with thumbnails).
- **Persistence:** persist to the shared `stash.db`, capped to a rolling 200 non-pinned
  items (+ all pinned); image bytes stored in a sidecar cache dir, not the DB.
- **Other tabs:** rendered as styled "Coming soon" placeholder panels so the hub looks complete.
- **Project structure:** XcodeGen (`project.yml` → generated `.xcodeproj`); requires
  `brew install xcodegen`.
- **Toolchain:** Xcode 26.5, Swift 6.3.2 (strict concurrency), macOS 26.

## Toolchain & target

- SwiftUI `App` with a `MenuBarExtra` scene, `.menuBarExtraStyle(.window)` — pure-SwiftUI
  menu-bar item, no `NSStatusItem`.
- `LSUIElement = true` (agent app, no Dock icon).
- **Non-sandboxed**, so the app shares `~/Library/Application Support/Stash/stash.db` with
  the Node MCP server. (A sandboxed app would resolve a container path and break the
  shared-DB contract.)
- Dependency: **GRDB.swift** via SwiftPM (declared in `project.yml`).
- Build headlessly: `xcodegen generate` then `xcodebuild -scheme StashApp`.

## Directory layout

```
stash/
├── StashApp/
│   ├── project.yml              # XcodeGen: target, LSUIElement, entitlements, GRDB dep
│   ├── Sources/StashApp/
│   │   ├── StashApp.swift        # @main App + MenuBarExtra scene
│   │   ├── App/AppEnvironment.swift   # composition root (DB, store, monitor)
│   │   ├── Hub/                  # HubView, HubTab, SearchField, Footer
│   │   ├── Clipboard/            # ClipboardTab, ClipRowView, ClipboardMonitor,
│   │   │                         #   ClipboardStore, ClipClassifier, ThumbnailCache
│   │   ├── Placeholders/ComingSoonView.swift
│   │   ├── Data/                 # Database.swift (GRDB setup + migrations), ClipItem
│   │   └── Design/Tokens.swift   # colors, radii, fonts from README
│   └── Tests/StashAppTests/
├── mcp-server/                  # existing; db.ts schema kept in sync
└── docs/superpowers/specs/      # this doc
```

## App shell & navigation

- `AppEnvironment` — composition root. Opens the DB, constructs `ClipboardStore` and
  `ClipboardMonitor`; injected into views via `@Environment`.
- `HubView` — frosted 456px panel: search field, 6-item tab bar
  (`Clipboard · Notes · To-dos · Snippets · Windows · AI`), scrollable content
  (max-height ~600), footer.
- `HubTab` enum drives selection. `Clipboard` renders the real tab; the other five render
  `ComingSoonView`. Tab switch is instant (no animation, per spec).
- Search field is wired to the Clipboard live filter this slice; inert on placeholder tabs.

## Data layer & schema

- GRDB `DatabasePool` (WAL, matching the Node side) at
  `~/Library/Application Support/Stash/stash.db`. UI reads via `ValueObservation` so rows
  update live as the monitor (or the MCP server) writes.
- **Schema change to the shared `clipboard` table.** Current columns:
  `id, kind, text, app, pinned, created_at`. Add two nullable columns:
  - `title TEXT` — display label (link page title, image filename, or first line of text).
  - `preview_path TEXT` — sidecar file path for image/GIF thumbnails.
- **Kept in sync:** update `mcp-server/src/db.ts`'s `CREATE TABLE` to include both columns
  (Node-first creation matches), and the app's GRDB `DatabaseMigrator` runs
  `ALTER TABLE … ADD COLUMN` guarded by existence checks (an existing Node-created DB
  upgrades losslessly regardless of which process creates the file first).
- Image bytes live as files in `~/Library/Application Support/Stash/clip-cache/`
  (full + 58×38 thumbnail), referenced by `preview_path`. Never DB blobs.

## Clipboard engine

- `ClipboardMonitor` (actor) polls `NSPasteboard.general.changeCount` on a ~0.5s timer.
  On change it reads the pasteboard; a pure `ClipClassifier` maps it to a kind:
  **image/GIF** (NSImage/file types), **link** (string parses as URL), else **text**.
  Source app from `NSWorkspace.shared.frontmostApplication`.
- **Dedup:** skip if identical to the newest row.
- **Copy-back guard:** when the user clicks a row to re-copy, the monitor ignores that one
  self-induced pasteboard change so it does not create a duplicate.
- **Cap:** after insert, delete oldest non-pinned rows beyond 200; pinned rows always kept.
- Images: write full image + thumbnail to the cache dir, store `preview_path`;
  thumbnail-generation failure falls back to a type badge.

## UI fidelity

`Design/Tokens.swift` carries README values (terracotta `#c8642f`, frosted
`rgba(252,250,246,.93)`, radii 16/9, SF Pro / SF Pro Rounded). Clipboard tab renders
`PINNED` then `RECENT` sections; each row: type tile or 58×38 preview, title +
`time · app` sub, pin dot, type badge. Row click → copy + "Copied" toast; pin dot → toggle.
Live search filter.

## Error handling

- DB open failure surfaces a non-fatal error state; the app keeps running.
- Unsupported pasteboard types are skipped.
- Oversized images are downscaled for the thumbnail and capped before storing full bytes.
- All DB writes go through GRDB's WAL pool so concurrent MCP-server access is safe.
- Swift 6 concurrency: `ClipboardMonitor`/`ClipboardStore` are actors, views `@MainActor`,
  records `Sendable`.

## Testing

Logic stays out of views to keep it unit-testable:

- `ClipClassifier` — text / link / image classification.
- `ClipboardStore` — insert, dedup, cap-at-200, pin retention; against a temp DB.
- `ThumbnailCache` — write/read/fallback.
- **Migration test** — a Node-style minimal `clipboard` table migrates to add the new
  columns without data loss.
- UI verified by running the app.

## Out of scope (later slices)

Notes, To-dos, Snippets, Window management, AI/MCP tab wiring, global hotkey to toggle the
hub, CloudKit sync, link page-mock thumbnails (beyond best-effort title), `code`-kind
detection.
