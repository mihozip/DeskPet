#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTION="$ROOT_DIR/Sources/DeskPet/Services/CalendarActionService.swift"
PET_MENU="$ROOT_DIR/Sources/DeskPet/Views/PetRootView.swift"
STATUS_MENU="$ROOT_DIR/Sources/DeskPet/App/StatusMenuController.swift"
TRASH="$ROOT_DIR/Sources/DeskPet/Services/TrashService.swift"
BUILD_DEBUG="$ROOT_DIR/script/build_and_run.sh"
BUILD_RELEASE="$ROOT_DIR/script/build_release.sh"

# Calendar and Reminders requests must be isolated at the service boundary.
grep -qF 'private let calendarStore = EKEventStore()' "$ACTION"
grep -qF 'private let remindersStore = EKEventStore()' "$ACTION"
grep -qF 'calendarStore.requestWriteOnlyAccessToEvents()' "$ACTION"
grep -qF 'remindersStore.requestFullAccessToReminders()' "$ACTION"
if grep -qF 'calendarStore.requestFullAccessToReminders' "$ACTION"; then
  echo "ERROR: Calendar store must not request Reminders access" >&2
  exit 1
fi
if grep -qF 'remindersStore.requestWriteOnlyAccessToEvents' "$ACTION"; then
  echo "ERROR: Reminders store must not request Calendar access" >&2
  exit 1
fi

# The pet menu must stay compact and group secondary actions.
grep -qF 'Menu("工作")' "$PET_MENU"
grep -qF 'Menu("查詢與輸入")' "$PET_MENU"
grep -qF 'Menu("工具")' "$PET_MENU"
grep -qF 'Button("清理垃圾桶…")' "$PET_MENU"
grep -qF 'NSMenuItem(title: "工作"' "$STATUS_MENU"
grep -qF 'NSMenuItem(title: "工具"' "$STATUS_MENU"

# Trash cleanup is destructive and must remain confirmation-gated, but it must
# not depend on Finder Apple Events/TCC in an ad-hoc RC build.
grep -qF 'alert.messageText = "清理垃圾桶？"' "$TRASH"
grep -qF 'guard alert.runModal() == .alertFirstButtonReturn else { return }' "$TRASH"
grep -qF 'homeDirectoryForCurrentUser.appendingPathComponent(".Trash"' "$TRASH"
grep -qF '.appendingPathComponent(".Trashes"' "$TRASH"
grep -qF 'try fileManager.removeItem(at: item)' "$TRASH"
if grep -qF 'NSAppleScript' "$TRASH"; then
  echo "ERROR: Trash cleanup must not depend on Finder Apple Events" >&2
  exit 1
fi
if grep -qF 'NSAppleEventsUsageDescription' "$BUILD_DEBUG" || grep -qF 'NSAppleEventsUsageDescription' "$BUILD_RELEASE"; then
  echo "ERROR: Obsolete Finder Automation usage description must be removed" >&2
  exit 1
fi

echo "DeskPet RC1.1.2 permission, menu and trash contracts passed"
