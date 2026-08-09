#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ICON="$ROOT_DIR/Sources/DeskPet/Resources/AppIcon.png"
BUNDLE_ICON="$ROOT_DIR/Sources/DeskPet/Resources/AppIcon.icns"

[[ -s "$SOURCE_ICON" && -s "$BUNDLE_ICON" ]]
width="$(sips -g pixelWidth "$SOURCE_ICON" 2>/dev/null | awk '/pixelWidth/ { print $2 }')"
height="$(sips -g pixelHeight "$SOURCE_ICON" 2>/dev/null | awk '/pixelHeight/ { print $2 }')"
[[ "$width" == "$height" && "$width" -ge 1024 ]]

VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/deskpet-icon-test.XXXXXX")"
trap '/bin/rm -rf "$VERIFY_DIR"' EXIT
iconutil -c iconset "$BUNDLE_ICON" -o "$VERIFY_DIR/AppIcon.iconset"
[[ -s "$VERIFY_DIR/AppIcon.iconset/icon_512x512@2x.png" ]]

icon_width="$(sips -g pixelWidth "$VERIFY_DIR/AppIcon.iconset/icon_512x512@2x.png" 2>/dev/null | awk '/pixelWidth/ { print $2 }')"
icon_height="$(sips -g pixelHeight "$VERIFY_DIR/AppIcon.iconset/icon_512x512@2x.png" 2>/dev/null | awk '/pixelHeight/ { print $2 }')"
[[ "$icon_width" == "1024" && "$icon_height" == "1024" ]]

echo "DeskPet app icon contract tests passed"
