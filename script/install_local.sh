#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="$HOME/Applications"
DEST_APP="$DEST_DIR/DeskPet.app"

"$ROOT_DIR/script/build_release.sh"
mkdir -p "$DEST_DIR"
rm -rf "$DEST_APP"
cp -R "$ROOT_DIR/dist-release/DeskPet.app" "$DEST_APP"
/usr/bin/open -n "$DEST_APP"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
echo "Installed DeskPet $VERSION locally: $DEST_APP"
echo "建議從這個位置啟用「登入後自動啟動」。"
