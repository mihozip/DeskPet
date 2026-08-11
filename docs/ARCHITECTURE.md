# DeskPet Architecture

This document describes the DeskPet `1.0.0.0` Release Candidate 1 architecture.

## Conceptual flow

```text
Capture → Inbox → Interpret → Confirm → Act → Monitor → Work Diary
```

The components intentionally have different responsibilities rather than mirroring the same data everywhere.

### Inbox — Capture

`CaptureStore` persists raw notes and their interpretation / conversion metadata. An Inbox item can later link to a GAS task, but the original captured text remains historical input.

### GAS Task — Execution

`GASTaskConnector` communicates with the optional standalone Apps Script Gateway. GAS becomes the source of truth for the formal task lifecycle once an Inbox item is converted to a task.

### Work Diary — History

`WorkEventStore` stores append-style events describing actions DeskPet observed: captures, task creation, replies, postponements, completions and manual diary notes.

The diary is intentionally derived from events so future daily / weekly / monthly analysis can be regenerated from original facts.

### Daily Work Loop — Derived views

`DailyWorkService` is a pure domain service. It combines the current GAS digest, pending Inbox items, WorkEvents, local snooze expirations, and an Asia/Taipei clock into `DailyWorkSnapshot`. Today Brief, Waiting Radar, Daily Wrap, Weekly Review, and Pet Work State are derived values and are never persisted as a second task or diary database.

The existing task-digest utility window presents the Daily Work sections. Any row that can mutate a formal task routes into `TaskInteractionViewModel`; only its explicit submit action calls `GASTaskConnector`. A successful connector response is recorded as a WorkEvent, while failure leaves no success event.

## State ownership

- Models: value types and identifiers.
- Stores: local persistence and app-wide observable state.
- Services: external systems and platform APIs.
- Views: SwiftUI presentation.
- Window controllers: AppKit utility-window / floating-panel lifecycle.

## External integrations

### Gemini

Optional. The API key is read from Keychain only at request time. AI interpretation does not itself authorize writes.

### EventKit

Calendar and Reminders are executed by `CalendarActionService` after explicit confirmation.

### GAS

The public Gateway Web App is protected by a per-install token. It is deployed separately from [`school-admin-daily-dashboard`](https://github.com/mihozip/school-admin-daily-dashboard), while both projects operate on the same installed Spreadsheet. This keeps the Dashboard's Workspace login boundary separate from DeskPet's machine API boundary.

Gateway attachment validates the Dashboard's task, log, settings and option sheets without creating or migrating them. The macOS client stores the deployment URL in preferences and the token in Keychain, and caches non-secret integration metadata such as school, office, role, categories and priorities in `UserDefaults`.

### Software update

`SoftwareUpdateService` owns the app-side version check and launches a bundled updater only after validating its marker and size. A bounded line protocol reports validated, monotonic stage percentages to SwiftUI while the app remains open. The updater is an outer delivery adapter: it downloads source with bounded retries, builds and verifies a complete replacement, redirects output to the persistent log, then performs a backup → replace → verify transaction with rollback on failure. User data remains outside the app bundle.

The administrative-title override is local preference policy. `GASTaskConnector` maps it to the `owner` field only when DeskPet creates a task; it does not mutate Dashboard profile configuration.

## Idempotency and duplicates

These solve different problems:

- `clientTaskId`: network / retry idempotency for the same create operation.
- Inbox → Task Link: provenance between capture and formal task.
- Duplicate Guard: semantic warning when different captures appear to describe the same work.

## Persistence

```text
Application Support/DeskPet/inbox.json
Application Support/DeskPet/work-events.json
UserDefaults
macOS Keychain
```

RC1 adds one versioned local `UserDefaults` value containing only task IDs and snooze expiration dates. It does not store task copies or credentials.

Stored models should remain backward-decodable when possible. Any incompatible change should include a migration note in the changelog.
