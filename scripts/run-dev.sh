#!/usr/bin/env bash
# Build + launch the DEV variant of Stash (Debug config). It has a separate
# bundle id (com.rohithgilla.stash.app.dev), name ("Stash Dev"), menu-bar icon
# (hammer), and data dir (~/Library/Application Support/Stash-Dev) — so it runs
# alongside the installed prod app without colliding (separate Accessibility
# grant, UserDefaults, and database). Run from Xcode (Debug) for the same result.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/StashApp"
xcodegen generate >/dev/null
echo "==> building Stash Dev (Debug)"
xcodebuild -scheme StashApp -configuration Debug -derivedDataPath .build build CODE_SIGNING_ALLOWED=NO >/dev/null
APP=".build/Build/Products/Debug/StashApp.app"

pkill -f "Debug/StashApp.app/Contents/MacOS/StashApp" 2>/dev/null || true
sleep 1
open "$APP"
echo "==> launched Stash Dev — look for the hammer icon in the menu bar"
echo "    bundle id: com.rohithgilla.stash.app.dev"
echo "    data:      ~/Library/Application Support/Stash-Dev"
echo "Grant Accessibility to \"Stash Dev\" separately when prompted (prod is unaffected)."
