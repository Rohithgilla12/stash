#!/usr/bin/env bash
# Build Stash (Release), sign with a stable Developer ID identity, and install
# to ~/Applications/Stash.app. Signing with Developer ID (not ad-hoc) gives the
# app a STABLE code identity, so the macOS Accessibility (window snapping +
# text expander) grant PERSISTS across rebuilds instead of re-prompting.
#
# Usage: scripts/install-signed.sh
set -euo pipefail

IDENTITY="${STASH_SIGN_IDENTITY:-Developer ID Application: Rohith Gilla (7D2V3RM56T)}"
APP_DEST="$HOME/Applications/Stash.app"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT/StashApp"
echo "==> xcodegen generate"
xcodegen generate >/dev/null

echo "==> building Release"
xcodebuild -scheme StashApp -configuration Release \
  -derivedDataPath .build-release build CODE_SIGNING_ALLOWED=NO >/dev/null
APP=".build-release/Build/Products/Release/StashApp.app"

echo "==> signing with: $IDENTITY (incl. nested Sparkle helpers)"
bash "$ROOT/scripts/sign-app.sh" "$APP" "$IDENTITY"

echo "==> installing to $APP_DEST"
# Kill BOTH the installed signed app and any stale Debug build (…/StashApp.app/…)
# so an old instance doesn't keep capturing the clipboard with outdated code.
pkill -f "StashApp.app/Contents/MacOS/StashApp" 2>/dev/null || true
pkill -f "Stash.app/Contents/MacOS/StashApp" 2>/dev/null || true
rm -rf "$APP_DEST"
mkdir -p "$HOME/Applications"
cp -R "$APP" "$APP_DEST"

echo "==> launching"
open "$APP_DEST"
echo "Done. If window snapping / the text expander ask for Accessibility once,"
echo "grant 'Stash' in System Settings > Privacy & Security > Accessibility."
