# Google Apps Script Gateway Setup

DeskPet's GAS integration is optional. The public repository contains no private Spreadsheet ID, deployment URL or API token.

For an existing Spreadsheet or Apps Script system, also read [`GAS_PROJECT_INTEGRATION.md`](GAS_PROJECT_INTEGRATION.md) for the schema mapping and API contract.

## 1. Prepare a Google Spreadsheet

Create or choose a Spreadsheet for DeskPet. It may be blank: the initialization function can create the required `任務清單`, `工作紀錄` and `系統設定` sheets and their headers. If a same-named sheet already contains data, initialization validates its headers instead of silently rewriting them.

## 2. Create a standalone Apps Script project

Copy `GAS/DeskPet_GAS_API_Gateway_v3.js` into a standalone Google Apps Script project.

Do not paste your Spreadsheet ID or token into the source file.

## 3. Configure Script Properties

Open **Project Settings → Script Properties** in Apps Script and add:

```text
DESKPET_SPREADSHEET_ID = your Spreadsheet ID
```

Then run `initializeDeskPetGateway()` once from the Apps Script editor. It validates / creates the required sheets and generates `DESKPET_API_TOKEN` if one does not exist.

Return to **Project Settings → Script Properties**, copy the `DESKPET_API_TOKEN` value into DeskPet, and keep it private. Do not post it in GitHub Issues or commit it to source control.

You can check configuration without revealing the token by running `getDeskPetGatewayStatus()`.

To rotate the token, run `resetDeskPetApiToken()` and then copy the new value from Script Properties. The previous token becomes invalid immediately.

## 4. Deploy as Web App

Deploy the standalone Gateway as a Web App:

- Execute as: yourself
- Access: the deployment mode required for DeskPet's HTTP client (commonly anyone with the URL, depending on Workspace policy)

The endpoint is public at the network layer, so the API token is the application-level authorization control. Treat both the deployment URL and token as sensitive configuration.

## 5. Configure DeskPet

In DeskPet → Settings → Integration:

- enable GAS integration
- paste the `/exec` deployment URL
- save the API token
- test the connection

The URL is stored in `UserDefaults`; the token is stored in macOS Keychain.

## API actions

Gateway v3 supports:

- `ping`
- `createTask`
- `taskDigest`
- `updateTask`

Create calls use `clientTaskId` for idempotency. Update calls allow only a constrained field set.
