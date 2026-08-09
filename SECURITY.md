# Security Policy

## Supported version

The pre-1.0 branch is under active development. Security fixes should target the latest tagged release candidate.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting / Security Advisory flow when available. Do **not** disclose exploitable issues or secrets in a public Issue.

Never include real:

- Gemini API keys
- `DESKPET_API_TOKEN` values
- private GAS `/exec` URLs
- Spreadsheet IDs
- private Inbox / Diary data

## Security model

DeskPet relies on several explicit boundaries:

1. Gemini and GAS credentials are stored in macOS Keychain.
2. The standalone GAS Gateway keeps its token and target Spreadsheet ID in Apps Script Script Properties.
3. Gateway `GET` returns health status only; task data requires authenticated `POST`.
4. GAS task updates are allow-listed to a limited set of fields.
5. Calendar, Reminders and task mutations require human confirmation in the app.
6. `clientTaskId` provides idempotency for create operations; Duplicate Guard is an additional UX-level duplicate warning, not a security control.

## Known operational risks

- Anyone who obtains the GAS token can call the public Web App endpoint with that token. Rotate the token immediately if it leaks.
- Google Apps Script is not a high-throughput API gateway and is subject to Google quotas.
- User-entered task text may contain confidential information. Enabling Gemini can transmit selected text to an external API.
- Ad-hoc signed builds are for local testing only. Public binary distribution should use Developer ID, Hardened Runtime and Apple notarization.
- Source updates trust the public `mihozip/DeskPet` main branch and the local Apple Swift toolchain. Review the downloaded updater in managed environments and keep the GitHub account protected with strong authentication.

A lightweight repository threat model is maintained at [`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md).
