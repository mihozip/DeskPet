# 把 DeskPet GAS Gateway 接到你的專案

這份文件說明如何讓公開版 DeskPet 使用你自己的 Google Spreadsheet，或接進既有的 Google Apps Script 工作系統，同時避免把 Spreadsheet ID、部署網址與 Token 寫進公開原始碼。

## 建議架構

```text
DeskPet macOS App
  │ HTTPS POST + API Token
  ▼
獨立 DeskPet GAS Gateway
  │ DESKPET_SPREADSHEET_ID（Script Property）
  ▼
你的既有 Google Spreadsheet
```

Gateway 建議維持為獨立 Apps Script 專案。原本的管理後台可繼續使用 Google 帳號或 Workspace 權限；DeskPet Gateway 則只處理 JSON API、Token 驗證與限定欄位的任務操作。

## 最少整合步驟

1. 在 Apps Script 建立一個獨立專案。
2. 貼上 [`GAS/DeskPet_GAS_API_Gateway_v3.js`](../GAS/DeskPet_GAS_API_Gateway_v3.js)。
3. 從你的 Spreadsheet 網址取得 ID：

   ```text
   https://docs.google.com/spreadsheets/d/SPREADSHEET_ID/edit
   ```

4. 在 Apps Script 編輯器執行：

   ```javascript
   configureDeskPetGateway('你的 SPREADSHEET_ID');
   ```

   這個函式會把 ID 寫入 Script Properties、建立或驗證必要工作表，並在尚未設定時產生 API Token。若 Spreadsheet 無法開啟或初始化失敗，原設定會自動還原。

5. 在 **Project Settings → Script Properties** 複製 `DESKPET_API_TOKEN`。
6. 把 Gateway 部署成 Web App：執行身分選擇自己，存取方式需允許 DeskPet 的 HTTP client 直接 POST。
7. 在 DeskPet「設定 → 總務工作台」填入 `/exec` 網址與 Token，啟用串接後按「測試連線」。

不要把真實的 Spreadsheet ID、`/exec` 網址或 Token 寫回此 repository。

## 預設工作表 contract

Gateway 預設使用三張工作表：

| 工作表 | 用途 |
| --- | --- |
| `任務清單` | 任務主資料、狀態與期限 |
| `工作紀錄` | 建立與更新的 append-only 紀錄 |
| `系統設定` | 預設負責人與 Email |

`任務清單` 需要以下欄位。既有工作表可以包含其他欄位，但這些欄名必須存在：

```text
任務ID、任務名稱、類型、狀態、優先級、截止日期、截止時間、
下一步行動、等待對象、最近進度、負責人、負責人Email、
看板顯示、顯示排序、詳細連結、建立時間、更新時間、完成時間、封存
```

`工作紀錄` 需要：

```text
紀錄ID、任務ID、動作、變更前、變更後、操作者、時間
```

空白 Spreadsheet 可由 `configureDeskPetGateway()` 自動建立這些結構；已有同名工作表時只會驗證欄位，不會默默覆寫既有資料。

## DeskPet 與 Gateway 的固定 API contract

macOS App 使用 API v3，支援四個 action：

| Action | 用途 | 主要欄位 |
| --- | --- | --- |
| `ping` | 測試 Token 與部署 | `token` |
| `createTask` | 建立任務 | `clientTaskId`、`rawText`、`task` |
| `taskDigest` | 取得未封存任務摘要 | `limit` |
| `updateTask` | 更新既有任務 | `taskId`、`update`、`reason` |

`clientTaskId` 是建立任務的冪等鍵。`updateTask` 只允許更新 `status`、`dueDate`、`dueTime`、`waitingFor`、`progress`，避免桌面代理人改寫任務名稱、分類或負責人等核心資料。

只要保留上述 request／response contract，你可以在 Gateway 內替換資料來源或欄位映射，而不必修改 macOS App。

## 接到不同欄位結構的既有專案

如果你的工作表欄名不同，集中調整 Gateway 的這幾個區域：

- `GATEWAY_CONFIG`：工作表名稱與時區
- `GATEWAY_TASK_HEADERS`、`GATEWAY_LOG_HEADERS`：必要欄位
- `GATEWAY_OPTIONS`：類型、狀態、優先級與看板選項
- `taskToRow_()`：API task 寫入工作表的映射
- `rowArrayToTask_()`：工作表資料轉回 API task 的映射
- `readDefaults_()`：讀取你專案的預設負責人設定

保留 `verifyToken_()`、`constantTimeEquals_()`、`clientTaskId` 冪等處理、更新欄位 allow-list 與 public `doGet()` 不回傳任務資料等安全邊界。

## 若你的專案已有 Apps Script 後台

不要直接用需要 Google 登入的後台 Web App URL 當 DeskPet endpoint；URLSession 收到的通常會是 401、403 或登入 HTML。

推薦做法是：

- 後台 Apps Script：維持原本的使用者登入與管理 UI。
- DeskPet Gateway：獨立部署，只提供 JSON API。
- 兩者：透過同一個 Spreadsheet ID 操作相同資料。

這樣公開 API 的權限、Token 輪替與部署版本都能與管理後台分開管理。

## 上線前檢查

- `doGet()` 只回健康狀態，不回任務內容。
- 真實 Token 只存在 Script Properties 與 macOS Keychain。
- Gateway 使用新的獨立部署網址；舊 Token 若曾外流就先輪替。
- 使用非正式資料測試 `ping`、建立、摘要與更新。
- 確認 Workspace 政策允許 Web App 接受 DeskPet 的 POST。
