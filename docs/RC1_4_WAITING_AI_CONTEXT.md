# DeskPet RC1.4 — Waiting Intelligence + AI Context

Release Candidate version: `1.4.0.0`.

RC1.4 保留 RC1.3 的 deterministic Waiting Risk，新增一層可選用的 Gemini 情境分析。目標不是把行政風險交給模型決定，而是讓 AI 補足規則層難以理解的流程依賴、阻塞關係與文字情境。

## 雙層判斷

```text
GAS Task + WorkEvent
        ↓
Deterministic Waiting Risk
(Age / Priority / Deadline / Follow-up)
        ↓
Base Risk Score
        ↓
Optional Gemini AI Context
(Blocking / Dependency / Semantic signals)
        ↓
Bounded Context Delta (-15...+25)
        ↓
Combined Recommendation
        ↓
Human decides / Human-confirmed action
```

第一層規則風險仍是正式、可重現的基礎。Gemini 不會覆寫 `riskScore`、`riskLevel`、`interventionRequired`、任務狀態或截止日。

## AI Context Assessment

每一筆等待案件可以個別啟動「AI 情境分析」，也可以一次分析目前最值得關注的三件案件。

Gemini 會回傳：

- `contextualRiskDelta`：介於 `-15` 到 `+25` 的情境加權；
- `blockingImpact`：低／中／高阻塞；
- `dependencySummary`：可由現有工作資料支持的後續依賴摘要；
- `riskSignals`：最多四個可由輸入直接支持的情境訊號；
- `rationale`：為什麼 AI 認為情境值得提高或降低注意；
- `recommendedAction`：給人的下一步建議；
- `confidence`：AI 對本次情境判斷的信心。

AI 加權會被程式再次 clamp 到 `-15...+25`，即使模型輸出越界也不會直接放大風險。

## Combined Recommendation

RC1.4 顯示兩個層次，不混在一起：

- **規則風險**：RC1.3 的 deterministic score；
- **綜合建議**：規則風險 + AI 情境加權。

例如：

```text
規則風險：58/100 · 建議追蹤
AI 情境：+18 · 高阻塞
綜合建議：76/100 · 應立即介入
```

這個綜合建議仍然是 advisory。它不會自動把案件寫回 GAS，也不會自動寄信、催辦或改期限。

## Blocking / Dependency

AI Context 會把目前案件與最多 12 筆其他工作摘要一起分析，用來尋找文字上可確認的流程依賴。例如：

```text
等待廠商修正估價
       ↓
收到估價後簽辦
       ↓
招標公告
```

若輸入資料不足，prompt 明確要求 Gemini 回覆「未發現可確認的後續依賴」，而不是自行補出不存在的行政流程。

## UI

「今日工作」視窗新增 `AI 等待情境` 工具列入口。

AI Context 畫面會：

- 保留每筆案件原本的規則風險；
- 顯示 AI 情境加權與阻塞程度；
- 顯示綜合建議與 AI 信心；
- 顯示依賴摘要、情境訊號與建議行動；
- 綜合建議達到追蹤門檻時，可進入既有「開啟催辦確認」流程。

最後一項仍只是開啟既有人工確認 UI，不會跳過確認直接寫入。

## AI 呼叫策略

RC1.4 不會在背景對所有 Waiting 自動呼叫 Gemini。

AI Context 只在使用者：

1. 對單一案件按下「AI 情境分析」；或
2. 按下「分析最值得關注的 3 件」

時才呼叫 Gemini。

這樣可以避免不必要的 API 成本與背景資料傳送，同時讓 deterministic Waiting Intelligence 即使沒有 AI 仍完整可用。

## Privacy

當使用 AI Context 時，DeskPet 會把：

- 目前等待案件的任務名稱、類別、狀態、優先度、截止日、等待對象、等待天數、催辦次數、下一步與最近進度；
- 最多 12 筆其他目前工作的名稱、類別、狀態、截止日與下一步

傳送至使用者設定的 Gemini API。

AI Context 不會傳送本機 Calendar 內容；Calendar 的既有隱私邊界不變。

AI Context 結果目前只保存在本次 App 執行期間的記憶體，不寫入 GAS、WorkEvent、UserDefaults 或新的持久化資料庫。任務內容更新後，舊 assessment 的 fingerprint 會失效，介面不再把它當成目前有效結果。

## Safety / Architecture

RC1.4 保留既有安全邊界：

- GAS Task 仍是正式任務 source of truth；
- WorkEvent 仍是 append-style 工作歷程；
- RC1.3 deterministic Waiting Risk 仍是可稽核基礎；
- Gemini 只提供 advisory context；
- AI Context service/store 不持有 `GASTaskConnector`，不能直接寫入正式任務；
- Calendar / Reminders / GAS 正式寫入仍須人工確認；
- Gemini API Key 仍只放在 macOS Keychain。

## Validation

RC1.4 增加：

- AI context delta 上下界測試；
- deterministic risk threshold 與 combined recommendation 測試；
- task fingerprint stale detection 測試；
- RC1.4 contract，禁止 AI Context service/store 直接依賴 GAS mutation；
- 既有 RC1.3 Waiting Intelligence、Gemini model、task mutation、permission、desktop interaction contracts 全部持續驗證。
