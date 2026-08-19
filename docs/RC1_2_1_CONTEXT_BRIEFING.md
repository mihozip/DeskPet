# DeskPet RC1.2.1 — Context Briefing

RC1.2.1 makes the RC1.2 Work Context visible without requiring the user to open Today Work first. The new `WorkContextBriefingService` evaluates the same deterministic `WorkContextEngine` snapshot and surfaces one low-noise desktop recommendation when the context changes enough to matter.

**Release target:** `v1.2.1.0` / `DeskPet-1.2.1.0.zip`.

## User experience

A desktop bubble titled `白帥帥建議` may appear beside the pet. The bubble contains the same deterministic context headline used by Today Work, for example:

```text
11:00 有「行政會議」，先處理「確認採購公告」
```

Clicking the bubble dismisses it and opens Today Work, where the full Now / Next / Later context is available.

Today Work is no longer hidden when GAS is not linked. Inbox and local Calendar alone can provide useful context; GAS tasks are included when the optional integration is available.

## Low-noise trigger policy

Context Briefing is intentionally event-driven rather than a repeating reminder.

1. **First useful context of the day** — one briefing when DeskPet first has something meaningful to show that day.
2. **Upcoming timed Calendar event** — one briefing when a non-all-day event is 10–60 minutes away. The same event is not briefed twice that day.
3. **Completion changes focus** — a completed task may immediately produce a new briefing when the top Now item changes.
4. **Other focus changes** — require a 30-minute cooldown after the previous briefing.
5. **Manual refresh** — may explicitly show the current headline again.

The service refreshes local Calendar context every 15 minutes. Source changes from GAS digest, Inbox, WorkEvents or Snooze trigger a debounced local reevaluation.

## Persistence

Context Briefing stores only delivery-control metadata in `UserDefaults`:

- last briefing day
- last briefing timestamp
- last announced context signature
- last upcoming Calendar event ID announced that day

It does not persist a second task database, Calendar copy, or Work Context snapshot.

## Privacy and safety

- Work Context and Context Briefing are read-only.
- Calendar event content remains local to EventKit and is not sent to Gemini.
- Calendar read failure is non-fatal; DeskPet continues with GAS, Inbox, WorkEvents and Snooze data.
- The briefing never performs Calendar, Reminders or GAS writes.
- Existing human-confirmation boundaries remain unchanged.

## Display precedence

When a Context Briefing is visible, it takes precedence over the older GAS ambient summary bubble so DeskPet does not show two competing desktop messages. After it disappears, the existing GAS ambient summary may be shown normally.

## Non-goals

RC1.2.1 does not estimate task duration, infer effort, learn long-term behavior, or persist memory. Those belong to later Context Ranking and Memory milestones.
