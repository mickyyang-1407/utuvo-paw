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

codesign --force --deep --sign - "$APP"
codesign --verify --strict "$APP" && echo "✅ $APP"
