#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PANEL_CONTROLLER="Sources/DeskPet/Window/PetPanelController.swift"
PANEL="Sources/DeskPet/Window/PetPanel.swift"
ROOT_VIEW="Sources/DeskPet/Views/PetRootView.swift"
HOTKEY="Sources/DeskPet/Services/GlobalHotKeyService.swift"
APP_DELEGATE="Sources/DeskPet/App/AppDelegate.swift"
STATUS_MENU="Sources/DeskPet/App/StatusMenuController.swift"

grep -Fq 'styleMask: [.borderless]' "$PANEL_CONTROLLER"
if grep -Fq '.nonactivatingPanel' "$PANEL_CONTROLLER"; then
    echo "ERROR: desktop pet must not use nonactivatingPanel" >&2
    exit 1
fi

grep -Fq 'panel.ignoresMouseEvents = false' "$PANEL_CONTROLLER"
grep -Fq 'PetHostingView(rootView: rootView)' "$PANEL_CONTROLLER"
grep -Fq 'acceptsFirstMouse' "$PANEL"
grep -Fq 'Color.black.opacity(0.001)' "$ROOT_VIEW"
grep -Fq 'GetApplicationEventTarget()' "$HOTKEY"
grep -Fq 'StatusMenuController' "$APP_DELEGATE"
grep -Fq '快速記事' "$STATUS_MENU"
grep -Fq '查詢行事曆…' "$STATUS_MENU"

echo "Desktop interaction contract: PASS"
