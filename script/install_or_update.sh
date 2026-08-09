#!/usr/bin/env bash
# DESKPET_STANDALONE_UPDATER=1
set -euo pipefail

REPOSITORY="mihozip/DeskPet"
SOURCE_ARCHIVE_URL="https://github.com/${REPOSITORY}/archive/refs/heads/main.zip"
DESTINATION="${HOME}/Applications/DeskPet.app"
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
Install or update DeskPet from the public GitHub repository.

Usage:
  install_or_update.sh [--destination /absolute/path/DeskPet.app]
                       [--wait-pid PID]
                       [--no-launch]

The updater builds the latest source with the local Apple Swift toolchain,
verifies the new app before replacement, and restores the previous app if
installation fails. User data and Keychain credentials are not removed.
USAGE
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --destination)
      [[ "$#" -ge 2 ]] || { echo "ERROR: --destination requires a path" >&2; exit 2; }
      DESTINATION="$2"
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

for command_path in /usr/bin/curl /usr/bin/ditto /usr/bin/codesign /usr/bin/xcrun /usr/bin/open /usr/bin/xattr /usr/bin/pkill /usr/libexec/PlistBuddy; do
  [[ -x "$command_path" ]] || { echo "ERROR: required tool is missing: $command_path" >&2; exit 1; }
done
command -v swift >/dev/null 2>&1 || { echo "ERROR: Swift toolchain is required. Install Xcode or Apple Command Line Tools." >&2; exit 1; }
report_progress 5 "準備更新環境"

UPDATE_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/deskpet-update.XXXXXX")"
SOURCE_DIR="$UPDATE_TEMP_DIR/source"
ARCHIVE_PATH="$UPDATE_TEMP_DIR/DeskPet-main.zip"
BACKUP_APP="$UPDATE_TEMP_DIR/DeskPet.previous.app"
REPLACEMENT_STARTED=0

cleanup_and_rollback() {
  local exit_code=$?
  if [[ "$exit_code" -ne 0 && "$REPLACEMENT_STARTED" -eq 1 && -d "$BACKUP_APP" ]]; then
    echo "Update failed; restoring the previous DeskPet.app…" >&2
    /bin/rm -rf "$DESTINATION"
    /bin/mv "$BACKUP_APP" "$DESTINATION"
  fi
  /bin/rm -rf "$UPDATE_TEMP_DIR"
  if [[ "$exit_code" -ne 0 ]]; then
    echo "DeskPet update failed (exit $exit_code). The previous installation was preserved when available." >&2
  fi
  exit "$exit_code"
}
trap cleanup_and_rollback EXIT

if [[ -n "$WAIT_PID" ]]; then
  report_progress 8 "等待 DeskPet 關閉"
  echo "Waiting for DeskPet process $WAIT_PID to exit…"
  wait_deadline=$((SECONDS + 30))
  while /bin/kill -0 "$WAIT_PID" 2>/dev/null; do
    if [[ "$SECONDS" -ge "$wait_deadline" ]]; then
      echo "ERROR: DeskPet did not exit within 30 seconds" >&2
      exit 1
    fi
    /bin/sleep 1
  done
fi

echo "Downloading latest DeskPet source from GitHub…"
report_progress 10 "正在下載最新原始碼"
/usr/bin/curl \
  --fail --location --silent --show-error \
  --connect-timeout 10 --max-time 180 \
  --retry 2 --retry-delay 2 --retry-all-errors \
  "$SOURCE_ARCHIVE_URL" \
  --output "$ARCHIVE_PATH"
report_progress 22 "原始碼下載完成"

mkdir -p "$SOURCE_DIR"
report_progress 25 "正在解壓並驗證專案"
/usr/bin/ditto -x -k "$ARCHIVE_PATH" "$SOURCE_DIR"
PACKAGE_PATH="$(find "$SOURCE_DIR" -maxdepth 2 -type f -name Package.swift -print -quit)"
[[ -n "$PACKAGE_PATH" ]] || { echo "ERROR: downloaded archive does not contain Package.swift" >&2; exit 1; }
PROJECT_DIR="$(dirname "$PACKAGE_PATH")"
[[ -n "$PROJECT_DIR" && -x "$PROJECT_DIR/script/build_release.sh" ]] || {
  echo "ERROR: downloaded archive does not contain a valid DeskPet project" >&2
  exit 1
}

LATEST_VERSION="$(tr -d '[:space:]' < "$PROJECT_DIR/VERSION")"
[[ "$LATEST_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "ERROR: downloaded VERSION is invalid" >&2
  exit 1
}
report_progress 32 "已驗證 DeskPet ${LATEST_VERSION}"

PRESERVED_BUNDLE_ID=""
if [[ -f "$DESTINATION/Contents/Info.plist" ]]; then
  PRESERVED_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DESTINATION/Contents/Info.plist" 2>/dev/null || true)"
fi

echo "Building DeskPet ${LATEST_VERSION}…"
report_progress 35 "正在使用 Swift 建置 DeskPet ${LATEST_VERSION}"
if [[ -n "$PRESERVED_BUNDLE_ID" ]]; then
  BUNDLE_ID="$PRESERVED_BUNDLE_ID" "$PROJECT_DIR/script/build_release.sh"
else
  "$PROJECT_DIR/script/build_release.sh"
fi
report_progress 75 "DeskPet ${LATEST_VERSION} 建置完成"

NEW_APP="$PROJECT_DIR/dist-release/DeskPet.app"
[[ -x "$NEW_APP/Contents/MacOS/DeskPet" ]] || { echo "ERROR: update build did not produce DeskPet.app" >&2; exit 1; }
/usr/bin/codesign --verify --deep --strict --verbose=2 "$NEW_APP"
report_progress 82 "新版本簽章驗證完成"

report_progress 88 "準備替換 App；DeskPet 即將重新啟動"
if [[ "$PROGRESS_PROTOCOL" == "1" ]]; then
  /bin/sleep 1
  if [[ "$PROGRESS_LOG" == /* ]]; then
    exec >> "$PROGRESS_LOG" 2>&1
  fi
fi
/usr/bin/pkill -x DeskPet 2>/dev/null || true
mkdir -p "$(dirname "$DESTINATION")"
if [[ -d "$DESTINATION" ]]; then
  report_progress 90 "正在備份目前版本"
  /usr/bin/ditto "$DESTINATION" "$BACKUP_APP"
  /usr/bin/xattr -cr "$BACKUP_APP" 2>/dev/null || true
  if ! /usr/bin/codesign --verify --deep --strict --verbose=2 "$BACKUP_APP"; then
    echo "WARN: previous app is not fully code-sign verifiable; backup will still be retained for rollback" >&2
  fi
fi
REPLACEMENT_STARTED=1
report_progress 94 "正在安裝新版本"
/bin/rm -rf "$DESTINATION"
/usr/bin/ditto "$NEW_APP" "$DESTINATION"
/usr/bin/xattr -cr "$DESTINATION" 2>/dev/null || true
/usr/bin/codesign --verify --deep --strict --verbose=2 "$DESTINATION"
report_progress 98 "新版本安裝驗證完成"
if [[ "$SHOULD_LAUNCH" -eq 1 ]]; then
  /usr/bin/open -n "$DESTINATION"
fi

report_progress 100 "DeskPet ${LATEST_VERSION} 更新完成"
echo "DeskPet ${LATEST_VERSION} installed successfully: $DESTINATION"
