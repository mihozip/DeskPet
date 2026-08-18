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

1. Current Calendar event is context, not a task mutation.
2. Overdue, due-today, and high-priority active tasks are preferred for **Now**.
3. A nearby Calendar event and remaining actionable tasks populate **Next**.
4. Waiting tasks, later Calendar events, remaining work, and stale Inbox items populate **Later**.
5. Snoozed tasks stay out of all three buckets until the snooze expires.
6. The same source item may appear in only one bucket in a snapshot.

The headline is also deterministic. A current event wins first; an event within 90 minutes can shape the recommendation; otherwise the highest-ranked actionable task becomes the suggested focus.

## Calendar boundary

RC1.2 reuses `CalendarQueryService` through a concrete interval-read API. Calendar contents remain local to the Mac and are not sent to Gemini. Calendar read failure is non-fatal: the context view falls back to GAS tasks, Inbox, WorkEvents, and snooze state.

The Settings permission flow remains the only place that requests Calendar authorization.

## Safety and persistence

- No new persistent task database.
- No automatic Calendar, Reminders, or GAS writes.
- Existing human-confirmation gates remain unchanged.
- No Calendar event content is sent to Gemini.
- Existing Inbox, WorkEvent, GAS Dashboard, and snooze formats are unchanged.

## UI

The existing Today Work surface keeps its current task summary and detailed actionable list. RC1.2 adds a context layer above them:

```text
白帥帥情境：現在最值得處理：確認採購公告

[ 現在 ]        [ 接著 ]        [ 稍後 ]
高優先工作       11:00 行政會議   等廠商估價
...              ...             ...
```

This intentionally separates **orientation** (Work Context) from **mutation** (the existing task interaction flow).
