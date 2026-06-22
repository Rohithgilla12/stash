#!/usr/bin/env bash
# Sign a Stash.app with Developer ID + hardened runtime, INCLUDING the nested
# Sparkle helpers (Autoupdate, Updater.app, XPC services). Notarization requires
# every nested executable to be Developer-ID signed with the hardened runtime —
# signing only the outer app leaves Sparkle's helpers ad-hoc signed and Apple
# rejects the submission as Invalid.
#
# Usage: scripts/sign-app.sh <path-to-Stash.app> <signing-identity>
set -euo pipefail

APP="$1"
IDENTITY="$2"

sign() { codesign --force --options runtime --timestamp --sign "$IDENTITY" "$@"; }

SP="$APP/Contents/Frameworks/Sparkle.framework"
if [ -d "$SP" ]; then
  V="$SP/Versions/B"
  # innermost first
  [ -e "$V/XPCServices/Downloader.xpc" ] && sign "$V/XPCServices/Downloader.xpc"
  [ -e "$V/XPCServices/Installer.xpc" ]  && sign "$V/XPCServices/Installer.xpc"
  [ -e "$V/Autoupdate" ]                 && sign "$V/Autoupdate"
  [ -e "$V/Updater.app" ]                && sign "$V/Updater.app"
  sign "$SP"
fi

# the app last
sign "$APP"

codesign --verify --deep --strict "$APP"
echo "    signed + verified (incl. nested Sparkle): $APP"
