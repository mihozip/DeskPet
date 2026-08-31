#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATER="$ROOT_DIR/script/install_or_update.sh"
BUILD_RELEASE="$ROOT_DIR/script/build_release.sh"
SERVICE="$ROOT_DIR/Sources/DeskPet/Services/SoftwareUpdateService.swift"
SETTINGS="$ROOT_DIR/Sources/DeskPet/Views/SettingsView.swift"

EXPECTED="5 8 10 22 25 32 82 88 90 94 98 100"
ACTUAL="$(sed -nE 's/^[[:space:]]*report_progress ([0-9]+) .*/\1/p' "$UPDATER" | tr '\n' ' ' | sed 's/ $//')"
if [[ "$ACTUAL" != "$EXPECTED" ]]; then
  echo "ERROR: updater progress sequence changed: $ACTUAL" >&2
  exit 1
fi

HANDOFF_LINE="$(grep -nF 'report_progress 88 "準備替換 App；DeskPet 即將重新啟動"' "$UPDATER" | cut -d: -f1)"
REDIRECT_LINE="$(grep -nF 'exec >> "$PROGRESS_LOG" 2>&1' "$UPDATER" | cut -d: -f1)"
WAIT_LINE="$(grep -nF 'Waiting for DeskPet process $WAIT_PID to exit before replacement' "$UPDATER" | cut -d: -f1)"
OPEN_LINE="$(grep -nF '/usr/bin/open -n "$DESTINATION"' "$UPDATER" | tail -1 | cut -d: -f1)"

if [[ -z "$HANDOFF_LINE" || -z "$REDIRECT_LINE" || -z "$WAIT_LINE" || -z "$OPEN_LINE" ]]; then
  echo "ERROR: updater hand-off markers are missing" >&2
  exit 1
fi

if [[ "$HANDOFF_LINE" -ge "$REDIRECT_LINE" || "$REDIRECT_LINE" -ge "$WAIT_LINE" || "$WAIT_LINE" -ge "$OPEN_LINE" ]]; then
  echo "ERROR: updater must announce hand-off, detach output, wait for old PID, then launch" >&2
  exit 1
fi

# RC1.4.0.1 updater must install the published release asset instead of
# requiring a local Swift/Xcode rebuild.
grep -qF 'releases/download/v${TARGET_VERSION}/DeskPet-${TARGET_VERSION}.zip' "$UPDATER"
grep -qF 'No local Swift/Xcode build is required.' "$UPDATER"
if grep -qF 'command -v swift' "$UPDATER"; then
  echo "ERROR: standalone updater must not require Swift toolchain" >&2
  exit 1
fi
if grep -qF 'swift build' "$UPDATER"; then
  echo "ERROR: standalone updater must not build source locally" >&2
  exit 1
fi

grep -qF 'release bundle version mismatch' "$UPDATER"
grep -qF 'bundle identifier mismatch' "$UPDATER"
grep -qF 'installed version verification failed' "$UPDATER"
grep -qF 'HANDOFF_STARTED=1' "$UPDATER"
grep -qF '/usr/bin/open -n "$DESTINATION" >/dev/null 2>&1 || true' "$UPDATER"

# Compatibility bridge lets the already-shipped 1.2.1.1–1.4.0.0 updater use
# the published asset after it downloads the current main source tree.
grep -qF 'Legacy updater compatibility: trying published DeskPet' "$BUILD_RELEASE"
grep -qF 'DESKPET_PROGRESS_PROTOCOL' "$BUILD_RELEASE"
grep -qF 'falling back to local source build' "$BUILD_RELEASE"

grep -qF 'DESKPET_PROGRESS_PROTOCOL' "$SERVICE"
grep -qF 'consumeUpdaterOutput' "$SERVICE"
grep -qF '"--wait-pid", String(ProcessInfo.processInfo.processIdentifier)' "$SERVICE"
grep -qF 'NSApp.terminate(nil)' "$SERVICE"
grep -qF 'stage.contains("準備替換")' "$SERVICE"
grep -qF 'ProgressView(value: softwareUpdate.installProgress' "$SETTINGS"

echo "DeskPet release-asset updater hand-off and legacy compatibility contract tests passed"
