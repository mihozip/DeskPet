#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

grep -q 'enum WaitingRiskLevel' Sources/DeskPet/Models/DailyWorkModels.swift
grep -q 'followUpDueCount' Sources/DeskPet/Models/DailyWorkModels.swift
grep -q 'followUpQueue' Sources/DeskPet/Models/DailyWorkModels.swift
grep -q 'recommendedFollowUpAt' Sources/DeskPet/Models/DailyWorkModels.swift
grep -q 'waitingRiskScore' Sources/DeskPet/Services/DailyWorkService.swift
grep -q 'eventIndicatesFollowUp' Sources/DeskPet/Services/DailyWorkService.swift
grep -q '等待案件需要介入' Sources/DeskPet/Services/WorkContextEngine.swift
grep -q '稍後提醒只暫停通知' Sources/DeskPet/Views/TaskDigestView.swift
grep -q '需追蹤' Sources/DeskPet/Views/TaskDigestView.swift
grep -q 'RC1.3 — Waiting Intelligence' docs/RC1_3_WAITING_INTELLIGENCE.md

echo "RC1.3 Waiting Intelligence contract: PASS"
