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

HANDOFF_LINE="$(grep -nF 'report_progress 88 "準備替換 App；DeskPet 即將重新啟動"' "$UPDATER" | cut -d: -f1)"
REDIRECT_LINE="$(grep -nF 'exec >> "$PROGRESS_LOG" 2>&1' "$UPDATER" | cut -d: -f1)"
WAIT_LINE="$(grep -nF 'Waiting for DeskPet process $WAIT_PID to exit before replacement' "$UPDATER" | cut -d: -f1)"
OPEN_LINE="$(grep -nF '/usr/bin/open -n "$DESTINATION"' "$UPDATER" | cut -d: -f1)"

if [[ -z "$HANDOFF_LINE" || -z "$REDIRECT_LINE" || -z "$WAIT_LINE" || -z "$OPEN_LINE" ]]; then
  echo "ERROR: updater hand-off markers are missing" >&2
  exit 1
fi

if [[ "$HANDOFF_LINE" -ge "$REDIRECT_LINE" || "$REDIRECT_LINE" -ge "$WAIT_LINE" || "$WAIT_LINE" -ge "$OPEN_LINE" ]]; then
  echo "ERROR: updater must announce hand-off, detach output, wait for old PID, then launch" >&2
  exit 1
fi

grep -qF 'DESKPET_PROGRESS_PROTOCOL' "$SERVICE"
grep -qF 'consumeUpdaterOutput' "$SERVICE"
grep -qF '"--wait-pid", String(ProcessInfo.processInfo.processIdentifier)' "$SERVICE"
grep -qF 'NSApp.terminate(nil)' "$SERVICE"
grep -qF 'stage.contains("準備替換")' "$SERVICE"
grep -qF 'ProgressView(value: softwareUpdate.installProgress' "$SETTINGS"

echo "DeskPet updater hand-off and visible progress contract tests passed"
