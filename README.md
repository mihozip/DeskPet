# DeskPet

[![CI](https://github.com/mihozip/DeskPet/actions/workflows/ci.yml/badge.svg)](https://github.com/mihozip/DeskPet/actions/workflows/ci.yml)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-111111?logo=apple)](https://www.apple.com/macos/)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> **讓桌面上的每一個念頭，從捕捉一路走到完成。**

DeskPet 是一隻住在 macOS 桌面的工作代理人。它把快速記事、規則或 Gemini 理解、人工確認、Calendar／Reminders／GAS 任務執行，以及每日工作日誌串成同一條可追蹤的工作流。

**目前版本：1.1.3.1 — RC1.1.3.1 / Trash Cleanup Fix**

最新 RC：[`v1.1.3.1`](https://github.com/mihozip/DeskPet/releases/tag/v1.1.3.1)

DeskPet 是以 Swift / SwiftUI / AppKit 開發的 macOS 桌面工具。它不是要取代既有的任務系統，而是提供一個隨手可用的桌面入口，把零散資訊轉成可追蹤的工作，也能在使用者主動查詢時把既有行事曆整理成可讀的工作情境。

```text
Capture / Query
  ↓
Inbox / Calendar Intelligence
  ↓
Understand (local rules / optional Gemini)
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

- 桌面 DeskPet 可拖曳、調整大小與動畫強度；桌寵使用一般視窗層級，Word、瀏覽器、Finder 等一般工作視窗可以自然蓋住白帥帥，不會永遠置頂擋住工作。
- 提供 macOS 選單列腳印入口作為操作備援。
- 全域快捷鍵快速記事，內容保存於本機 Inbox。
- Smart Inbox：本機規則解析，亦可選擇啟用 Gemini API。
- Calendar Intelligence：用自然語句查詢 macOS 行事曆，可依年度、月份、地點、關鍵字，以及講師／研習／會議類型整理結果。
- Calendar Intelligence 的事件內容只在本機解析與篩選，不會將行事曆事件送往 Gemini。
- Apple Calendar / Reminders 權限分離，按哪一個就只要求哪一個；所有寫入前仍必須人工確認。
- 行事曆完整讀取權限只在使用者主動使用 Calendar Intelligence 時要求。
- Google Apps Script Gateway：建立、讀取、更新校務工作任務。
- 校務任務系統為選用整合；未完成串接時，GAS 任務摘要、同步、自然語句任務操作與語音任務操作等相關選單不會出現在桌寵主選單，只保留「設定」中的串接入口。
- Ambient Agent：完成 GAS 串接後，可定期讀取進行中、逾期、高優先與等待任務。
- Natural Action / Voice Action：完成 GAS 串接後，可用自然語句或語音提出任務變更草案，再由使用者確認。
- Inbox → Task Link：保留原始 Inbox 與正式 GAS Task 的關聯。
- Duplicate Guard：建立 GAS Task 前提示可能重複的工作，不自動刪除或合併。
- Work Diary：以 `WorkEvent` 保存每天實際發生的工作事件，可供後續匯出與分析。
- Today Brief：不依賴 Gemini，以確定性規則整理逾期、今日、高優先、等待與 Inbox 工作。
- Next Action：把最近進度與 Dashboard 既有「下一步行動」欄位一起帶入人工確認流程。
- Waiting Radar：以等待對象／狀態與更新時間 heuristic 顯示等待工作，不改寫截止日。
- Daily Wrap / Weekly Review：完全由原始 `WorkEvent` 重建每日收工與週回顧。
- Pet Work State / Snooze：工作狀態只提供視覺回饋；稍後提醒只保存本機狀態。
- 每 7 天自動檢查更新；只有偵測到較新版本時才跳出更新提示，可選「立即更新」或「稍後」。
- 「清理垃圾桶…」會在人工確認後直接清除目前使用者的 `~/.Trash` 與可存取掛載磁碟 `.Trashes/<UID>` 內容，不再依賴 Finder Automation / Apple Events。

### 桌面互動與選單列備援

RC1.1.1 修正部分新版 macOS／Apple Silicon 機型上「白帥帥有顯示，但像一張無法點擊的浮動 PNG」的互動問題。桌寵視窗會明確接收第一下滑鼠事件，快速記事快捷鍵也綁定 application event target。

RC1.1.2 起，右鍵選單改為分層結構，將高頻操作留在第一層，次要功能收進「工作」、「查詢與輸入」與「工具」子選單，避免選單過長。

RC1.1.3 起，白帥帥不再使用永遠置頂的 floating window level。一般 App 視窗可以正常蓋住桌寵；需要快速記事等操作時，DeskPet 仍可主動帶到前景。

若桌寵本體遇到互動異常，仍可從 macOS 選單列的腳印圖示進入主要功能。完整互動修補說明見：[`docs/RC1_1_1_DESKTOP_INTERACTION.md`](docs/RC1_1_1_DESKTOP_INTERACTION.md)。

### 行事曆智慧查詢

在白帥帥上按右鍵，選擇「查詢與輸入 → 查詢行事曆…」，例如輸入：

```text
告訴我今年所有研習講師的行程
下個月有哪些研習
九月在台中的研習
今年 AI 行程
```

未指定日期範圍時，Calendar Intelligence 預設查詢當年度。講師行程以 `講師`、`主講`、`授課`、`演講` 等明確角色訊號判斷，並排除 `參加`、`報名`、`學員`、`受訓` 等參與者訊號。若希望辨識更穩定，建議在行程標題使用 `[講師]`，或在備註標示 `角色：講師`。

Google Calendar 必須先在 macOS「行事曆」中可見，DeskPet 才能透過 EventKit 讀取。

完整設計與隱私邊界見：[`docs/RC1_1_CALENDAR_INTELLIGENCE.md`](docs/RC1_1_CALENDAR_INTELLIGENCE.md)

### 清理垃圾桶

從「工具 → 清理垃圾桶…」執行。DeskPet 一定會先顯示不可逆刪除確認，只有使用者確認後才開始清理。

RC1.1.3.1 已移除 Finder AppleScript / Automation 相依，改由 `FileManager` 直接處理目前使用者可存取的垃圾桶位置：

```text
~/.Trash
/Volumes/<Volume>/.Trashes/<UID>
```

DeskPet 只刪除辨識為目前使用者垃圾桶目錄底下的項目，不接受任意路徑，也不會自動執行。完成後會明確回報「垃圾桶原本就是空的」、「已刪除幾個項目」、「部分項目失敗」或完整失敗原因。

## 系統需求

- macOS 13 或更新版本
- Swift 5.9+ / Apple Command Line Tools 或 Xcode
- Gemini 功能為選用，需要使用者自行提供 Gemini API Key
- GAS 整合為選用，需要自行部署 `GAS/DeskPet_GAS_API_Gateway_v3.js`

## 快速開始

```bash
git clone https://github.com/mihozip/DeskPet.git
cd DeskPet
./script/build_and_run.sh
```

開發腳本會建立 `dist/DeskPet.app` 並啟動。若公開原始碼未包含自訂桌寵 PNG，DeskPet 會使用中性 fallback UI；詳見 `Sources/DeskPet/Resources/README.md`。

### 本機安裝

```bash
./script/install_local.sh
```

會安裝到：

```text
~/Applications/DeskPet.app
```

## 軟體更新

DeskPet 會保存上次自動檢查時間，**每 7 天最多進行一次真正的網路更新檢查**。App 內可以用較短週期做本機到期判斷，但不會因此反覆連線 GitHub。

如果沒有新版，DeskPet 不會主動打擾；只有偵測到較新版本時才會跳出「白帥帥有新版本」提示，可選：

- `立即更新`：進入既有更新流程。
- `稍後`：本次不安裝，下一次網路檢查仍受 7 天週期限制，不會每小時重複跳窗。

也可以在「設定 → 一般 → 軟體更新」手動檢查並安裝更新。更新畫面會顯示目前階段與百分比；下載、建置與驗證期間 App 保持開啟，到「準備替換 App」時才正常關閉舊 DeskPet。更新器會確認舊 PID 已退出後再替換 App，最後只啟動一個新版實例。新 App 驗證成功後才會替換舊 App；失敗時會保留或恢復原版本。

已安裝 0.9.1.x 等舊版、App 內尚無更新按鈕時，可在 Terminal 執行：

```bash
curl --fail --location --show-error \
  https://raw.githubusercontent.com/mihozip/DeskPet/main/script/install_or_update.sh \
  --output /tmp/DeskPetUpdater.sh
bash /tmp/DeskPetUpdater.sh
```

更新不會刪除 `Application Support/DeskPet`、`UserDefaults` 或 Keychain 憑證。需要 Xcode 或 Apple Command Line Tools；執行紀錄位於 `~/Library/Logs/DeskPet/update.log`。

目前 GitHub Release 的 RC ZIP 使用 ad-hoc 簽章，適合測試；尚未使用 Apple Developer ID 簽署或 notarize。

### Bundle ID

預設保留目前專案識別碼以維持既有安裝相容性；fork 或自行發佈時可覆寫：

```bash
BUNDLE_ID="io.github.yourname.DeskPet" ./script/build_release.sh
```

Keychain service 會跟隨實際 App Bundle Identifier。

## Gemini

DeskPet 不內建 API Key。使用者需在「設定 → AI」自行輸入，秘密值只寫入 macOS Keychain。

目前 UI 提供的 Gemini model ID 以 Google 官方 Gemini API 型號為基礎；模型生命週期可能變更，維護者應在 release 前重新核對官方文件。

Calendar Intelligence 不使用 Gemini 判斷或篩選行事曆事件；查詢資料維持本機處理。

## Google Apps Script Gateway

公開版本不含任何私人 Spreadsheet ID、Gateway URL 或 API Token。

完整安裝流程見：[`docs/GAS_GATEWAY_SETUP.md`](docs/GAS_GATEWAY_SETUP.md)

DeskPet Gateway 已依 [`mihozip/school-admin-daily-dashboard`](https://github.com/mihozip/school-admin-daily-dashboard) 的資料契約嫁接。請看：

- [`docs/GAS_PROJECT_INTEGRATION.md`](docs/GAS_PROJECT_INTEGRATION.md)：獨立 Gateway 架構、安裝步驟、處室切換與安全邊界
- [`GAS/DeskPet_GAS_API_Gateway_v3.js`](GAS/DeskPet_GAS_API_Gateway_v3.js)：可獨立部署的 Gateway 程式

Gateway 必須建成獨立 Apps Script 專案，再透過 `DESKPET_SPREADSHEET_ID` 附掛到已安裝完成的 Dashboard 試算表。它會動態讀取 Dashboard 的學校、處室、職務與選項清單，不會自行建立或覆寫工作表。

### 何時才視為完成串接

RC1.1.3 起，DeskPet 不再只用「有沒有填 URL」判斷校務任務功能是否可用。必須同時滿足：

1. GAS 整合已啟用。
2. Endpoint 是有效 HTTPS URL。
3. Keychain 中存在 API Token。
4. DeskPet 曾成功取得 Dashboard integration metadata。

四個條件都成立後，才會在桌寵與選單列顯示校務任務相關功能。尚未串接時，這些選單會隱藏，只在「設定」保留串接入口，避免一般使用者看到一堆不能使用的功能。

### 行政職稱

DeskPet 依序使用「本機行政職稱覆寫 → Dashboard `ROLE_NAME` → 預設 `總務`」。可在「設定 → 一般 → 行政職稱與工作介面」修改或恢復跟隨 Dashboard。

同一職稱會套用到「職稱工作台」、「職稱工作摘要」、「職稱工作提醒」、「職稱任務操作」、相關任務提示，以及 DeskPet 新建任務的負責人名稱；不會改寫 Dashboard 的 `OFFICE_KEY`／`ROLE_KEY`。從 `0.9.3.0` 更新時，舊「工作介面名稱」會自動遷移成行政職稱覆寫。

核心安全邊界：

- Gateway 的 `doGet()` 不回傳任務資料。
- API 寫入需要 bearer-style token（放在 HTTPS JSON body）。
- Token 儲存在 Apps Script Script Properties 與 macOS Keychain。
- `updateTask` 只允許有限欄位。
- 所有外部寫入仍需使用者確認。

## 本機資料

```text
~/Library/Application Support/DeskPet/inbox.json
~/Library/Application Support/DeskPet/work-events.json
```

更多資料流與隱私說明：[`PRIVACY.md`](PRIVACY.md)

RC1.0 Daily Work Loop 設計與測試計畫：[`docs/RC1_DAILY_WORK_LOOP.md`](docs/RC1_DAILY_WORK_LOOP.md)、[`docs/RC1_TEST_PLAN.md`](docs/RC1_TEST_PLAN.md)

RC1.1 Calendar Intelligence：[`docs/RC1_1_CALENDAR_INTELLIGENCE.md`](docs/RC1_1_CALENDAR_INTELLIGENCE.md)

RC1.1.1 Desktop Interaction Fix：[`docs/RC1_1_1_DESKTOP_INTERACTION.md`](docs/RC1_1_1_DESKTOP_INTERACTION.md)

最新版本變更請見：[`CHANGELOG.md`](CHANGELOG.md)

## 專案結構

```text
Sources/DeskPet/
├── App/        App lifecycle
├── Models/     資料模型
├── Stores/     狀態與持久化
├── Services/   Gemini / GAS / EventKit / Speech / Keychain / Trash
├── Views/      SwiftUI views
├── Window/     AppKit window / panel controllers
└── Resources/  Default pet artwork

GAS/            Google Apps Script Gateway
script/         Build / install / update / public-repo checks
docs/           Architecture / Gateway / releasing docs
.github/        CI and contribution templates
```

架構說明：[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

## 開發原則

DeskPet 對外部系統採用這條邊界：

> **AI 可以理解與提出操作；使用者負責授權；Workflow 才負責執行。**

因此讀取與整理可以主動發生，但 Calendar、Reminders 與 GAS 的寫入不應在沒有確認的情況下自動執行。清理垃圾桶屬於不可逆刪除，同樣必須由使用者明確確認後才執行。

## 公開素材

公開版包含四張預設白貓 PNG，對應待機、聆聽、成功與睡眠狀態：

- `pet_idle.png`
- `pet_listening.png`
- `pet_success.png`
- `pet_sleep.png`

這些檔案是專案維護者提供並核准公開散布的 AI 輔助重繪素材，預設隨專案一併採 MIT License 發布。素材來源與權利說明見 [`ASSETS.md`](ASSETS.md)。

## 安全與回報

請不要在公開 Issue 貼出 Gemini API Key、GAS Token、Spreadsheet ID、包含個資的 Diary / Inbox 或私有 Gateway URL。

安全性問題請參閱 [`SECURITY.md`](SECURITY.md)。

## 貢獻

歡迎 Issue 與 Pull Request。開始前請閱讀 [`CONTRIBUTING.md`](CONTRIBUTING.md)。

## License

DeskPet 原始碼與專案提供的預設白貓素材以 [MIT License](LICENSE) 釋出。

第三方或使用者自行加入的圖片、字型、商標與其他素材，仍依其各自授權條款處理。