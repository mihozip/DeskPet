# DeskPet Architecture

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

The public Web App is protected by a per-install token. The macOS client stores the deployment URL in preferences and the token in Keychain.

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

Stored models should remain backward-decodable when possible. Any incompatible change should include a migration note in the changelog.
