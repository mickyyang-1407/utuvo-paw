#!/usr/bin/env bash
# Build UTUVO Paw.app from the SwiftPM package and ad-hoc sign it.
# Usage: bash scripts/build-app.sh [debug|release]   (default release)
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG" 2>&1 | tail -n 5

BIN=".build/${CONFIG}/UTUVOPaw"
RES=".build/${CONFIG}/UTUVOPaw_UTUVOPaw.bundle"
[[ -f "$BIN" ]] || { echo "❌ missing $BIN" >&2; exit 1; }
[[ -d "$RES" ]] || { echo "❌ missing resource bundle $RES" >&2; exit 1; }

APP="build/UTUVO Paw.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/UTUVOPaw"
cp -R "$RES" "$APP/Contents/Resources/"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Sign with Developer ID when available (TCC grants such as Full Disk Access are tied to the
# code identity; an ad-hoc signature changes every build and drops them). Override: SIGN_ID=-
SIGN_ID="${SIGN_ID:-$(security find-identity -v -p codesigning 2>/dev/null | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')}"
SIGN_ID="${SIGN_ID:--}"
if [[ "$SIGN_ID" == "-" ]]; then
    codesign --force --deep --sign - "$APP"
else
    codesign --force --deep --options runtime --timestamp \
        --entitlements Resources/UTUVOPaw.entitlements --sign "$SIGN_ID" "$APP"
fi
codesign --verify --strict "$APP" && echo "✅ $APP  (signed: $SIGN_ID)"
