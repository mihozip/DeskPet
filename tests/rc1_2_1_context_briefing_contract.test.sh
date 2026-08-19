#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE="$ROOT_DIR/Sources/DeskPet/Services/WorkContextBriefingService.swift"
BUBBLE="$ROOT_DIR/Sources/DeskPet/Views/ContextBriefingBubbleView.swift"
PET_ROOT="$ROOT_DIR/Sources/DeskPet/Views/PetRootView.swift"
STATUS_MENU="$ROOT_DIR/Sources/DeskPet/App/StatusMenuController.swift"
APP_DELEGATE="$ROOT_DIR/Sources/DeskPet/App/AppDelegate.swift"
DOC="$ROOT_DIR/docs/RC1_2_1_CONTEXT_BRIEFING.md"

for file in "$SERVICE" "$BUBBLE" "$PET_ROOT" "$STATUS_MENU" "$APP_DELEGATE" "$DOC"; do
  test -s "$file"
done

grep -qF 'withTimeInterval: 15 * 60' "$SERVICE"
grep -qF 'let cooldown: TimeInterval = completedSinceLastBriefing ? 0 : 30 * 60' "$SERVICE"
grep -qF 'upcoming.startDate.timeIntervalSince(now) <= 60 * 60' "$SERVICE"
grep -qF 'upcoming.startDate.timeIntervalSince(now) >= 10 * 60' "$SERVICE"
grep -qF '$0.kind == .taskCompleted' "$SERVICE"
grep -qF 'lastUpcomingEventID' "$SERVICE"
grep -qF 'ContextBriefingBubbleView(' "$PET_ROOT"
grep -qF 'Button("今日工作") { onOpenTaskDigest() }' "$PET_ROOT"
grep -qF 'workMenu.addItem(makeItem(title: "今日工作", action: #selector(openTaskDigest)))' "$STATUS_MENU"
grep -qF 'contextBriefing.start()' "$APP_DELEGATE"
grep -qF 'contextBriefing.stop()' "$APP_DELEGATE"
grep -qF 'onOpenTodayWork()' "$BUBBLE"

if grep -qF 'guard gasConfiguration.isLinked else { return }' "$STATUS_MENU"; then
  echo "ERROR: read-only Today Work must remain available without GAS" >&2
  exit 1
fi

echo "DeskPet RC1.2.1 Context Briefing contract tests passed"
