# DeskPet RC1.2 — Work Context

RC1.2 adds a deterministic work-context layer on top of the existing Daily Work Loop. The goal is not to create another task database, but to answer three practical questions from the information DeskPet already has:

- **Now** — what deserves attention right now?
- **Next** — what should be handled after that?
- **Later** — what should stay visible without interrupting the current focus?

## Data flow

```text
GAS active tasks ─┐
Inbox items ──────┤
WorkEvents ───────┤
Snooze state ─────┼─> WorkContextEngine ─> Now / Next / Later
Local Calendar ───┘
```

`WorkContextEngine` is a pure domain service. It does not persist a second copy of tasks, calendar events, or summaries. Every context snapshot is regenerated from source data.

## Deterministic priority rules

1. A currently active **non-all-day** Calendar event can provide immediate context.
2. Waiting tasks are treated as blocked / deferred context even when their configured priority is high.
3. Overdue, due-today, and high-priority **actionable** tasks are preferred for **Now**.
4. A nearby Calendar event and remaining actionable tasks populate **Next**.
5. Waiting tasks, later Calendar events, remaining work, and stale Inbox items populate **Later**.
6. Snoozed tasks stay out of all three buckets until the snooze expires.
7. The same source item may appear in only one bucket in a snapshot.
8. All-day Calendar events remain visible context but do not replace the active-focus headline for the whole day.

The headline is deterministic. An active non-all-day event wins first; an event within 90 minutes can shape the recommendation; otherwise the highest-ranked actionable task becomes the suggested focus.

## Calendar boundary

RC1.2 reuses `CalendarQueryService` through a concrete interval-read API. Calendar contents remain local to the Mac and are not sent to Gemini.

Calendar read failure is non-fatal: the context view falls back to GAS tasks, Inbox, WorkEvents, and Snooze state. The Settings permission flow remains the only place that requests Calendar authorization.

## Safety and persistence

- No new persistent task database.
- No automatic Calendar, Reminders, or GAS writes.
- Existing human-confirmation gates remain unchanged.
- No Calendar event content is sent to Gemini.
- Existing Inbox, WorkEvent, GAS Dashboard, and Snooze formats are unchanged.
- Work Context prioritization is deterministic and does not require Gemini.

## UI

The existing Today Work surface keeps its current task summary and detailed actionable list. RC1.2 adds a context layer above them:

```text
白帥帥情境：11:00 有「行政會議」，先處理「確認採購公告」

[ 現在 ]        [ 接著 ]        [ 稍後 ]
確認採購公告     11:00 行政會議   等廠商估價
...              ...             ...
```

This intentionally separates **orientation** (Work Context) from **mutation** (the existing task interaction flow).

## Validation

RC1.2 includes deterministic tests covering:

- overdue / due-today / high-priority placement
- waiting tasks staying out of active focus even when high-priority
- active and upcoming Calendar integration
- all-day Calendar events not replacing active focus
- Snooze exclusion
- source-item deduplication across buckets
- latest same-day WorkEvent activity
- full Swift package tests and application build in CI
