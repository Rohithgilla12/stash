#!/usr/bin/env bash
# Build → sign (hardened runtime) → package as a .dmg → NOTARIZE → staple, producing
# a distributable Stash-<version>.dmg for beta testers.
#
# Why notarization (not TestFlight): Stash is non-sandboxed and uses Accessibility +
# a CGEventTap (text expander) + global hotkeys, which the App Store sandbox forbids.
# Developer ID + notarization is the correct distribution path for this kind of app.
#
# ── ONE-TIME SETUP ────────────────────────────────────────────────────────────
# 1) Create an app-specific password at https://appleid.apple.com (Sign-In & Security
#    → App-Specific Passwords). Call it e.g. "stash-notary".
# 2) Store notarization credentials in the keychain (replace the password):
#      xcrun notarytool store-credentials "stash-notary" \
#        --apple-id "gillarohith@gmail.com" \
#        --team-id "7D2V3RM56T" \
#        --password "xxxx-xxxx-xxxx-xxxx"
# ──────────────────────────────────────────────────────────────────────────────
#
# Usage: scripts/release.sh
set -euo pipefail

IDENTITY="${STASH_SIGN_IDENTITY:-Developer ID Application: Rohith Gilla (7D2V3RM56T)}"
PROFILE="${STASH_NOTARY_PROFILE:-stash-notary}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/StashApp"

echo "==> xcodegen + build Release"
xcodegen generate >/dev/null
xcodebuild -scheme StashApp -configuration Release \
  -derivedDataPath .build-release build CODE_SIGNING_ALLOWED=NO >/dev/null
APP=".build-release/Build/Products/Release/StashApp.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist" 2>/dev/null || echo "0.1.0")

echo "==> sign with hardened runtime ($IDENTITY)"
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --strict "$APP" && echo "    signature verified"

echo "==> build DMG"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/Stash.app"
ln -s /Applications "$STAGE/Applications"
DMG="$ROOT/Stash-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "Stash" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "==> notarize (uploads to Apple; usually 1–5 min)"
if ! xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait; then
  echo "!! Notarization failed. Did you run the ONE-TIME SETUP at the top of this script?"
  echo "   Inspect a submission with: xcrun notarytool log <submission-id> --keychain-profile \"$PROFILE\""
  exit 1
fi

echo "==> staple"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG" && echo "    stapled + validated"

echo ""
echo "Done → $DMG"
echo "Share that .dmg. Testers: open it, drag Stash → Applications, launch,"
echo "and grant Accessibility once (System Settings → Privacy & Security → Accessibility)."
