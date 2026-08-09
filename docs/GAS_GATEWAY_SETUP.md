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

5. 從 Gateway Script Properties 複製產生的 `DESKPET_API_TOKEN`。
6. 將 Gateway 獨立部署成 DeskPet 可直接 POST 的 Web App。
7. 在 DeskPet 設定中填入 Gateway `/exec` URL 與 Token，啟用後測試連線。

請勿把 Gateway 合併進 Dashboard 的 `Code.gs`；兩者使用不同 Web App 入口與授權模型。

完整架構、契約、處室切換與安全說明見 [`GAS_PROJECT_INTEGRATION.md`](GAS_PROJECT_INTEGRATION.md)。
