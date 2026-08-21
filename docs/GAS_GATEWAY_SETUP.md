# Google Apps Script Gateway Setup

DeskPet Gateway 是 [`school-admin-daily-dashboard`](https://github.com/mihozip/school-admin-daily-dashboard) 的獨立機器 API。請先完成 Dashboard 安裝，再把 Gateway 指向同一份 Spreadsheet。

## 快速設定

1. 依參考專案 README 安裝 Dashboard，並選擇學校、處室與職務。
2. 取得 Dashboard 安裝時保存的 `BOUND_SPREADSHEET_ID`，或直接從 Spreadsheet 網址複製 ID。
3. 建立**獨立** Apps Script 專案，將 `GAS/DeskPet_GAS_API_Gateway_v3.js` 貼入 `Code.gs`。
4. 打開 Apps Script 左側 **Project Settings（專案設定）**，在 **Script Properties（指令碼屬性）** 新增：

   ```text
   DESKPET_SPREADSHEET_ID = 你的 BOUND_SPREADSHEET_ID
   ```

5. 回到 Apps Script 編輯器，從上方函式選單直接執行：

   ```javascript
   setupDeskPetGateway()
   ```

   `setupDeskPetGateway()` 是無參數入口，適合直接從 Apps Script 函式選單執行。它會依下列順序處理：

   1. 建立或沿用 `DESKPET_API_TOKEN`。
   2. 讀取 `DESKPET_SPREADSHEET_ID`。
   3. 驗證 Dashboard 工作表與設定契約。

   **Token 會先建立。** 因此即使 Spreadsheet ID 尚未設定、填錯，或 Dashboard schema 驗證失敗，已建立的 `DESKPET_API_TOKEN` 仍會保留在 Script Properties，不會因初始化失敗而消失。

6. 回到 **Project Settings → Script Properties**，複製：

   ```text
   DESKPET_API_TOKEN
   ```

7. 將 Gateway 獨立部署成 DeskPet 可直接 POST 的 Web App：
   - 執行身分：**我**
   - 誰可以存取：**任何人**
8. 在 DeskPet 設定中填入 Gateway `/exec` URL 與 `DESKPET_API_TOKEN`，啟用後測試連線。

## 只需要先建立 Token

若目前還沒準備好 Spreadsheet，也可以從 Apps Script 函式選單直接執行：

```javascript
createDeskPetApiToken()
```

第一次執行會建立 Token；已有 Token 時會沿用原值。執行紀錄會提示 Token 已建立或已存在，但**不會把秘密值直接印在 log 中**。請從：

**Project Settings → Script Properties → `DESKPET_API_TOKEN`**

複製實際 Token。

## 為什麼不直接從函式選單執行 configureDeskPetGateway？

`configureDeskPetGateway(spreadsheetId)` 仍保留給程式碼呼叫或進階使用，但 Apps Script 編輯器上方的函式選單**不能傳入參數**。因此一般安裝流程不要直接從選單執行它，否則 `spreadsheetId` 會是空值，並得到 `Spreadsheet ID 格式不正確`。

一般使用者請改用：

1. Script Properties 設定 `DESKPET_SPREADSHEET_ID`
2. 執行無參數的 `setupDeskPetGateway()`

## API Token 管理

正常重新部署 Gateway **不需要換 Token**。只要仍是同一個 Apps Script 專案，`DESKPET_API_TOKEN` 會保存在 Script Properties。

若需要確認 Gateway 狀態，可執行：

```javascript
getDeskPetGatewayStatus()
```

這個函數只回傳 `tokenConfigured`、`spreadsheetConfigured`、`dashboardContractValid` 等狀態，不會輸出 Token 秘密值。

只有在 Token 遺失、疑似外洩，或你確定要輪替憑證時，才執行：

```javascript
resetDeskPetApiToken()
```

`resetDeskPetApiToken()` 會立即產生新 Token，舊 Token 同時失效；執行後必須把新的 Token 同步更新到 DeskPet 設定。

請勿把 Gateway 合併進 Dashboard 的 `Code.gs`；兩者使用不同 Web App 入口與授權模型。

完整架構、契約、處室切換與安全說明見 [`GAS_PROJECT_INTEGRATION.md`](GAS_PROJECT_INTEGRATION.md)。
