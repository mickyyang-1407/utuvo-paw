#!/usr/bin/env bash
# Plant a harmless fake app plus leftovers in every folder UTUVO Paw scans, so the cat has
# something to throw at. Everything is under ~/Library/<root>/<bundle id> or named "Fake Cat Toy".
# Usage: bash scripts/make-fake-app.sh [target dir, default ~/Desktop]
set -euo pipefail
cd "$(dirname "$0")/.."

ID="com.utuvo.fakecattoy"
NAME="Fake Cat Toy"
DEST="${1:-$HOME/Desktop}"
L="$HOME/Library"
if [[ "${1:-}" == "--clean" ]]; then
    rm -rf "$HOME/Desktop/$NAME.app" "$L"/*/"$ID"* "$L"/*/*/"$ID"* "$L/Logs/$NAME" "$L/Group Containers/group.$ID" \
           "$L/Application Support/FakeCatToyPro" "$L/Caches/${ID}pro"
    echo "🧹 cleaned"; exit 0
fi
APP="$DEST/$NAME.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$ID</string>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleExecutable</key><string>FakeCatToy</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleShortVersionString</key><string>9.9.9</string>
  <key>CFBundleVersion</key><string>999</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>10.13</string>
</dict></plist>
EOF
cat > "$APP/Contents/MacOS/FakeCatToy" <<'EOF'
#!/bin/sh
osascript -e 'display dialog "meow. (this is the fake app for UTUVO Paw)" buttons {"OK"} default button 1 with title "Fake Cat Toy"'
EOF
chmod +x "$APP/Contents/MacOS/FakeCatToy"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"
dd if=/dev/urandom of="$APP/Contents/Resources/padding.bin" bs=1m count=8 2>/dev/null   # so it has a size
codesign --force --sign - "$APP" 2>/dev/null || true

# Some roots (Group Containers, Application Scripts) are TCC-protected; skip them when this shell lacks Full Disk Access.
blob() { mkdir -p "$(dirname "$1")" 2>/dev/null || { echo "  (skipped, no access: ${1#$HOME/})"; return 0; }; dd if=/dev/urandom of="$1" bs=1k count="$2" 2>/dev/null || true; }

blob "$L/Application Support/$ID/data/library.db" 3072
blob "$L/Caches/$ID/fsCachedData/chunk-1" 1024
blob "$L/Caches/$ID/fsCachedData/chunk-2" 512
defaults write "$ID" lastOpened -date "2026-09-16T12:00:00Z"
defaults write "$ID" purrLevel -int 11
blob "$L/Preferences/ByHost/$ID.$(uuidgen).plist" 2
blob "$L/Saved Application State/$ID.savedState/windows.plist" 4
blob "$L/Saved Application State/$ID.savedState/data.data" 40
blob "$L/Containers/$ID/Data/Library/Application Support/notes.txt" 8
blob "$L/Containers/$ID/Data/Library/Caches/thumbs/1.jpg" 300
blob "$L/Group Containers/group.$ID/shared.db" 64
blob "$L/Application Scripts/$ID/helper.scpt" 1
blob "$L/Logs/$NAME/run-2026-09-16.log" 16
blob "$L/Logs/$NAME/crash.log" 2
blob "$L/HTTPStorages/$ID/httpstorages.sqlite" 96
blob "$L/HTTPStorages/$ID.binarycookies" 2
blob "$L/WebKit/$ID/WebsiteData/LocalStorage/x.localstorage" 20
blob "$L/Cookies/$ID.binarycookies" 3
mkdir -p "$L/LaunchAgents"
cat > "$L/LaunchAgents/$ID.helper.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$ID.helper</string>
  <key>ProgramArguments</key><array><string>/usr/bin/true</string></array>
  <key>RunAtLoad</key><false/>
</dict></plist>
EOF
# decoys that must NOT be matched
blob "$L/Application Support/FakeCatToyPro/x" 1
blob "$L/Caches/${ID}pro/x" 1   # no dot: "$ID.pro" would count as a child id of $ID, by design

echo "✅ $APP"
echo "leftovers planted:"
ls -d "$L"/*/"$ID"* "$L"/*/*/"$ID"* "$L/Logs/$NAME" "$L/Group Containers/group.$ID" 2>/dev/null | sed "s|$HOME|~|"
echo "decoys (should NOT appear): ~/Library/Application Support/FakeCatToyPro, ~/Library/Caches/${ID}pro"
echo "cleanup of anything left: bash scripts/make-fake-app.sh --clean"
