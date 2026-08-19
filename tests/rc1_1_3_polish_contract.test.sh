#!/usr/bin/env bash
set -euo pipefail

# Release contract for RC1.1.3 desktop-polish behavior, with the RC1.2.1
# clarification that read-only Today Work / Work Context remains available
# without GAS while GAS-specific mutation/sync affordances stay gated.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATE_SERVICE="$ROOT_DIR/Sources/DeskPet/Services/SoftwareUpdateService.swift"
APP_DELEGATE="$ROOT_DIR/Sources/DeskPet/App/AppDelegate.swift"
GAS_CONFIG="$ROOT_DIR/Sources/DeskPet/Stores/GASTaskConfigurationStore.swift"
PET_ROOT="$ROOT_DIR/Sources/DeskPet/Views/PetRootView.swift"
STATUS_MENU="$ROOT_DIR/Sources/DeskPet/App/StatusMenuController.swift"
PET_PANEL="$ROOT_DIR/Sources/DeskPet/Window/PetPanelController.swift"

grep -qF 'automaticCheckInterval: TimeInterval = 7 * 24 * 60 * 60' "$UPDATE_SERVICE"
grep -qF 'onUpdateAvailable?(latestVersion)' "$UPDATE_SERVICE"
grep -qF 'func startAutomaticChecking()' "$UPDATE_SERVICE"
grep -qF 'softwareUpdate.startAutomaticChecking()' "$APP_DELEGATE"
grep -qF 'alert.messageText = "白帥帥有新版本"' "$APP_DELEGATE"
grep -qF 'alert.addButton(withTitle: "立即更新")' "$APP_DELEGATE"

grep -qF 'var isLinked: Bool' "$GAS_CONFIG"
grep -qF 'canUseConnector && integrationMetadata != nil' "$GAS_CONFIG"

# Read-only Today Work is now a DeskPet capability, not a GAS-only menu.
grep -qF 'Button("今日工作") { onOpenTaskDigest() }' "$PET_ROOT"
grep -qF 'workMenu.addItem(makeItem(title: "今日工作", action: #selector(openTaskDigest)))' "$STATUS_MENU"

# GAS-specific actions remain behind the verified isLinked boundary.
grep -qF 'if gasConfiguration.isLinked {' "$PET_ROOT"
grep -qF 'Button("自然語句操作…")' "$PET_ROOT"
grep -qF 'Button("立即同步校務任務系統")' "$PET_ROOT"

grep -qF 'panel.level = .normal' "$PET_PANEL"
grep -qF 'panel.isFloatingPanel = false' "$PET_PANEL"
if grep -qF 'panel.level = .floating' "$PET_PANEL"; then
  echo "ERROR: DeskPet must not remain at floating window level" >&2
  exit 1
fi

echo "DeskPet RC1.1.3 desktop polish contract tests passed"
