#!/bin/bash
# Build MacWall.app (native, ad-hoc signed, with app icon).
# Usage: bash build.sh [--install]
set -euo pipefail
cd "$(dirname "$0")"

APP="build/MacWall.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# App icon (generated once, then kept in Resources/)
if [ ! -f Resources/AppIcon.icns ]; then
  echo "Generating app icon…"
  mkdir -p build/icon.iconset
  swift tools/gen_icon.swift build/icon.iconset
  iconutil -c icns build/icon.iconset -o Resources/AppIcon.icns
fi

echo "Compiling…"
swiftc -O -swift-version 5 \
  -target arm64-apple-macosx13.0 \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/MacWall" \
  -framework AppKit -framework AVFoundation -framework SwiftUI -framework ServiceManagement

cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/*.ttf "$APP/Contents/Resources/" 2>/dev/null || true
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "Built: $(pwd)/$APP"

if [[ "${1:-}" == "--install" ]]; then
  echo "Installing to ~/Applications…"
  pkill -x MacWall 2>/dev/null || true
  sleep 1
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/MacWall.app"
  ditto "$APP" "$HOME/Applications/MacWall.app"
  echo "Installed: $HOME/Applications/MacWall.app"
fi
