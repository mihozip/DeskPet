# 嫁接 school-admin-daily-dashboard

DeskPet Gateway 已依 [`mihozip/school-admin-daily-dashboard`](https://github.com/mihozip/school-admin-daily-dashboard) 的實際資料契約設計。它不是另一套任務系統，而是該系統提供給 DeskPet macOS App 的獨立 JSON API 邊界。

## 為什麼必須使用獨立 Gateway

`school-admin-daily-dashboard` 的 Web App 是管理台與電子紙看板，使用 Google／Workspace 登入、`ALLOWED_DOMAIN` 與使用者 CSRF Token 保護。DeskPet 的 `URLSession` 無法操作這種登入頁，也不應把管理台直接公開成「任何人」可存取。

正確架構是：

```text
瀏覽器使用者
  │ Google / Workspace 登入
  ▼
school-admin-daily-dashboard Web App
  │
  ├───────────────┐
  ▼               ▼
任務清單等 Sheets   DeskPet 獨立 Gateway Web App
                  ▲
                  │ HTTPS POST + DESKPET_API_TOKEN
                  │
              DeskPet macOS App
```

兩個 Apps Script 專案操作同一份 Spreadsheet，但使用不同部署網址與不同授權邊界。不要把 Gateway 程式貼進 Dashboard 的 `Code.gs`；兩邊都有 Web App 入口，混在一起會造成 `doGet()` 衝突，也會模糊管理台與機器 API 的權限。

## 前置條件：先安裝 Dashboard

先依參考專案 README 完成安裝：

1. 將 `Code.gs`、`Installer.html`、`Index.html`、`Board.html` 與 `appsscript.json` 安裝到綁定 Google Sheet 的 Apps Script 專案。
2. 從「校務任務系統 → 安裝／選擇處室」選擇學校、處室與職務。
3. 確認已建立：`任務清單`、`工作紀錄`、`系統設定`、`選項清單`。

Dashboard 安裝時會把 Spreadsheet ID 寫入它自己的 Script Property：

```text
BOUND_SPREADSHEET_ID
```

這個 ID 也可以從試算表網址取得：

```text
https://docs.google.com/spreadsheets/d/SPREADSHEET_ID/edit
```

## 建立獨立 DeskPet Gateway

1. 建立一個新的「獨立」Apps Script 專案，例如 `DeskPet API Gateway`。
2. 貼上 [`GAS/DeskPet_GAS_API_Gateway_v3.js`](../GAS/DeskPet_GAS_API_Gateway_v3.js)。
3. 在 Gateway 專案的編輯器執行：

   ```javascript
   configureDeskPetGateway('從 Dashboard 取得的 BOUND_SPREADSHEET_ID');
   ```

4. 函式會完成以下工作：

   - 儲存 `DESKPET_SPREADSHEET_ID` 到 Gateway 的 Script Properties。
   - 以唯讀方式驗證 Dashboard 的四張必要工作表。
   - 驗證 `任務清單` 19 欄與 `工作紀錄` 7 欄資料契約。
   - 讀取目前的學校、處室、職務與動態選項。
   - 產生 `DESKPET_API_TOKEN`（若尚未存在）。

Gateway 不會建立、遷移、清空或重新格式化 Dashboard 的工作表。如果契約不符，設定會失敗並還原原本的 Spreadsheet ID。

5. 在 Gateway 的 **Project Settings → Script Properties** 複製 `DESKPET_API_TOKEN`。
6. 將 Gateway 部署為 Web App：

   - Execute as：部署者
   - Who has access：能讓 DeskPet 直接 POST 的模式；常見為 anyone，實際名稱依 Workspace 政策而異

Dashboard 管理台仍維持 Workspace 限制；只有獨立 Gateway 使用 Token 作為應用層授權。

## 設定 DeskPet

在 DeskPet「設定 → 校務任務系統（Google Apps Script）」：

1. 貼上 Gateway 的 `/exec` 網址。
2. 貼上 `DESKPET_API_TOKEN`。
3. 啟用串接。
4. 按「測試連線」。

連線成功後，DeskPet 會顯示嫁接到的學校、處室、職務與任務類型數量。Gateway 會回傳 integration metadata，DeskPet 的分類選單不再固定為總務處，而是直接使用 Dashboard `選項清單` 的目前 profile。

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

Gateway 從 `選項清單` 動態讀取：

- `類型`
- `狀態`
- `優先級`
- `看板顯示`

因此參考專案切換處室後，不需要修改 Gateway 原始碼。回到 DeskPet 再按一次「測試連線」，即可立即刷新本機保存的 integration metadata；Ambient 摘要同步時也會自動更新。

## API 與寫入邊界

| Action | 行為 |
| --- | --- |
| `ping` | 驗證 Token、Dashboard 契約，回傳 integration metadata |
| `createTask` | 使用 `clientTaskId` 冪等建立任務，分類與優先級依目前 `選項清單` 驗證 |
| `taskDigest` | 讀取未封存任務與統計，並同步 integration metadata |
| `updateTask` | 只允許狀態、期限、既有下一步行動、等待對象與最近進度 |

RC1.0 將 `nextAction` 安全加入 allow-list，對應既有第 8 欄「下一步行動」。Gateway 仍驗證完整 19 欄契約，不新增或遷移 Dashboard 欄位。

如果 DeskPet 傳來的分類已不在目前處室 profile，Gateway 會安全降級為 `其他`（若存在）或第一個合法分類，避免因切換處室讓建立任務完全失敗。

## 處室切換流程

1. 在 Dashboard 再次執行「安裝／選擇處室」。
2. Dashboard 更新 `系統設定` 與 `選項清單`，並保留既有任務使用過的舊分類。
3. 在 DeskPet 設定頁按「測試連線」。
4. 確認「已嫁接」摘要顯示新的處室／職務。

不需要重新部署 Gateway，也不需要更換 Token 或 Spreadsheet ID。

## DeskPet 行政職稱覆寫

DeskPet 依序使用本機覆寫、integration metadata 的 `ROLE_NAME`，最後才使用預設「總務」。可在「設定 → 一般 → 行政職稱與工作介面」建立本機覆寫，例如在不切換 Dashboard profile 的情況下使用代理主任或自訂職稱。

本機覆寫具有以下邊界：

- 儲存在 DeskPet `UserDefaults`，不送回 Dashboard 系統設定。
- 同時套用到 DeskPet 工作台、工作摘要、工作提醒、任務操作、相關任務訊息，以及 `createTask` request 的 `owner` 欄位。
- 不修改 Dashboard 的 `OFFICE_KEY`、`ROLE_KEY`、`ROLE_NAME` 或 `DEFAULT_OWNER`。
- 清除覆寫後立即恢復使用最新同步的 Dashboard `ROLE_NAME`；若 Dashboard 尚未提供職稱，則顯示預設「總務」。
- 從 `0.9.3.0` 更新時，舊工作介面名稱會在沒有既有行政職稱覆寫的前提下自動遷移一次。

正式切換處室或職務仍應使用 Dashboard 的「安裝／選擇處室」，再回 DeskPet 測試連線以刷新 metadata。

## 安全檢查

- Dashboard Web App 維持 Workspace／網域限制。
- Gateway `doGet()` 只回健康狀態，不回任務內容。
- 所有任務 API 都必須通過 `DESKPET_API_TOKEN`。
- 真實 Token 只存在 Gateway Script Properties 與 macOS Keychain。
- Spreadsheet ID、Gateway `/exec` URL 與 Token 不得提交到公開 repository。
- Token 若曾外流，執行 `resetDeskPetApiToken()` 並更新 DeskPet Keychain。
