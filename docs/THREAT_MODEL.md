# DeskPet lightweight threat model

This is a practical pre-1.0 threat model for contributors and reviewers.

## Assets to protect

- Gemini API Key
- GAS API Token
- target Spreadsheet ID / deployment URL
- Inbox and Work Diary contents
- Calendar / Reminders data
- integrity of formal GAS tasks

## Trust boundaries

```text
macOS local process
  ├─ Keychain
  ├─ local JSON / UserDefaults
  ├─ EventKit / Speech
  ├─ Google Gemini API (optional external service)
  └─ public GAS Web App endpoint (optional external service)
                                  ↓
                              Google Sheet
```

## Main threats and controls

### Credential leakage

Risk: secrets copied into source, diagnostics, logs or Issues.

Controls: Keychain / Script Properties, public-repo scanner, sanitized diagnostics, documentation warnings.

### Unauthorized GAS writes

Risk: a leaked GAS token can authorize requests to a public Web App deployment.

Controls: HTTPS, per-install token, constant-time token comparison, field allow-listing, token rotation, no task data from public GET.

Residual risk: token possession is sufficient authorization. Treat the token as a password.

### Accidental or AI-driven destructive actions

Risk: an interpretation error modifies a real task, Calendar event or Reminder.

Controls: proposal → preview → explicit human confirmation; restricted GAS update fields; Duplicate Guard never silently merges or deletes.

### Duplicate writes

Risk: retries create multiple tasks.

Controls: stable `clientTaskId` idempotency plus semantic Duplicate Guard for separate but similar captures.

### Sensitive text sent to Gemini

Risk: captured work text can include personal or confidential content.

Controls: Gemini is opt-in and the privacy notes identify the transmission boundary. Contributors should not expand AI transmission scope implicitly.

## Out of scope for pre-1.0

- multi-user authorization inside the macOS app
- enterprise MDM policy enforcement
- end-to-end encryption of Google Sheet contents
- server-grade rate limiting beyond Apps Script / Google quotas
