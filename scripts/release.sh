#!/bin/bash
# One-shot public release: bakes the wallpaper-list link INTO the app
# (compiled default — it must travel inside the DMG, a local defaults write
# does not), rebuilds, and produces the shareable MacWall.dmg.
#
# Usage: bash scripts/release.sh <wallpaper-list-url>
#   e.g. bash scripts/release.sh https://mohind.gumroad.com/l/macwall-wallpapers
#
# Safe to re-run with a new URL at any time: it only rewrites that one line.
set -euo pipefail
cd "$(dirname "$0")/.."

URL="${1:?usage: bash scripts/release.sh <wallpaper-list-url>}"
case "$URL" in
  http://*|https://*) ;;
  *) echo "That does not look like a URL: $URL"; exit 1 ;;
esac

echo "Baking wallpaper-list link: $URL"
/usr/bin/sed -i '' -E \
  "s|static let compiledWallpaperListURL: String\? = .*|static let compiledWallpaperListURL: String? = \"${URL}\"|" \
  Sources/Support.swift
grep -n "compiledWallpaperListURL: String?" Sources/Support.swift

bash build.sh
bash scripts/make_dmg.sh
cp MacWall.dmg ../MacWall.dmg

echo "Release ready: $(pwd)/../MacWall.dmg"
echo "The BROWSE WALLPAPERS button now opens $URL on every copy."
