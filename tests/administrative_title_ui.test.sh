#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if grep -RInE --include='*.swift' '總務(工作台|工作摘要|工作提醒|提醒|任務操作|任務)' Sources/DeskPet; then
  echo "ERROR: administrative-title UI labels must not be hard-coded" >&2
  exit 1
fi

if grep -RInE --include='*.swift' '(saveWorkRoleName|resetWorkRoleName|@Published[^\n]*workRoleName)' Sources/DeskPet; then
  echo "ERROR: the retired standalone work-role setting is still active" >&2
  exit 1
fi

STORE="Sources/DeskPet/Stores/GASTaskConfigurationStore.swift"
for contract in \
  'defaultAdministrativeTitle = "總務"' \
  '"\(administrativeTitle)工作台"' \
  '"\(administrativeTitle)工作摘要"' \
  '"\(administrativeTitle)工作提醒"' \
  '"\(administrativeTitle)任務操作"' \
  'removeObject(forKey: DefaultsKey.legacyWorkRoleName)'; do
  if ! grep -Fq "$contract" "$STORE"; then
    echo "ERROR: administrative-title UI contract is missing: $contract" >&2
    exit 1
  fi
done

echo "DeskPet administrative-title UI checks passed"
