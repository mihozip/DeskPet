# Google Apps Script Gateway Setup

DeskPet Gateway 是 [`school-admin-daily-dashboard`](https://github.com/mihozip/school-admin-daily-dashboard) 的獨立機器 API。請先完成 Dashboard 安裝，再把 Gateway 附掛到同一份 Spreadsheet。

## 快速設定

1. 依參考專案 README 安裝 Dashboard 並選擇學校、處室與職務。
2. 取得 Dashboard 安裝時保存的 `BOUND_SPREADSHEET_ID`，或從 Spreadsheet 網址複製 ID。
3. 建立獨立 Apps Script 專案並貼上 `GAS/DeskPet_GAS_API_Gateway_v3.js`。
4. 在 Gateway 專案執行：

   ```javascript
   configureDeskPetGateway('BOUND_SPREADSHEET_ID');
   ```

   這一步會驗證 Dashboard 資料契約，並在尚未存在 Token 時自動建立 `DESKPET_API_TOKEN`。

5. 若要明確建立／取得目前 Token，可從 Apps Script 函數選單執行：

   ```javascript
   createDeskPetApiToken()
   ```

   - 第一次執行會建立 Token。
   - 已有 Token 時會沿用原 Token，不會因重新部署而自動更換。
   - 函數回傳結果包含目前 Token；也可以從 **Project Settings → Script Properties → `DESKPET_API_TOKEN`** 複製。

6. 將 Gateway 獨立部署成 DeskPet 可直接 POST 的 Web App。
7. 在 DeskPet 設定中填入 Gateway `/exec` URL 與 `DESKPET_API_TOKEN`，啟用後測試連線。

## API Token 管理

正常重新部署 Gateway **不需要換 Token**。只要仍是同一個 Apps Script 專案，`DESKPET_API_TOKEN` 會保存在 Script Properties。

若需要確認 Token 是否存在，可執行：

```javascript
getDeskPetGatewayStatus()
```

這個函數只回傳 `tokenConfigured` 等狀態，不會輸出秘密值。

只有在 Token 遺失、疑似外洩，或你真的要輪替憑證時，才執行：

```javascript
resetDeskPetApiToken()
```

`resetDeskPetApiToken()` 會立即產生新 Token，舊 Token 同時失效；執行後必須把新的 Token 同步更新到 DeskPet 設定。

請勿把 Gateway 合併進 Dashboard 的 `Code.gs`；兩者使用不同 Web App 入口與授權模型。

完整架構、契約、處室切換與安全說明見 [`GAS_PROJECT_INTEGRATION.md`](GAS_PROJECT_INTEGRATION.md)。
