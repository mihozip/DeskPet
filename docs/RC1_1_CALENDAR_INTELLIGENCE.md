# RC1.1 Calendar Intelligence

DeskPet RC1.1 adds a read-only calendar query surface on top of macOS EventKit.

## Goal

Turn Calendar from a write target into a local work-context source without changing the existing confirmation boundary for writes.

## Entry point

Right-click DeskPet and choose `查詢行事曆…`.

Example queries:

- `告訴我今年所有研習講師的行程`
- `下個月有哪些研習`
- `九月在台中的研習`
- `今年 AI 行程`

Queries without an explicit date range default to the current calendar year.

## Query pipeline

```text
Natural language
  ↓
CalendarQueryParser
  ↓
Date range / category / location / keywords
  ↓
CalendarQueryService (EventKit read)
  ↓
CalendarQueryMatcher
  ↓
Date-sorted local result list
```

## Lecturer matching

RC1.1 intentionally uses deterministic local rules instead of sending event content to an LLM.

Positive presenter signals include:

- `講師`
- `主講`
- `授課`
- `演講`
- `分享者`

Training context signals include `研習`, `課程`, `工作坊`, `講座`, `增能`, and `研修`.

Attendee signals such as `參加`, `報名`, `學員`, and `受訓` exclude an event from lecturer results.

For best precision, put an explicit role marker such as `[講師]` in the event title or `角色：講師` in Notes.

## Permissions and privacy

- Existing event creation continues to use the write permission path.
- Full event access is requested only when a Calendar Intelligence query is performed.
- Event title, location, notes, and calendar name are filtered locally.
- RC1.1 does not send Calendar event content to Gemini.
- Calendar Intelligence does not modify events.
- Google Calendar events are available only if that account/calendar is already visible to macOS Calendar / EventKit.

## Compatibility

RC1.1 keeps the project minimum at macOS 13. macOS 14+ uses EventKit's full-access API; macOS 13 uses the legacy EventKit authorization API.
