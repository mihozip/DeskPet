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

BUILD_STATUS_LINE="$(grep '^echo "Building DeskPet ' "$UPDATER")"
if ! LATEST_VERSION=0.9.2.1 /bin/bash -u -c "$BUILD_STATUS_LINE" >/dev/null; then
  echo "ERROR: updater status output is unsafe under Bash nounset" >&2
  exit 1
fi

if grep -qF '$LATEST_VERSION…' "$UPDATER"; then
  echo "ERROR: updater contains an unbraced variable next to Unicode punctuation" >&2
  exit 1
fi

echo "DeskPet updater CLI validation tests passed"
