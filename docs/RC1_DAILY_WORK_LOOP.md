# DeskPet RC1.0 — Daily Work Loop

Release Candidate version: `1.0.0.0`.

## Product goal

RC1.0 turns the existing capture-and-action workflow into a daily administrative loop:

```text
Capture → Inbox → Interpret → Confirm → Act → Monitor → Work Diary
```

It does not introduce another task database. GAS remains the source of truth for formal tasks, Inbox preserves captured input, and `WorkEvent` remains the append-style historical record.

## Repository audit and reuse

- Task model: `GASTaskDigest.Task` already maps the Dashboard task contract and is reused by every RC view.
- Capture / Inbox: `CaptureItem` and `CaptureStore` remain unchanged and backward-decodable.
- Work history: `WorkEvent` and `WorkEventStore` remain the sole diary/event stream.
- GAS: `GASTaskConnector`, `taskDigest`, `updateTask`, token validation and `clientTaskId` idempotency are reused.
- Ambient Agent: `GASTaskAmbientMonitor` remains the only background task reader and now requests up to 30 digest candidates.
- Natural Action: the local/Gemini interpreters still create proposals only; `TaskInteractionViewModel` still owns confirmed execution.
- Workbench UI: the existing task-digest utility window is now the Daily Work surface. No new dashboard database or independent window family was added.
- Settings / persistence: local snoozes use one versioned `UserDefaults` value; credentials remain in Keychain.
- Pet state: the existing interaction `PetState` remains intact. `PetWorkState` is a separate derived work signal mapped to existing visuals and a status badge.
- Release/update: existing rollback-aware updater behavior is unchanged; release scripts package version `1.0.0.0` as `DeskPet-1.0.0.0.zip`.

## Derived domain

`DailyWorkService` builds a `DailyWorkSnapshot` from:

- active `GASTaskDigest.Task` values;
- pending `CaptureItem` values;
- raw `WorkEvent` values;
- local snooze expirations;
- an explicit current date and Asia/Taipei calendar.

The snapshot contains `TodayBrief`, `WaitingItem`, `DailyWrap`, `WeeklyReview`, and `PetWorkState`. None are persisted.

### Deterministic priority

Candidate tiers are ordered:

1. overdue;
2. due today;
3. high priority;
4. waiting;
5. normal.

Ties use deadline, priority, update time, task name, and task ID. The Gateway digest comparator follows the same tier order before the macOS domain performs its final deterministic sort.

## Today Brief

The existing work-summary window is presented as **今日工作** and shows date, overdue, due-today, high-priority, waiting, and pending-Inbox counts. It recommends at most five tasks. Opening or starting a task is read-only until the user selects and confirms a mutation in the existing task interaction window.

Gemini is not used to calculate facts or sorting. The complete surface works without an API key.

## Next Action

`updateTask` now allow-lists `nextAction`, mapped to the existing Dashboard column `下一步行動`; the 19-column schema is unchanged.

Natural language containing `下一步` or `接下來` can create a local `updateProgress` proposal with separate progress and next-action values. Gemini supports the same optional proposal, but the local interpreter is the fallback and core implementation.

The write boundary remains:

```text
interpret → draft → confirmation view → GASTaskConnector.updateTask → success → WorkEvent
```

No draft writes remotely. A failed remote update does not append a success event.

## Waiting Radar

A task is included when `waitingFor` is non-empty or its status/flags indicate waiting. The radar shows waiting target, age, deadline, and recent progress, and offers confirmed follow-up, waiting-target change, waiting release, task view, and local snooze actions.

Waiting age first uses a matching waiting-entry `WorkEvent` when that event is unambiguous. Otherwise it uses `task.updatedAt`.

> RC1.0 waiting age is a heuristic when no explicit event exists. It is not presented as an exact workflow timestamp.

## Daily Wrap and Weekly Review

Both reviews are regenerated from raw `WorkEvent` values on every render. They never write AI summaries into the event stream.

- Daily Wrap uses the Asia/Taipei day boundary and counts completed, progressed, waiting, created, and captured events.
- Weekly Review covers Monday 00:00 through the current Taipei day and exposes results, active work, long waits, and next priorities.

## Pet Work State

`PetWorkState` is calculated centrally by `DailyWorkService`:

- overdue or due today → `attention`;
- otherwise waiting at least three days → `waiting`;
- otherwise a completed event today with no high-priority work → `success`;
- otherwise active work → `normal`;
- no work → `idle`, or `sleep` during rest hours.

This state only changes visual feedback. It never performs a task mutation.

## Snooze

`SnoozeStore` saves only `taskID` and `snoozedUntil` locally in versioned `UserDefaults`. Active snoozes remove a task from Today Brief and Waiting Radar. Expired values become eligible again and can be purged safely. Snooze never changes a task deadline or writes to GAS.

## Explicitly deferred

Gmail, Google Drive, document AI, Android, a plugin marketplace, autonomous execution, auto-completion, auto-merging, background AI writes, and Dashboard schema expansion remain post-1.0 work.
