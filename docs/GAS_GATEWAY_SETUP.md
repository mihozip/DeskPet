# Google Apps Script Gateway Setup

DeskPet 與 [`school-admin-daily-dashboard`](https://github.com/mihozip/school-admin-daily-dashboard) 現在優先採用**同一個 Apps Script 專案、同一份 Spreadsheet、兩個 Web App deployment** 的方式整合。

Dashboard repo 已內建 `DeskPetGateway.gs`，因此一般使用者不再需要建立第二個 Apps Script 專案，也不需要手動設定 `DESKPET_SPREADSHEET_ID`。

## 推薦架構

```text
瀏覽器使用者
   │ Google / Workspace 登入
   ▼
Dashboard Deployment（網域限定）
   │
   ├──────────────┐
   ▼              ▼
同一份 Google Sheet   DeskPet API Deployment（直接 POST）
                      ▲
                      │ HTTPS POST + DESKPET_API_TOKEN
                      │
                   DeskPet macOS App
```

兩個 deployment 使用同一份 Apps Script 原始碼，但權限目的不同：

- Dashboard deployment：給人使用，維持 Workspace／網域登入。
- DeskPet API deployment：給 macOS App 使用，允許直接 POST，並以 `DESKPET_API_TOKEN` 做應用層驗證。

## 快速設定

### 1. 更新 Dashboard Apps Script

依 `school-admin-daily-dashboard` README，把以下檔案放進綁定 Google Sheet 的 Apps Script 專案：

```text
Code.gs
DeskPetGateway.gs
Installer.html
Index.html
Board.html
appsscript.json
```

若 Dashboard 已經安裝，只要把新版 `DeskPetGateway.gs` 加進現有專案即可；不需要換 Spreadsheet。

### 2. 先設定 ALLOWED_DOMAIN

在 Dashboard 的 `系統設定` 工作表設定：

```text
ALLOWED_DOMAIN = 你的學校 Workspace 網域
```

例如：

```text
ALLOWED_DOMAIN = school.edu.tw
```

**同專案模式要建立一個「任何人」可存取的 API deployment，因此這一步不可省略。** 管理台資料仍會經過 Dashboard 的 `assertAuthorized_()`，匿名 API deployment 不應成為管理台資料入口。

### 3. 建立 DeskPet API Token

在 Apps Script 編輯器直接執行：

```javascript
setupDeskPetGateway()
```

它會：

1. 建立或沿用 `DESKPET_API_TOKEN`。
2. 直接使用 Dashboard 已綁定的 Spreadsheet。
3. 驗證 `任務清單`、`工作紀錄`、`系統設定`、`選項清單`。
4. 驗證任務 19 欄與工作紀錄 7 欄契約。
5. 回傳學校、處室、職務與動態選項 metadata。

不再需要：

```text
DESKPET_SPREADSHEET_ID
BOUND_SPREADSHEET_ID 手動複製
第二個 Apps Script 專案
```

### 4. 取得 Token

可從 Apps Script 函式選單執行：

```javascript
showDeskPetApiToken()
```

Token 會顯示在執行記錄，並保存在 Script Properties：

```text
DESKPET_API_TOKEN
```

正常重新部署不需要換 Token。

### 5. 建立 DeskPet API Deployment

在**同一個 Apps Script 專案**選擇：

```text
部署 → 新增部署 → 網頁應用程式
```

建立第二個 deployment，專門給 DeskPet：

- 執行身分：部署者
- 誰可以存取：可讓 DeskPet 不經 Google 登入直接 POST 的模式，通常為「任何人」

部署後會得到另一個 `/exec` URL。

**DeskPet 必須填這個 API deployment URL，不是 Dashboard 管理台 URL。**

如果填到管理台 deployment，Google 會先要求 Workspace 登入，DeskPet 收到的就會是登入頁／HTML，而不是 JSON。

### 6. DeskPet 設定

在 DeskPet「設定 → 校務任務系統（Google Apps Script）」填入：

```text
網址  = DeskPet API deployment 的 /exec URL
Token = DESKPET_API_TOKEN
```

啟用後按「測試連線」。

成功時 DeskPet 會同步：

- 學校名稱
- 處室
- 職務
- 任務類型
- 狀態
- 優先級
- 看板顯示選項

## API Token 管理

查看目前狀態：

```javascript
getDeskPetGatewayStatus()
```

重新顯示／建立 Token：

```javascript
showDeskPetApiToken()
```

強制輪替 Token：

```javascript
resetDeskPetApiToken()
```

`resetDeskPetApiToken()` 會讓舊 Token 立即失效，之後必須同步更新 DeskPet Keychain 中的 Token。

## 常見錯誤

### Web App 回傳登入／HTML 頁面

幾乎都表示 DeskPet 填到了錯誤 deployment：

```text
錯：Dashboard 管理台 /exec URL
對：DeskPet API /exec URL
```

兩者可以來自同一 Apps Script 專案，但 deployment 權限不同。

### HTTP 401 / 403

代表 Google 在 DeskPet API 邏輯執行前就拒絕了請求。重新檢查 DeskPet API deployment 的「誰可以存取」。

### Token 不正確

執行：

```javascript
showDeskPetApiToken()
```

重新複製 `DESKPET_API_TOKEN` 到 DeskPet。

### Dashboard schema 不符合

先在 `school-admin-daily-dashboard` 執行安裝／遷移，確認存在：

```text
任務清單
工作紀錄
系統設定
選項清單
```

再執行：

```javascript
getDeskPetGatewayStatus()
```

## 舊版獨立 Gateway

`DeskPet/GAS/DeskPet_GAS_API_Gateway_v3.js` 仍保留作為**相容與備援模式**。以下情況可繼續使用獨立 Gateway：

- 無法在 Dashboard 同專案建立可直接 POST 的第二個 deployment。
- 不適合設定 `ALLOWED_DOMAIN`。
- Workspace 管理政策禁止同專案的公開 API deployment。

舊版模式仍使用：

```text
DESKPET_SPREADSHEET_ID
DESKPET_API_TOKEN
```

但一般安裝建議改用 Dashboard 內建的 `DeskPetGateway.gs`。

完整架構、契約與處室切換說明見 [`GAS_PROJECT_INTEGRATION.md`](GAS_PROJECT_INTEGRATION.md)。
