# DeskPet Architecture

This document describes the DeskPet `1.2.0.0` RC1.2 architecture.

## Conceptual flow

```text
Observe / Capture / Query
        ↓
Inbox / Calendar / GAS / WorkEvents
        ↓
Interpret + Work Context
        ↓
Prioritize / Recommend
        ↓
Confirm writes / Display read-only results
        ↓
Calendar / Reminders / GAS Task
        ↓
Monitor
        ↓
Work Diary
```

The components intentionally have different responsibilities rather than mirroring the same data everywhere.

## Capture and source data

### Inbox — Capture

`CaptureStore` persists raw notes and interpretation / conversion metadata. An Inbox item can later link to a GAS task, but the original captured text remains historical input.

### GAS Task — Execution source of truth

`GASTaskConnector` communicates with the optional standalone Apps Script Gateway. GAS becomes the source of truth for the formal task lifecycle once an Inbox item is converted into a task.

### Calendar — Local context

`CalendarQueryService` reads EventKit events only after readable Calendar access is already granted through Settings. Calendar Intelligence performs local natural-language filtering. RC1.2 also exposes an interval-based read path so Work Context can consume upcoming local events without routing them through Gemini.

### Work Diary — History

`WorkEventStore` stores append-style events describing actions DeskPet observed: captures, task creation, replies, postponements, completions and manual diary notes.

The diary is intentionally derived from events so future daily / weekly / monthly analysis can be regenerated from original facts.

## Daily Work Loop — Derived views

`DailyWorkService` is a pure domain service. It combines the current GAS digest, pending Inbox items, WorkEvents, local snooze expirations, and an Asia/Taipei clock into `DailyWorkSnapshot`.

Today Brief, Waiting Radar, Daily Wrap, Weekly Review, and Pet Work State are derived values and are never persisted as a second task or diary database.

The task-digest utility window presents the Daily Work sections. Any row that can mutate a formal task routes into `TaskInteractionViewModel`; only its explicit submit action calls `GASTaskConnector`. A successful connector response is recorded as a WorkEvent, while failure leaves no success event.

## RC1.2 Work Context

`WorkContextEngine` is another pure domain service layered above the existing Daily Work Loop. It combines:

- active GAS tasks
- pending Inbox items
- WorkEvents
- local Snooze state
- local Calendar events

and regenerates a `WorkContextSnapshot` with:

- `Now`
- `Next`
- `Later`
- deterministic focus headline
- current / next Calendar event references
- latest WorkEvent activity for the current day

No Work Context snapshot is persisted as a new database.

### Priority rules

1. Active non-all-day Calendar events may provide current context.
2. Waiting tasks are treated as blocked / deferred context even if their task priority is high.
3. Overdue, due-today and high-priority actionable tasks are preferred for `Now`.
4. Nearby Calendar events and remaining actionable tasks populate `Next`.
5. Waiting tasks, later Calendar events, remaining work and stale Inbox items populate `Later`.
6. Snoozed tasks stay out of all buckets until the snooze expires.
7. A source item appears in at most one bucket per snapshot.
8. All-day events remain visible context but do not replace the active-focus headline.

Calendar read failure is non-fatal. The engine falls back to GAS tasks, Inbox, WorkEvents and Snooze state.

See [`RC1_2_WORK_CONTEXT.md`](RC1_2_WORK_CONTEXT.md) for the detailed RC1.2 contract.

## State ownership

- Models: value types and identifiers.
- Stores: local persistence and app-wide observable state.
- Services: domain logic, external systems and platform APIs.
- Views: SwiftUI presentation.
- Window controllers: AppKit utility-window / panel lifecycle.

## External integrations

### Gemini

Optional. The API key is read from Keychain only at request time. AI interpretation does not itself authorize writes.

Gemini is used for selected interpretation / structured-output workflows, not for Work Context prioritization or Calendar event analysis. Model IDs are restricted to verified first-party Gemini API identifiers; see [`GEMINI_MODELS.md`](GEMINI_MODELS.md).

### EventKit

Settings is the single authorization entry point. Calendar and Reminders remain separate permission paths.

Read-only Calendar Intelligence and Work Context use EventKit reads. Calendar and Reminders write operations continue through `CalendarActionService` after explicit confirmation.

### GAS

The public Gateway Web App is protected by a per-install token. It is deployed separately from [`school-admin-daily-dashboard`](https://github.com/mihozip/school-admin-daily-dashboard), while both projects operate on the same installed Spreadsheet.

This keeps the Dashboard Workspace login boundary separate from DeskPet's machine API boundary.

Gateway attachment validates the Dashboard task, log, settings and option sheets without creating or migrating them. The macOS client stores the deployment URL in preferences and the token in Keychain, and caches non-secret integration metadata such as school, office, role, categories and priorities in `UserDefaults`.

## Software update

`SoftwareUpdateService` owns the app-side version check and launches a bundled updater only after validating its marker and size. A bounded line protocol reports validated, monotonic stage percentages to SwiftUI while the app remains open.

The updater downloads source with bounded retries, builds and verifies a complete replacement, redirects output to the persistent log, then performs a backup → replace → verify transaction with rollback on failure. User data remains outside the app bundle.

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

Snooze stores only task IDs and expiration dates locally. Work Context adds no new persistent source-of-truth store.

Stored models should remain backward-decodable when possible. Any incompatible change should include a migration note in the changelog.
