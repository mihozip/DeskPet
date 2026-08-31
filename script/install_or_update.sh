#!/usr/bin/env bash
# DESKPET_STANDALONE_UPDATER=1
set -euo pipefail

REPOSITORY="mihozip/DeskPet"
VERSION_URL="https://raw.githubusercontent.com/${REPOSITORY}/main/VERSION"
DESTINATION="${HOME}/Applications/DeskPet.app"
TARGET_VERSION=""
WAIT_PID=""
SHOULD_LAUNCH=1
PROGRESS_PROTOCOL="${DESKPET_PROGRESS_PROTOCOL:-0}"
PROGRESS_LOG="${DESKPET_PROGRESS_LOG:-}"

report_progress() {
  local percent="$1"
  shift
  if [[ "$PROGRESS_PROTOCOL" == "1" ]]; then
    printf 'DESKPET_PROGRESS|%s|%s\n' "$percent" "$*"
  fi
}

usage() {
  cat <<'USAGE'
Install or update DeskPet from the published GitHub Release asset.

Usage:
  install_or_update.sh [--destination /absolute/path/DeskPet.app]
                       [--version 1.4.0.1]
                       [--wait-pid PID]
                       [--no-launch]

The updater downloads the already-built DeskPet release ZIP, verifies the app
bundle and code signature while DeskPet remains open, then closes the old app,
replaces it atomically with rollback protection, and launches the new version.
No local Swift/Xcode build is required.
USAGE
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --destination)
      [[ "$#" -ge 2 ]] || { echo "ERROR: --destination requires a path" >&2; exit 2; }
      DESTINATION="$2"
      shift 2
      ;;
    --version)
      [[ "$#" -ge 2 ]] || { echo "ERROR: --version requires a value" >&2; exit 2; }
      TARGET_VERSION="$2"
      shift 2
      ;;
    --wait-pid)
      [[ "$#" -ge 2 && "$2" =~ ^[0-9]+$ ]] || { echo "ERROR: --wait-pid requires a numeric PID" >&2; exit 2; }
      WAIT_PID="$2"
      shift 2
      ;;
    --no-launch)
      SHOULD_LAUNCH=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$DESTINATION" != /* || "$DESTINATION" != *.app ]]; then
  echo "ERROR: destination must be an absolute .app path" >&2
  exit 2
fi

if [[ "$(basename "$DESTINATION")" != "DeskPet.app" ]]; then
  echo "ERROR: destination app must be named DeskPet.app" >&2
  exit 2
fi

for command_path in /usr/bin/curl /usr/bin/ditto /usr/bin/codesign /usr/bin/open /usr/bin/xattr /usr/bin/pkill /usr/bin/pgrep /usr/libexec/PlistBuddy; do
  [[ -x "$command_path" ]] || { echo "ERROR: required tool is missing: $command_path" >&2; exit 1; }
done

report_progress 5 "準備更新環境"
if [[ -n "$WAIT_PID" ]]; then
  report_progress 8 "已準備 DeskPet 更新交接"
fi

if [[ -z "$TARGET_VERSION" ]]; then
  TARGET_VERSION="$(/usr/bin/curl \
    --fail --location --silent --show-error \
    --connect-timeout 10 --max-time 30 \
    --retry 2 --retry-delay 2 --retry-all-errors \
    "$VERSION_URL" | tr -d '[:space:]')"
fi

