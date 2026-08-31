#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MODEL="Sources/DeskPet/Models/WaitingAIContextModels.swift"
ANALYZER="Sources/DeskPet/Services/GeminiWaitingContextAnalyzer.swift"
STORE="Sources/DeskPet/Stores/WaitingAIContextStore.swift"
VIEW="Sources/DeskPet/Views/TaskDigestAIContainerView.swift"
WINDOW="Sources/DeskPet/Window/TaskDigestWindowController.swift"

for file in "$MODEL" "$ANALYZER" "$STORE" "$VIEW" "$WINDOW"; do
  test -s "$file"
done

grep -q 'contextualRiskDelta' "$MODEL"
grep -q 'combinedRiskScore' "$MODEL"
grep -q 'WaitingBlockingImpact' "$MODEL"
grep -q 'GeminiWaitingContextAnalyzer' "$ANALYZER"
grep -q 'contextual_risk_delta' "$ANALYZER"
grep -q 'blocking_impact' "$ANALYZER"
grep -q '不得假設未提供' "$ANALYZER"
grep -q '不會自動修改任務' "$VIEW"
grep -q 'AI 結果僅供判斷輔助' "$VIEW"
grep -q 'WaitingAIContextStore' "$WINDOW"

# AI Context must remain advisory. It must not gain a direct GAS connector or mutation dependency.
if grep -qE 'GASTaskConnector|updateTask|createTask' "$ANALYZER" "$STORE"; then
  echo "ERROR: Waiting AI Context must not write GAS tasks directly"
  exit 1
fi

# Context adjustment is intentionally bounded so deterministic risk remains the auditable base layer.
grep -q 'min(25, max(-15, value))' "$ANALYZER"

echo "RC1.4 Waiting Intelligence + AI Context contract passed"
