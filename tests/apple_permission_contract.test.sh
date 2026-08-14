#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTION="$ROOT_DIR/Sources/DeskPet/Services/CalendarActionService.swift"
QUERY="$ROOT_DIR/Sources/DeskPet/Services/CalendarQueryService.swift"
SETTINGS="$ROOT_DIR/Sources/DeskPet/Views/SettingsView.swift"
SIGNING="$ROOT_DIR/script/resolve_codesign_identity.sh"
BUILD_DEBUG="$ROOT_DIR/script/build_and_run.sh"
BUILD_RELEASE="$ROOT_DIR/script/build_release.sh"

# EventKit authorization must have one source of truth and must not spoof a
# granted UI state before authorizationStatus(for:) reports it.
grep -qF 'enum PermissionState: Equatable' "$ACTION"
grep -qF 'EKEventStore.authorizationStatus(for: .event)' "$ACTION"
grep -qF 'EKEventStore.authorizationStatus(for: .reminder)' "$ACTION"
grep -qF 'waitForSystemAuthorizationState' "$ACTION"
if grep -qF 'markGrantedImmediately' "$ACTION" || grep -qF 'reconcileAuthorizationStatus' "$ACTION"; then
  echo "ERROR: permission UI must not invent authorization state" >&2
  exit 1
fi

# Calendar queries are read-only consumers. They must never trigger a second
# permission request outside Settings.
if grep -qF 'requestFullAccessToEvents' "$QUERY" || grep -qF 'requestAccess(to:' "$QUERY"; then
  echo "ERROR: CalendarQueryService must not request EventKit permission" >&2
  exit 1
fi
grep -qF 'case .writeOnly:' "$QUERY"
grep -qF '請先到「設定 → 整合」授權行事曆完整存取' "$QUERY"

# Denied permissions must route the user to System Settings instead of calling
# the request API again and pretending that macOS will re-prompt.
grep -qF 'Button("開啟系統設定")' "$SETTINGS"
grep -qF 'Button("重新檢查權限")' "$SETTINGS"

# Local builds and source-based updates should reuse a stable signing identity
# whenever the Mac has one, with ad-hoc only as a fallback.
grep -qF 'Developer ID Application:' "$SIGNING"
grep -qF 'Apple Development:' "$SIGNING"
grep -qF "printf '%s\\n' '-'" "$SIGNING"
grep -qF 'resolve_codesign_identity.sh' "$BUILD_DEBUG"
grep -qF 'resolve_codesign_identity.sh' "$BUILD_RELEASE"

echo "DeskPet Apple permission and TCC signing contract: PASS"
