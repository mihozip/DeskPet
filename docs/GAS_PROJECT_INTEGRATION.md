# 嫁接 school-admin-daily-dashboard

DeskPet Gateway 直接依 [`mihozip/school-admin-daily-dashboard`](https://github.com/mihozip/school-admin-daily-dashboard) 的實際資料契約運作。它不是第二套任務系統，而是 Dashboard 提供給 DeskPet macOS App 的 JSON API 邊界。

自 2026-08-21 起，推薦架構改為：**Gateway 程式與 Dashboard 放在同一個 Apps Script 專案，但使用不同 Web App deployment。**

## 為什麼仍要分成兩個 deployment

Dashboard 管理台是給「人」使用的 Web App，使用 Google／Workspace 登入、`ALLOWED_DOMAIN` 與使用者 CSRF Token 保護。DeskPet 的 `URLSession` 則需要可以直接送出 JSON POST，無法先操作 Google 登入頁。

因此需要分開「部署權限」，但不必再分開「Apps Script 專案」。

```text
瀏覽器使用者
  │ Google / Workspace 登入
  ▼
Dashboard Deployment（網域限定）
  │
  ├───────────────┐
  ▼               ▼
任務清單等 Sheets   DeskPet API Deployment（直接 POST）
                  ▲
                  │ HTTPS POST + DESKPET_API_TOKEN
                  │
              DeskPet macOS App
```

兩個 deployment 共用：

- 同一個 Apps Script 專案
- 同一份 Spreadsheet
- 同一套 `Code.gs` helper
- 同一套 19 欄任務契約
- 同一個 `DESKPET_API_TOKEN` Script Property

## Dashboard 端檔案

新版 `school-admin-daily-dashboard` Apps Script 專案應包含：

```text
Code.gs
DeskPetGateway.gs
Installer.html
Index.html
Board.html
appsscript.json
```

`DeskPetGateway.gs` 只新增機器 API `doPost()` 與 Token 管理函式；任務資料仍使用 `Code.gs` 的 canonical helper，因此不會建立第二套資料結構。

## 安全前置條件

在同一 Apps Script 專案建立「任何人」可存取的 DeskPet API deployment 前，先在 `系統設定` 填入：

```text
ALLOWED_DOMAIN = 你的 Workspace 網域
```

例如：

```text
ALLOWED_DOMAIN = school.edu.tw
```

原因是同一專案仍包含管理台 `doGet()`。API deployment 可公開接受 POST，但 Dashboard 的 `getBootstrapData()`、`getTasks()`、`saveTask()` 等人機操作仍必須由 `assertAuthorized_()` 擋住匿名存取。

若環境無法安全設定 `ALLOWED_DOMAIN`，請改用舊版「獨立 Gateway 專案」模式。

## 啟用整合

先完成 Dashboard 安裝，確認存在：

```text
任務清單
工作紀錄
系統設定
選項清單
```

接著從 Apps Script 編輯器執行：

```javascript
setupDeskPetGateway()
```

新版同專案 Gateway 會：

1. 建立或沿用 `DESKPET_API_TOKEN`。
2. 直接使用 Dashboard 綁定的 Spreadsheet。
3. 驗證四張必要工作表。
4. 驗證 `任務清單` 19 欄與 `工作紀錄` 7 欄。
5. 讀取目前學校、處室、職務與動態選項。

不再需要：

```text
DESKPET_SPREADSHEET_ID
手動複製 BOUND_SPREADSHEET_ID
另一個 Apps Script 專案
```

## 建立 DeskPet API deployment

在 Dashboard 同一個 Apps Script 專案再建立一個 Web App deployment：

- Execute as：部署者
- Who has access：能讓 DeskPet 不經 Google 登入直接 POST 的模式，通常為任何人

Dashboard 原本的管理台 deployment 仍維持 Workspace／網域限定。

因此會有兩個不同的 `/exec` URL：

```text
Dashboard URL   → 瀏覽器管理台／看板
DeskPet API URL → DeskPet POST
```

**DeskPet 設定只能填第二個。**

若把 Dashboard URL 填入 DeskPet，Google 會先回登入頁或 HTML，App 就會顯示「Web App 回傳登入／HTML 頁面」。

## 設定 DeskPet

在 DeskPet「設定 → 校務任務系統（Google Apps Script）」：

1. 貼上 DeskPet API deployment 的 `/exec` URL。
2. 貼上 `DESKPET_API_TOKEN`。
3. 啟用串接。
4. 按「測試連線」。

連線成功後，DeskPet 會保存 integration metadata，包含學校、處室、職務與目前 profile 的選項清單。

## 與 Dashboard 對齊的資料契約

Gateway 直接使用 Dashboard 的標準 19 欄：

```text
任務ID、任務名稱、類型、狀態、優先級、截止日期、截止時間、
下一步行動、等待對象、最近進度、負責人、負責人Email、
看板顯示、顯示排序、詳細連結、建立時間、更新時間、完成時間、封存
```

工作紀錄使用：

```text
紀錄ID、任務ID、動作、變更前、變更後、操作者、時間
```

Gateway 從 `系統設定` 讀取：

- `SYSTEM_NAME`
- `SCHOOL_NAME`
- `OFFICE_KEY`、`OFFICE_NAME`
- `ROLE_KEY`、`ROLE_NAME`
- `DEFAULT_OWNER`、`DEFAULT_OWNER_EMAIL`

Gateway 從目前 Dashboard profile 動態讀取：

- `類型`
- `狀態`
- `優先級`
- `看板顯示`

因此 Dashboard 切換處室後，不需要修改 Gateway 原始碼或 Spreadsheet ID；回 DeskPet 再按一次「測試連線」即可刷新 metadata。

## API 與寫入邊界

| Action | 行為 |
| --- | --- |
| `ping` | 驗證 Token、Dashboard 契約，回傳 integration metadata |
| `createTask` | 使用 `clientTaskId` 產生穩定 DeskPet 任務 ID，避免重複建立 |
| `taskDigest` | 讀取未封存的工作摘要，回傳逾期、今日、高優先與等待旗標 |
| `updateTask` | 只允許狀態、期限、下一步行動、等待對象與最近進度 |

`nextAction` 已列入 update allow-list。`nil` 表示不修改欄位，空字串表示明確清除欄位，對應 DeskPet RC1.2.1.1 的 mutation semantics。

所有 DeskPet 寫入都會追加到 Dashboard 的 `工作紀錄`，操作者標記為 request `source`（預設 `deskpet-macos`）。

## 處室切換流程

1. 在 Dashboard 再次執行「安裝／選擇處室」。
2. Dashboard 更新 `系統設定` 與選項，並保留舊任務使用過的分類。
3. 在 DeskPet 設定頁按「測試連線」。
4. 確認「已嫁接」摘要顯示新的處室／職務。

不需要重新建立 Token，也不需要重新指定 Spreadsheet。

## DeskPet 行政職稱覆寫

DeskPet 依序使用本機覆寫、integration metadata 的 `ROLE_NAME`，最後才使用預設「總務」。可在「設定 → 一般 → 行政職稱與工作介面」建立本機覆寫，例如在不切換 Dashboard profile 的情況下使用代理主任或自訂職稱。

本機覆寫具有以下邊界：

- 儲存在 DeskPet `UserDefaults`，不送回 Dashboard 系統設定。
- 同時套用到 DeskPet 工作台、工作摘要、工作提醒、任務操作、相關任務訊息，以及 `createTask` request 的 `owner` 欄位。
- 不修改 Dashboard 的 `OFFICE_KEY`、`ROLE_KEY`、`ROLE_NAME` 或 `DEFAULT_OWNER`。
- 清除覆寫後立即恢復使用最新同步的 Dashboard `ROLE_NAME`。

正式切換處室或職務仍應使用 Dashboard 的「安裝／選擇處室」，再回 DeskPet 測試連線以刷新 metadata。

## Token 與診斷

建立／沿用 Token：

```javascript
setupDeskPetGateway()
```

顯示 Token：

```javascript
showDeskPetApiToken()
```

查看狀態：

```javascript
getDeskPetGatewayStatus()
```

輪替 Token：

```javascript
resetDeskPetApiToken()
```

Token 若外流，應立即執行 `resetDeskPetApiToken()`，並同步更新 DeskPet Keychain。

## 舊版獨立 Gateway

`GAS/DeskPet_GAS_API_Gateway_v3.js` 仍保留作為備援。舊架構為：

```text
Dashboard Apps Script → Spreadsheet ← 獨立 Gateway Apps Script ← DeskPet
```

適用於 Workspace 政策不允許 Dashboard 同專案建立公開 API deployment，或無法安全設定 `ALLOWED_DOMAIN` 的環境。

新安裝則優先採用 `school-admin-daily-dashboard/DeskPetGateway.gs` 的同專案雙 deployment 模式。