[[ "$TARGET_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "ERROR: target VERSION is invalid: $TARGET_VERSION" >&2
  exit 1
}

RELEASE_ZIP_URL="https://github.com/${REPOSITORY}/releases/download/v${TARGET_VERSION}/DeskPet-${TARGET_VERSION}.zip"
UPDATE_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/deskpet-update.XXXXXX")"
EXTRACT_DIR="$UPDATE_TEMP_DIR/extracted"
ARCHIVE_PATH="$UPDATE_TEMP_DIR/DeskPet-${TARGET_VERSION}.zip"
BACKUP_APP="$UPDATE_TEMP_DIR/DeskPet.previous.app"
REPLACEMENT_STARTED=0
HANDOFF_STARTED=0

cleanup_and_rollback() {
  local exit_code=$?

  if [[ "$exit_code" -ne 0 && "$REPLACEMENT_STARTED" -eq 1 && -d "$BACKUP_APP" ]]; then
    echo "Update failed; restoring the previous DeskPet.app…" >&2
    /bin/rm -rf "$DESTINATION" 2>/dev/null || true
    /bin/mv "$BACKUP_APP" "$DESTINATION" 2>/dev/null || true
  fi

  if [[ "$exit_code" -ne 0 && "$HANDOFF_STARTED" -eq 1 && "$SHOULD_LAUNCH" -eq 1 && -d "$DESTINATION" ]]; then
    /usr/bin/open -n "$DESTINATION" >/dev/null 2>&1 || true
  fi

  /bin/rm -rf "$UPDATE_TEMP_DIR"
  if [[ "$exit_code" -ne 0 ]]; then
    echo "DeskPet update failed (exit $exit_code). The previous installation was preserved when available." >&2
  fi
  exit "$exit_code"
}
trap cleanup_and_rollback EXIT

echo "Downloading DeskPet ${TARGET_VERSION} release asset…"
report_progress 10 "正在下載 DeskPet ${TARGET_VERSION} 發布包"
/usr/bin/curl \
  --fail --location --silent --show-error \
  --connect-timeout 10 --max-time 180 \
  --retry 3 --retry-delay 2 --retry-all-errors \
  "$RELEASE_ZIP_URL" \
  --output "$ARCHIVE_PATH"
report_progress 22 "發布包下載完成"

mkdir -p "$EXTRACT_DIR"
report_progress 25 "正在解壓並驗證發布包"
/usr/bin/ditto -x -k "$ARCHIVE_PATH" "$EXTRACT_DIR"
NEW_APP="$(find "$EXTRACT_DIR" -maxdepth 3 -type d -name DeskPet.app -print -quit)"
[[ -n "$NEW_APP" && -x "$NEW_APP/Contents/MacOS/DeskPet" ]] || {
  echo "ERROR: release archive does not contain a valid DeskPet.app" >&2
  exit 1
}

NEW_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$NEW_APP/Contents/Info.plist" 2>/dev/null || true)"
[[ "$NEW_VERSION" == "$TARGET_VERSION" ]] || {
  echo "ERROR: release bundle version mismatch: expected $TARGET_VERSION, got ${NEW_VERSION:-unknown}" >&2
  exit 1
}
report_progress 32 "已驗證 DeskPet ${TARGET_VERSION} 版本"

CURRENT_BUNDLE_ID=""
if [[ -f "$DESTINATION/Contents/Info.plist" ]]; then
  CURRENT_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DESTINATION/Contents/Info.plist" 2>/dev/null || true)"
fi
NEW_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$NEW_APP/Contents/Info.plist" 2>/dev/null || true)"
if [[ -n "$CURRENT_BUNDLE_ID" && -n "$NEW_BUNDLE_ID" && "$CURRENT_BUNDLE_ID" != "$NEW_BUNDLE_ID" ]]; then
  echo "ERROR: bundle identifier mismatch: current=$CURRENT_BUNDLE_ID new=$NEW_BUNDLE_ID" >&2
  exit 1
fi

/usr/bin/xattr -cr "$NEW_APP" 2>/dev/null || true
/usr/bin/codesign --verify --deep --strict --verbose=2 "$NEW_APP"
report_progress 82 "新版本簽章驗證完成"

DESTINATION_PARENT="$(dirname "$DESTINATION")"
if [[ ! -d "$DESTINATION_PARENT" ]]; then
  mkdir -p "$DESTINATION_PARENT"
fi
[[ -w "$DESTINATION_PARENT" ]] || {
  echo "ERROR: destination directory is not writable: $DESTINATION_PARENT" >&2
  exit 1
}

# This is the hand-off point. Everything network/build/signature related has
# already succeeded. Only now do we ask the running app to terminate.
report_progress 88 "準備替換 App；DeskPet 即將重新啟動"
HANDOFF_STARTED=1
if [[ "$PROGRESS_PROTOCOL" == "1" && "$PROGRESS_LOG" == /* ]]; then
  exec >> "$PROGRESS_LOG" 2>&1
fi

if [[ -n "$WAIT_PID" ]]; then
  echo "Waiting for DeskPet process $WAIT_PID to exit before replacement…"
  wait_deadline=$((SECONDS + 30))
  while /bin/kill -0 "$WAIT_PID" 2>/dev/null; do
    if [[ "$SECONDS" -ge "$wait_deadline" ]]; then
      echo "ERROR: DeskPet did not exit within 30 seconds" >&2
      exit 1
    fi
    /bin/sleep 1
  done
else
  /usr/bin/pkill -x DeskPet 2>/dev/null || true
  wait_deadline=$((SECONDS + 30))
  while /usr/bin/pgrep -x DeskPet >/dev/null 2>&1; do
    if [[ "$SECONDS" -ge "$wait_deadline" ]]; then
      echo "ERROR: running DeskPet processes did not exit within 30 seconds" >&2
      exit 1
    fi
    /bin/sleep 1
  done
fi

if [[ -d "$DESTINATION" ]]; then
  report_progress 90 "正在備份目前版本"
  /usr/bin/ditto "$DESTINATION" "$BACKUP_APP"
  /usr/bin/xattr -cr "$BACKUP_APP" 2>/dev/null || true
fi

REPLACEMENT_STARTED=1
report_progress 94 "正在安裝新版本"
/bin/rm -rf "$DESTINATION"
/usr/bin/ditto "$NEW_APP" "$DESTINATION"
/usr/bin/xattr -cr "$DESTINATION" 2>/dev/null || true
/usr/bin/codesign --verify --deep --strict --verbose=2 "$DESTINATION"
INSTALLED_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DESTINATION/Contents/Info.plist" 2>/dev/null || true)"
[[ "$INSTALLED_VERSION" == "$TARGET_VERSION" ]] || {
  echo "ERROR: installed version verification failed: expected $TARGET_VERSION, got ${INSTALLED_VERSION:-unknown}" >&2
  exit 1
}
report_progress 98 "新版本安裝驗證完成"

if [[ "$SHOULD_LAUNCH" -eq 1 ]]; then
  /usr/bin/open -n "$DESTINATION"
fi

report_progress 100 "DeskPet ${TARGET_VERSION} 更新完成"
echo "DeskPet ${TARGET_VERSION} installed successfully: $DESTINATION"
