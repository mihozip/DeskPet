# DeskPet RC1.3 — Waiting Intelligence

Release Candidate version: `1.3.0.0`.

RC1.3 把既有 Waiting Radar 從「等待清單」升級為「等待情報層」。DeskPet 不只顯示工作正在等誰、等多久，也會根據可驗證的工作資料判斷哪些等待開始需要介入。

## 核心變化

```text
Waiting
   ↓
Age / Follow-up History / Deadline / Priority
   ↓
Risk Score
   ↓
Need Intervention?
   ├─ No  → Keep Watching
   └─ Yes → Return to Now / Context Briefing
                    ↓
                 Follow Up
                    ↓
                 Continue
```

## Waiting Risk

Waiting Intelligence 採 deterministic 規則，不需要 Gemini 才能運作。風險分數綜合：

- 等待天數；
- 任務優先度；
- 截止日距離或是否已逾期；
- 等待對象是否缺漏；
- 建議追蹤時間是否已到；
- 本輪等待是否已有催辦紀錄。

風險分成四級：

- `正常等待`
- `建議注意`
- `建議追蹤`
- `應立即介入`

Risk Score 是注意力排序訊號，不會自行修改 GAS 任務、截止日或狀態。

## Follow-up Queue

「今日工作」新增 `需追蹤` 統計與最多三件今日建議追蹤項目。需要介入的 Waiting 可以直接開啟既有「記錄已催辦」人工確認流程。

催辦歷程仍以 `WorkEvent` 重建：

- `followUpCount`：目前這輪 Waiting 已催辦次數；
- `lastFollowUpAt`：最近一次催辦時間；
- `recommendedFollowUpAt`：依等待起點、最近催辦與截止日推算的建議追蹤時間。

不新增第二套持久化任務資料庫。

## Waiting → Now

RC1.2 原本刻意讓 Waiting 工作不搶占 `Now`。RC1.3 保留這個原則，但增加一個例外：

> 只有「已經需要介入」且沒有被暫停提醒的 Waiting，才會重新回到 `Now`。

因此 Context Briefing 可以出現：

```text
等待案件需要介入：電梯工程修正報價（已等 8 天）
```

一般正常等待仍維持在 `Later`。

## Snooze 語意修正

RC1.3 把 Snooze 對 Waiting 的意義改成「暫停提醒」，而不是「從雷達消失」。

- Waiting Radar 仍看得到該案件；
- Risk Score 仍持續計算；
- Snooze 到期前不進 Follow-up Queue；
- Snooze 到期前不因 Waiting Intelligence 主動搶占 `Now`。

一般非 Waiting 任務的 Snooze 行為維持不變。

## Waiting Analytics

Weekly Review 新增：

- 目前 Waiting 平均等待天數；
- 高風險 Waiting 數量；
- 目前 Waiting 的催辦累計；
- 等待過久清單附帶風險等級。

這些統計由現有 GAS Task 與 WorkEvent 即時重建，不另外保存 AI 摘要。

## Safety / Architecture

RC1.3 不改變既有安全邊界：

- GAS Task 仍是正式任務 source of truth；
- `WorkEvent` 仍是 append-style 工作歷程；
- Waiting Intelligence 是 derived domain，不新增 Dashboard schema；
- 所有 GAS 寫入仍必須經過人工確認；
- Gemini 不參與 Risk Score 或 Waiting 事實判定；
- Snooze 仍只存在本機 `UserDefaults`。

## Validation

RC1.3 增加測試覆蓋：

- Waiting Risk 與 deadline-sensitive escalation；
- Follow-up history 與 recommended follow-up cadence；
- Snooze 保留 Radar 可見性但抑制主動提醒；
- Intervention-required Waiting 回到 `Now`；
- Snoozed Waiting 留在 `Later` 且不打斷 Context Briefing；
- Weekly Waiting analytics。
