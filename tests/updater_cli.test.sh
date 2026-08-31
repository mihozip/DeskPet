#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATER="$ROOT_DIR/script/install_or_update.sh"

"$UPDATER" --help >/dev/null

if "$UPDATER" --destination relative/DeskPet.app --no-launch >/dev/null 2>&1; then
  echo "ERROR: updater accepted a relative destination" >&2
  exit 1
fi

if "$UPDATER" --destination /tmp/Other.app --no-launch >/dev/null 2>&1; then
  echo "ERROR: updater accepted an unexpected app name" >&2
  exit 1
fi

if "$UPDATER" --wait-pid not-a-pid --no-launch >/dev/null 2>&1; then
  echo "ERROR: updater accepted a non-numeric PID" >&2
  exit 1
fi

if "$UPDATER" --version not-a-version --destination /tmp/DeskPet.app --no-launch >/dev/null 2>&1; then
  echo "ERROR: updater accepted an invalid target version" >&2
  exit 1
fi

DOWNLOAD_STATUS_LINE="$(grep '^echo "Downloading DeskPet ' "$UPDATER")"
TEST_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
if ! TARGET_VERSION="$TEST_VERSION" /bin/bash -u -c "$DOWNLOAD_STATUS_LINE" >/dev/null; then
  echo "ERROR: updater release status output is unsafe under Bash nounset" >&2
  exit 1
fi

if grep -qF '$TARGET_VERSION…' "$UPDATER"; then
  echo "ERROR: updater contains an unbraced variable next to Unicode punctuation" >&2
  exit 1
fi

if grep -qF 'Building DeskPet' "$UPDATER"; then
  echo "ERROR: standalone updater still exposes the retired local-build path" >&2
  exit 1
fi

echo "DeskPet updater CLI validation tests passed"
