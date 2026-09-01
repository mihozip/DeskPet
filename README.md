# DeskPet

[![CI](https://github.com/mihozip/DeskPet/actions/workflows/ci.yml/badge.svg)](https://github.com/mihozip/DeskPet/actions/workflows/ci.yml)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-111111?logo=apple)](https://www.apple.com/macos/)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> **讓桌面上的每一個念頭，從捕捉一路走到完成。**

DeskPet（白帥帥）是一隻住在 macOS 桌面的工作代理人。它把快速記事、規則或 Gemini 理解、人工確認、Calendar／Reminders／GAS 任務、環境式監測、Waiting Intelligence，以及 Work Diary 串成一條可追蹤的工作流。

**目前主線版本：1.4.0.1 — RC1.4.0.1 / Waiting Intelligence + AI Context + Updater Hotfix**

已發佈的安裝包請見 GitHub Releases；`main` 代表目前通過 CI 的最新主線原始碼。

## 1.4.0.1：更新器改用正式 Release Asset

RC1.4.0.1 修正舊版內建更新器過度依賴本機 Swift／Xcode build 的問題。一般更新流程現在優先下載 GitHub Releases 已發佈的 `DeskPet-<version>.zip`，先完成版本、bundle identifier 與 codesign 驗證，再關閉舊版、備份、替換與重新啟動。

這個 hotfix 不改變 RC1.4 的 Waiting Intelligence、AI Context、人工確認邊界與 GAS task contract。

完整說明見 [`docs/RC1_4_0_1_UPDATER_HOTFIX.md`](docs/RC1_4_0_1_UPDATER_HOTFIX.md)。

## 1.4：Waiting Intelligence + AI Context

RC1.4 保留 RC1.3 的 deterministic Waiting Risk，再加入**使用者主動啟動**的 Gemini 情境分析。AI 不負責決定正式風險，而是補充規則層較難理解的阻塞、依賴與文字情境。

```text
GAS Task + WorkEvent
        ↓
Deterministic Waiting Risk
        ↓
Base Risk Score
        ↓
Optional Gemini AI Context
        ↓
Bounded Context Delta (-15...+25)
        ↓
Combined Recommendation
        ↓
Human decides / Human-confirmed action
```

每一筆 Waiting 可以個別進行 AI 情境分析，也可以一次分析目前最值得關注的三件案件。AI 會提供阻塞程度、依賴摘要、情境訊號、建議行動與信心，但不會自行修改任務、期限、狀態，也不會自動催辦。

完整說明見 [`docs/RC1_4_WAITING_AI_CONTEXT.md`](docs/RC1_4_WAITING_AI_CONTEXT.md)。

## 1.3：Waiting Intelligence

RC1.3 把原本的 Waiting Radar 從「等待清單」升級成**等待情報層**。DeskPet 不只知道哪些事情在等，而是進一步回答：

- **等多久？**：目前這一輪 Waiting 已經持續幾天。
- **在等誰？**：等待對象是否清楚。
- **何時再追？**：依等待起點、催辦紀錄與期限推算建議追蹤時間。
- **是否需介入？**：綜合等待天數、優先度、截止日、等待對象與催辦歷程判斷。

風險分為四級：

- `正常等待`
- `建議注意`
- `建議追蹤`
- `應立即介入`

一般 Waiting 不會搶占 `Now`；只有已經需要介入、而且沒有被 Snooze 暫停提醒的等待案件，才會重新回到目前焦點。Snooze 對 Waiting 的意義也改為「暫停提醒」，不是讓案件從 Radar 消失。

完整說明見 [`docs/RC1_3_WAITING_INTELLIGENCE.md`](docs/RC1_3_WAITING_INTELLIGENCE.md)。

## 1.2.1.1：任務寫入只送真正改動的欄位

RC1.2.1.1 修正任務確認畫面的寫入一致性。現在預覽沒有顯示變更的欄位，就不會被送到 GAS Gateway；例如只更新「最近進度」時，不會再順便重送原本未修改的 `nextAction`。

- `nil` 代表不更新該欄位。
- 空字串代表使用者明確要清除該欄位。
- 「最近進度」與「下一步行動」的清除操作都會在變更預覽中顯示。
- 完全沒有差異時，不呼叫 Gateway。
- 若使用者真的修改 `nextAction`，但部署中的 GAS Gateway 太舊而不支援，DeskPet 會明確提示需要更新並重新部署 Gateway。

這個 hotfix 不改變既有人工確認邊界，也不改動 Dashboard schema。

## 1.2.1：白帥帥開始主動提醒工作情境

RC1.2.1 把 1.2 已有的 `Now / Next / Later` 判斷接到桌面白帥帥。使用者不必先打開「今日工作」才能知道目前焦點；在有意義的時機，白帥帥會以低干擾泡泡顯示一則情境建議。

預設會在以下情況提示：

- 每天第一次出現有意義的工作情境。
- 10–60 分鐘內有即將到來的非全天行程，而且今天尚未提示過該行程。
- 完成任務後，`Now` 的焦點發生改變。
- 其他焦點改變需通過 30 分鐘冷卻時間，避免反覆打擾。

點一下「白帥帥建議」泡泡可直接打開完整 `Now / Next / Later`。Context Briefing 不要求 GAS 一定已串接；只有 Inbox 與本機 Calendar 也能產生情境。右鍵選單與 macOS 選單列的「今日工作」也因此改為永遠可用。

完整說明見 [`docs/RC1_2_1_CONTEXT_BRIEFING.md`](docs/RC1_2_1_CONTEXT_BRIEFING.md)。

## 1.2：從「任務清單」走向「工作情境」

RC1.2 新增 `WorkContextEngine`，不建立第二套任務資料庫，而是即時整合既有資訊，回答三個問題：

- **現在（Now）**：目前最值得注意的是什麼？
- **接著（Next）**：做完現在的事情後，下一步是什麼？
- **稍後（Later）**：哪些事情要保持可見，但不該打斷現在？

```text
GAS Tasks ───────┐
Inbox ───────────┤
WorkEvents ──────┤
Snooze ──────────┼─> WorkContextEngine ─> Now / Next / Later
Local Calendar ──┘
```

情境摘要採 deterministic 規則產生，不依賴 Gemini。Calendar 內容只在本機 EventKit 讀取，不會送往 Gemini；Calendar 無權限或讀取失敗時，也會退回以 GAS、Inbox、WorkEvents 與 Snooze 產生工作情境。

等待中的工作即使是高優先，也不會搶占「現在」；全天行程也不會整天蓋過真正的工作焦點。完整設計見 [`docs/RC1_2_WORK_CONTEXT.md`](docs/RC1_2_WORK_CONTEXT.md)。

## 核心工作流

```text
Capture / Query
      ↓
Inbox / Calendar Intelligence
      ↓
Understand (local rules / optional Gemini)
      ↓
Work Context (Now / Next / Later)
      ↓
Waiting Intelligence
(Risk / Follow-up / Intervention / optional AI Context)
      ↓
Context Briefing (low-noise desktop nudge)
      ↓
Confirm writes / Display read-only results
      ↓
Calendar / Reminders / GAS Task
      ↓
Monitor
      ↓
Work Diary
```

## 主要功能

- 桌面白帥帥：可拖曳、調整大小與動畫強度；一般 App 視窗可以自然蓋住桌寵。
- Context Briefing：在每日首次情境、近期行程、完成工作後焦點改變等關鍵時機主動提示。
- macOS 選單列腳印入口：桌寵互動異常時仍可操作主要功能。
- 全域快捷鍵快速記事：原始內容保存在本機 Inbox。
- Smart Inbox：先用本機規則解析，可選擇使用 Gemini API 協助理解。
- Calendar Intelligence：以自然語句查詢 macOS Calendar，可依年度、月份、地點、關鍵字、講師／研習／會議類型整理。
- Work Context：整合 GAS、Inbox、WorkEvents、Snooze 與本機 Calendar，產生 Now / Next / Later。
- Today Brief：依確定性規則整理逾期、今日、高優先、等待與 Inbox。
- Waiting Radar / Waiting Intelligence：掌握等待天數、等待對象、催辦歷程、建議追蹤時間、風險等級與是否需要介入。
- Follow-up Queue：今日工作顯示需要追蹤的等待案件，可進入既有人工確認的催辦流程。
- Waiting AI Context：可選擇讓 Gemini 分析阻塞、依賴與情境訊號；結果只作 advisory，不會直接寫回 GAS。
- Next Action：將最近進度與既有「下一步行動」帶入人工確認流程。
- Daily Wrap / Weekly Review：由原始 `WorkEvent` 重建每日收工與週回顧；Weekly Review 也會納入 Waiting analytics。
- Work Diary：以 append-style `WorkEvent` 保存實際工作歷程。
- Google Apps Script Gateway：建立、讀取、更新校務工作任務。
- Ambient Agent：串接 GAS 後，可定期讀取進行中、逾期、高優先與等待任務。
- Natural Action / Voice Action：用自然語句或語音提出任務變更草案，再由使用者確認。
- Inbox → Task Link：保留原始 Inbox 與正式 GAS Task 的關聯。
- Duplicate Guard：建立 GAS Task 前提示可能重複的工作，不自動刪除或合併。
- Pet Work State / Snooze：桌寵狀態只提供視覺回饋；Waiting 的 Snooze 是暫停提醒，不會讓案件從 Radar 消失。
- 軟體更新：每 7 天最多進行一次真正的網路檢查；1.4.0.1 起一般更新優先使用已發佈並驗證的 Release Asset。

## Waiting Radar：把「等待」變成可以管理的工作流

行政工作最容易被忽略的，不一定是「還沒做」，而是：

> **我已經完成自己的部分，但整件事情還在等別人。**

例如公文等回覆、採購等廠商報價、報修等排程、資料等補件。這些工作並不是 Done，而是進入 Waiting。

DeskPet 的 Waiting Radar / Waiting Intelligence 不把 Waiting 當成靜態標籤，而是把它視為一段需要持續觀察的工作週期。

### 四個核心問題

| 問題 | DeskPet 如何處理 |
| --- | --- |
| **等多久？** | 計算目前 Waiting 的等待時間，並納入 Risk Score |
| **在等誰？** | 讀取 `waitingFor`；缺少等待對象本身也是風險訊號 |
| **何時再追？** | 依等待起點、最近催辦、催辦次數與截止日推算 `recommendedFollowUpAt` |
| **是否需介入？** | 綜合等待天數、優先度、期限、等待對象與追蹤歷程，產生 deterministic risk |

### Waiting Risk

Waiting Intelligence 的基礎判斷不依賴 Gemini，因此即使完全沒有 AI Key，也能正常運作。

風險分成：

1. **正常等待**：仍在合理等待範圍。
2. **建議注意**：開始需要提高可見度。
3. **建議追蹤**：已到適合主動確認進度的時間。
4. **應立即介入**：等待已可能影響期限或後續工作，需要重新取得控制權。

Risk Score 是**注意力排序訊號**，不是自動化命令。DeskPet 不會因為分數提高就自行修改任務、截止日或狀態。

### Follow-up Queue 與「催辦」

「今日工作」會整理需要追蹤的 Waiting。使用者可以從 Waiting 案件進入既有的「記錄已催辦」流程。

催辦行為仍遵守 DeskPet 一貫的人工確認邊界：

```text
Waiting detected
      ↓
DeskPet suggests follow-up
      ↓
Open confirmation
      ↓
Human reviews
      ↓
Confirmed write
```

催辦歷程由既有 `WorkEvent` 重建，不另建第二套正式任務資料庫。

### Waiting → Now

正常 Waiting 仍留在 `Later`，避免「正在等別人」的事情一直佔據注意力。

但當 Waiting Intelligence 判定案件已經**需要介入**時，它可以重新回到 `Now`，Context Briefing 也能提醒：

```text
等待案件需要介入：電梯工程修正報價（已等 8 天）
```

因此 DeskPet 管的不只是「今天要做什麼」，也開始看見：

**哪些事情你早就做過了，但整個流程還沒有真正閉合。**

### Snooze 不等於消失

對 Waiting 使用 Snooze，只代表「暫時不要主動提醒我」。

- 案件仍保留在 Waiting Radar；
- Risk Score 繼續計算；
- Snooze 到期前不進 Follow-up Queue；
- Snooze 到期前不因 Waiting Intelligence 搶占 `Now`。

這避免「暫時不想被提醒」變成「系統忘記這件事」。

### Optional AI Context

RC1.4 在 deterministic risk 之外，再提供可選的 Gemini 情境層。只有使用者主動按下分析時才會呼叫 AI，不會在背景自動分析所有 Waiting。

AI 可以補充：

- 這件 Waiting 是否阻塞其他工作；
- 後續是否存在可由資料支持的依賴關係；
- 哪些文字訊號值得提高或降低注意；
- 下一步可以採取什麼行動。

AI 的 `contextualRiskDelta` 會被限制在 `-15...+25`，而且**不會覆寫 deterministic risk，也沒有權限直接寫入 GAS**。最後仍由人決定是否追蹤、更新或介入。

### 與「總務主任每日任務系統」的關係

DeskPet 與 [`school-admin-daily-dashboard`](https://github.com/mihozip/school-admin-daily-dashboard) 共用同一套核心 GAS Task 資料契約，但兩邊對 Waiting 各自負責不同層次：

```text
school-admin-daily-dashboard
        │
        ├─ 正式任務 / waitingFor / status / progress
        ├─ Dashboard Waiting Radar
        │  └─ 等待追蹤、下次追蹤、追蹤次數
        │
        └──── DeskPet Gateway ────> 白帥帥 DeskPet
                                  ├─ Waiting Risk
                                  ├─ Follow-up history from WorkEvent
                                  ├─ Waiting → Now
                                  ├─ Weekly Waiting analytics
                                  └─ optional AI Context
```

Dashboard 是正式校務工作管理介面；DeskPet 則把 Waiting 帶進個人的桌面工作情境與注意力排序。

兩邊共同的目標都是：

> **不要只記得「我做了什麼」，還要知道「事情現在卡在哪裡、誰還沒回、什麼時候該再追」。**

## 安全與隱私邊界

DeskPet 對「讀取、建議、寫入」保持明確分層：

- Calendar Intelligence、Work Context 與 Context Briefing 都是唯讀能力。
- deterministic Waiting Risk 是 derived domain，不直接修改 GAS Task。
- Waiting AI Context 只有使用者主動要求時才會呼叫 Gemini；AI assessment 目前只存在本次 App 執行期間的記憶體。
- AI Context service/store 不持有 `GASTaskConnector`，不能直接寫正式任務。
- Calendar 事件內容不送 Gemini；Waiting AI Context 也不傳送本機 Calendar 內容。
- Context Briefing 只把最後提示日期、時間、焦點 signature 與已提示行程 ID 存在本機 `UserDefaults`，不新增工作資料庫。
- Calendar / Reminders / GAS 的正式寫入都必須經過人工確認。
- Gemini API Key 只存放在 macOS Keychain。
- GAS token 只存放在 Keychain；非秘密整合 metadata 才進 `UserDefaults`。
- Work Context / Waiting Intelligence 不新增第二套持久化正式任務資料庫。

完整說明見 [`PRIVACY.md`](PRIVACY.md)、[`SECURITY.md`](SECURITY.md) 與 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)。

## Calendar / Reminders 權限

Calendar 與 Reminders 採分離授權。設定頁是唯一的權限入口，狀態只依 macOS EventKit `authorizationStatus` 實際結果判斷。

DeskPet 支援查詢既有 Calendar 行程，因此 macOS 14+ 需要 Calendar 完整事件存取；Reminders 仍由獨立按鈕要求完整存取。若 Google Calendar 已經加入 macOS「行事曆」，DeskPet 才能透過 EventKit 讀取。

完整設計見 [`docs/RC1_1_CALENDAR_INTELLIGENCE.md`](docs/RC1_1_CALENDAR_INTELLIGENCE.md)。

## Gemini

DeskPet 不內建 API Key。使用者需在「設定 → AI」自行輸入，秘密值只寫入 macOS Keychain。

目前模型選單：

- `gemini-3.6-flash` — 預設／建議
- `gemini-3.5-flash`
- `gemini-3.5-flash-lite`

Gemini 2.x 已移除。2026-08-18 再次核對 Google 第一方 Gemini API 文件後，仍沒有可驗證的 Gemini 3.7 Flash API model ID，因此 DeskPet 不猜測 `gemini-3.7-flash`。完整政策見 [`docs/GEMINI_MODELS.md`](docs/GEMINI_MODELS.md)。

## 系統需求

- macOS 13 或更新版本
- Swift 5.9+ / Apple Command Line Tools 或 Xcode
- Gemini 為選用整合，需要自行提供 Gemini API Key
- GAS 為選用整合；推薦使用 `school-admin-daily-dashboard` 內建的 `DeskPetGateway.gs` 建立 DeskPet API deployment，`GAS/DeskPet_GAS_API_Gateway_v3.js` 保留作為獨立 Gateway 備援

## 快速開始

```bash
git clone https://github.com/mihozip/DeskPet.git
cd DeskPet
./script/build_and_run.sh
```

本機安裝：

```bash
./script/install_local.sh
```

預設安裝到：

```text
~/Applications/DeskPet.app
```

更新器、簽章、rollback 與舊版 bootstrap 指令見 [`docs/UPDATING.md`](docs/UPDATING.md)。

> GitHub-hosted RC binary 若仍採 ad-hoc 簽章，跨版本 TCC 權限延續無法完全保證。公開發佈要穩定延續 Calendar／Reminders 權限，仍應配置 Developer ID Application 簽署與 notarization。

## GAS / Dashboard 整合

Gateway 是 `mihozip/school-admin-daily-dashboard` 的非破壞性 companion API。新版推薦把 `DeskPetGateway.gs` 與 Dashboard 放在同一個 Apps Script 專案，再建立第二個專供 DeskPet 直接 POST 的 Web App deployment；管理台 deployment 仍維持 Workspace／網域限制。

因此 DeskPet 不再需要手動複製 `DESKPET_SPREADSHEET_ID`。設定時只需填入 **DeskPet API deployment 的 `/exec` URL** 與 `DESKPET_API_TOKEN`。舊版獨立 Gateway 仍可在 Workspace 政策受限時使用。

- Gateway 設定：[`docs/GAS_GATEWAY_SETUP.md`](docs/GAS_GATEWAY_SETUP.md)
- Dashboard 整合：[`docs/GAS_PROJECT_INTEGRATION.md`](docs/GAS_PROJECT_INTEGRATION.md)

行政職稱解析順序為：本機覆寫 → Dashboard `ROLE_NAME` → `總務` fallback。這個職稱會套用到工作台、摘要、提醒、任務操作與 DeskPet 新建任務 owner，但不會修改 Dashboard profile key。

## 架構與測試

核心責任分層：

- Models：值型別與 identifier
- Stores：本機 persistence 與 observable state
- Services：domain logic、外部系統與平台 API
- Views：SwiftUI presentation
- Window controllers：AppKit 視窗生命週期

CI 會驗證 public repository contract、GAS Gateway、Apple 權限、Gemini model/response parser、Waiting Intelligence / Waiting AI Context contracts、Swift unit tests，以及完整 `.app` build/resource。

## 文件索引

- [`docs/RC1_4_0_1_UPDATER_HOTFIX.md`](docs/RC1_4_0_1_UPDATER_HOTFIX.md) — RC1.4.0.1 Release Asset Updater Hotfix
- [`docs/RC1_4_WAITING_AI_CONTEXT.md`](docs/RC1_4_WAITING_AI_CONTEXT.md) — RC1.4 Waiting Intelligence + AI Context
- [`docs/RC1_3_WAITING_INTELLIGENCE.md`](docs/RC1_3_WAITING_INTELLIGENCE.md) — RC1.3 Waiting Intelligence
- [`docs/RC1_2_1_CONTEXT_BRIEFING.md`](docs/RC1_2_1_CONTEXT_BRIEFING.md) — RC1.2.1 Context Briefing
- [`docs/RC1_2_WORK_CONTEXT.md`](docs/RC1_2_WORK_CONTEXT.md) — RC1.2 Work Context
- [`docs/RC1_DAILY_WORK_LOOP.md`](docs/RC1_DAILY_WORK_LOOP.md) — Daily Work Loop
- [`docs/RC1_1_CALENDAR_INTELLIGENCE.md`](docs/RC1_1_CALENDAR_INTELLIGENCE.md) — Calendar Intelligence
- [`docs/GEMINI_MODELS.md`](docs/GEMINI_MODELS.md) — Gemini model policy
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — Architecture
- [`CHANGELOG.md`](CHANGELOG.md) — Version history
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — Contribution guide

## License

Source code and maintainer-approved default artwork are distributed under the [MIT License](LICENSE). Asset provenance is documented in [`ASSETS.md`](ASSETS.md).