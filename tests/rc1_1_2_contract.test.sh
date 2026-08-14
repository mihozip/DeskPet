#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTION="$ROOT_DIR/Sources/DeskPet/Services/CalendarActionService.swift"
PET_MENU="$ROOT_DIR/Sources/DeskPet/Views/PetRootView.swift"
STATUS_MENU="$ROOT_DIR/Sources/DeskPet/App/StatusMenuController.swift"

# Calendar and Reminders requests must be isolated at the service boundary.
grep -qF 'private let calendarStore = EKEventStore()' "$ACTION"
grep -qF 'private let remindersStore = EKEventStore()' "$ACTION"
grep -qF 'calendarStore.requestFullAccessToEvents()' "$ACTION"
grep -qF 'remindersStore.requestFullAccessToReminders()' "$ACTION"
if grep -qF 'calendarStore.requestFullAccessToReminders' "$ACTION"; then
  echo "ERROR: Calendar store must not request Reminders access" >&2
  exit 1
fi
if grep -qF 'remindersStore.requestFullAccessToEvents' "$ACTION"; then
  echo "ERROR: Reminders store must not request Calendar access" >&2
  exit 1
fi

# The pet menu must stay compact and group secondary actions.
grep -qF 'Menu("工作")' "$PET_MENU"
grep -qF 'Menu("查詢與輸入")' "$PET_MENU"
grep -qF 'Menu("工具")' "$PET_MENU"
grep -qF 'NSMenuItem(title: "工作"' "$STATUS_MENU"
grep -qF 'NSMenuItem(title: "工具"' "$STATUS_MENU"

# Trash cleanup was intentionally removed from RC1.1.3.1.
if grep -qF '清理垃圾桶' "$PET_MENU" || grep -qF '清理垃圾桶' "$STATUS_MENU"; then
  echo "ERROR: retired trash cleanup action must not appear in menus" >&2
  exit 1
fi
if [[ -e "$ROOT_DIR/Sources/DeskPet/Services/TrashService.swift" ]]; then
  echo "ERROR: retired TrashService.swift must not exist" >&2
  exit 1
fi

echo "DeskPet RC1.1.2 permission and compact-menu contracts passed"
