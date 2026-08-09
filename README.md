# DeskPet

[![CI](https://github.com/mihozip/DeskPet/actions/workflows/ci.yml/badge.svg)](https://github.com/mihozip/DeskPet/actions/workflows/ci.yml)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-111111?logo=apple)](https://www.apple.com/macos/)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> **讓桌面上的每一個念頭，從捕捉一路走到完成。**

DeskPet 是一隻住在 macOS 桌面的工作代理人。它把快速記事、規則或 Gemini 理解、人工確認、Calendar／Reminders／GAS 任務執行，以及每日工作日誌串成同一條可追蹤的工作流。

**目前版本：0.9.1.2 — Duplicate Guard（pre-1.0 / RC）**

DeskPet 是以 Swift / SwiftUI / AppKit 開發的 macOS 桌面工具。它不是要取代既有的任務系統，而是提供一個隨手可用的桌面入口，把零散資訊轉成可追蹤的工作。

```text
Capture
  ↓
Inbox
  ↓
Understand (local rules / Gemini)
  ↓
Confirm
  ↓
Calendar / Reminders / GAS Task
  ↓
Monitor
  ↓
Work Diary
```

## 主要功能

- 桌面常駐 DeskPet，可拖曳、調整大小與動畫強度。
- 全域快捷鍵快速記事，內容保存於本機 Inbox。
- Smart Inbox：本機規則解析，亦可選擇啟用 Gemini API。
- Apple Calendar / Reminders 建立前必須人工確認。
- Google Apps Script Gateway：建立、讀取、更新工作任務。
- Ambient Agent：定期讀取進行中、逾期、高優先與等待任務。
- Natural Action / Voice Action：自然語句或語音提出任務變更草案，再由使用者確認。
- Inbox → Task Link：保留原始 Inbox 與正式 GAS Task 的關聯。
- Duplicate Guard：建立 GAS Task 前提示可能重複的工作，不自動刪除或合併。
- Work Diary：以 `WorkEvent` 保存每天實際發生的工作事件，可供後續匯出與分析。

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

### Bundle ID

預設保留目前專案識別碼以維持既有安裝相容性；fork 或自行發佈時可覆寫：

```bash
BUNDLE_ID="io.github.yourname.DeskPet" ./script/build_release.sh
```

Keychain service 會跟隨實際 App Bundle Identifier。

## Gemini

DeskPet 不內建 API Key。使用者需在「設定 → AI」自行輸入，秘密值只寫入 macOS Keychain。

目前 UI 提供的 Gemini model ID 以 Google 官方 Gemini API 型號為基礎；模型生命週期可能變更，維護者應在 release 前重新核對官方文件。

## Google Apps Script Gateway

公開版本不含任何私人 Spreadsheet ID、Gateway URL 或 API Token。

完整安裝流程見：[`docs/GAS_GATEWAY_SETUP.md`](docs/GAS_GATEWAY_SETUP.md)

如果要把 DeskPet 接到你自己的既有 Google Spreadsheet／Apps Script 專案，請看：

- [`docs/GAS_PROJECT_INTEGRATION.md`](docs/GAS_PROJECT_INTEGRATION.md)：哪些部分直接沿用、哪些欄位可依你的專案調整
- [`GAS/DeskPet_GAS_API_Gateway_v3.js`](GAS/DeskPet_GAS_API_Gateway_v3.js)：可獨立部署的 Gateway 程式

建議把 Gateway 建成獨立 Apps Script 專案，再透過 `DESKPET_SPREADSHEET_ID` 連到既有試算表。這樣不必把公開 HTTP API 混進原本的管理後台，也較容易獨立輪替 Token 與部署版本。

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

## 專案結構

```text
Sources/DeskPet/
├── App/        App lifecycle
├── Models/     資料模型
├── Stores/     狀態與持久化
├── Services/   Gemini / GAS / EventKit / Speech / Keychain
├── Views/      SwiftUI views
├── Window/     AppKit window / panel controllers
└── Resources/  Optional pet artwork

GAS/            Google Apps Script Gateway
script/         Build / install / public-repo checks
docs/           Architecture / Gateway / releasing docs
.github/        CI and contribution templates
```

架構說明：[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

## 開發原則

DeskPet 對外部系統採用這條邊界：

> **AI 可以理解與提出操作；使用者負責授權；Workflow 才負責執行。**

因此讀取與整理可以主動發生，但 Calendar、Reminders 與 GAS 的寫入不應在沒有確認的情況下自動執行。

## 公開素材

原型階段使用的白貓 PNG **沒有在公開原始碼包中散布**，因為目前沒有可驗證的再散布授權。程式碼的 MIT License 不會自動涵蓋外部圖片素材。

如果你有自己的合法素材，加入：

```text
Sources/DeskPet/Resources/pet_idle.png
Sources/DeskPet/Resources/pet_listening.png
Sources/DeskPet/Resources/pet_success.png
Sources/DeskPet/Resources/pet_sleep.png
```

## 安全與回報

請不要在公開 Issue 貼出 Gemini API Key、GAS Token、Spreadsheet ID、包含個資的 Diary / Inbox 或私有 Gateway URL。

安全性問題請參閱 [`SECURITY.md`](SECURITY.md)。

## 貢獻

歡迎 Issue 與 Pull Request。開始前請閱讀 [`CONTRIBUTING.md`](CONTRIBUTING.md)。

## License

DeskPet **原始碼**以 [MIT License](LICENSE) 釋出。

第三方或使用者自行加入的圖片、字型、商標與其他素材，仍依其各自授權條款處理。
