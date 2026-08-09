#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATER="$ROOT_DIR/script/install_or_update.sh"
SERVICE="$ROOT_DIR/Sources/DeskPet/Services/SoftwareUpdateService.swift"
SETTINGS="$ROOT_DIR/Sources/DeskPet/Views/SettingsView.swift"

EXPECTED="5 8 10 22 25 32 35 75 82 88 90 94 98 100"
ACTUAL="$(sed -nE 's/^[[:space:]]*report_progress ([0-9]+) .*/\1/p' "$UPDATER" | tr '\n' ' ' | sed 's/ $//')"
if [[ "$ACTUAL" != "$EXPECTED" ]]; then
  echo "ERROR: updater progress sequence changed: $ACTUAL" >&2
  exit 1
fi

REDIRECT_LINE="$(grep -nF 'exec >> "$PROGRESS_LOG" 2>&1' "$UPDATER" | cut -d: -f1)"
STOP_LINE="$(grep -nF '/usr/bin/pkill -x DeskPet' "$UPDATER" | cut -d: -f1)"
if [[ -z "$REDIRECT_LINE" || -z "$STOP_LINE" || "$REDIRECT_LINE" -ge "$STOP_LINE" ]]; then
  echo "ERROR: updater must detach output before stopping DeskPet" >&2
  exit 1
fi

grep -qF 'DESKPET_PROGRESS_PROTOCOL' "$SERVICE"
grep -qF 'consumeUpdaterOutput' "$SERVICE"
grep -qF 'ProgressView(value: softwareUpdate.installProgress' "$SETTINGS"

if grep -qF '"--wait-pid"' "$SERVICE" || grep -qF 'NSApp.terminate' "$SERVICE"; then
  echo "ERROR: app-side updater must remain open until the replacement stage" >&2
  exit 1
fi

echo "DeskPet visible update progress contract tests passed"
