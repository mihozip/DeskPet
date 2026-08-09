#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if grep -RInE --include='*.swift' '總務(工作台|工作摘要|提醒|任務操作|任務)' Sources/DeskPet; then
  echo "ERROR: user-facing work-role labels must not be hard-coded" >&2
  exit 1
fi

for symbol in workbenchTitle taskDigestTitle taskActionTitle reminderTitle saveWorkRoleName resetWorkRoleName; do
  if ! grep -Rqs --include='*.swift' "$symbol" Sources/DeskPet; then
    echo "ERROR: configurable work-role contract is missing: $symbol" >&2
    exit 1
  fi
done

echo "DeskPet configurable work-role label checks passed"
