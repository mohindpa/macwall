#!/bin/bash
# Build the shareable MacWall.dmg: single-file installer.
# Contains MacWall.app + an /Applications drop link + INSTALL.txt, with a
# styled Finder window (pixel-art arrow background, arranged icons).
# Usage: bash scripts/make_dmg.sh [output.dmg]
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/MacWall.app"
[ -d "$APP" ] || { echo "No $APP — run 'bash build.sh' first."; exit 1; }

OUT="${1:-MacWall.dmg}"
STAGE="build/dmg-stage"
RW="build/dmg-rw.dmg"
VOL="MacWall"
BG="scripts/dmg-background.png"

# Background (generated once, kept)
if [ ! -f "$BG" ]; then
  echo "Generating DMG background…"
  swift tools/gen_dmg_background.swift "$BG"
fi

rm -rf "$STAGE" "$RW"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/MacWall.app"
ln -s /Applications "$STAGE/Applications"
cp scripts/INSTALL.txt "$STAGE/INSTALL.txt"

SIZE_MB=$(( $(du -sm "$STAGE" | cut -f1) + 24 ))
hdiutil create -srcfolder "$STAGE" -volname "$VOL" -fs HFS+ -format UDRW -size "${SIZE_MB}m" "$RW" >/dev/null

hdiutil attach "$RW" -noautoopen >/dev/null
sleep 2
MOUNT="/Volumes/$VOL"

# The Finder background must live inside the volume
mkdir -p "$MOUNT/.background"
cp "$BG" "$MOUNT/.background/background.png"

# Window styling needs Finder Automation permission; degrade gracefully.
osascript <<'EOF' 2>/dev/null || echo "(Finder styling skipped — no Automation permission; DMG is still fully functional)"
with timeout of 25 seconds
tell application "Finder"
  tell disk "MacWall"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 568}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set background picture of viewOptions to file ".background:background.png"
    set position of item "MacWall.app" of container window to {150, 168}
    set position of item "Applications" of container window to {510, 168}
    set position of item "INSTALL.txt" of container window to {330, 330}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
end timeout
EOF

sync
hdiutil detach "$MOUNT" >/dev/null

rm -f "$OUT"
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUT" >/dev/null
rm -f "$RW"
rm -rf "$STAGE"

echo "DMG: $(pwd)/$OUT ($(du -h "$OUT" | cut -f1 | tr -d ' '))"
