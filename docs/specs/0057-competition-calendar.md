# Spec 0057 — Browse competitions by calendar

- **Status:** Accepted
- **Related:** spec 0010 (competitions), spec 0038 (the "Mine økter" calendar,
  whose date helpers this reuses). A forum feature request.

## Context
A user asked to be able to **filter competitions through a calendar**.
Competitions had no date of their own (only a created-at), so this adds an
optional **event date** to a competition and a calendar to browse the list by it.

## Requirements
1. When creating a competition, the owner can set an **optional date** (when it
   is held). A competition without a date simply has none.
2. The competitions list has a **calendar** (toggled from the app bar): days
   that have a competition are dotted; tapping a day **filters** the active list
   to that day's competitions; tapping the selected day again — or "Vis alle" —
   clears the filter.
3. The date and filter never affect any permission; a competition with no date
   is shown when no day is filtered.

## Rationale
**A nullable `event_date` column + the existing calendar maths.** The date is
optional view metadata, so a plain nullable `date` column on `competitions` is
enough — no policy change. The list filter reuses `month_calendar.dart`'s pure
date helpers (`dateKey`, `firstOfMonth`, `monthGrid`) already proven by "Mine
økter", and a small `_CompetitionCalendar` widget mirrors that calendar's look
(the two could later share one widget; kept separate here to avoid touching the
sessions screen).

## Design
- Migration: `alter table public.competitions add column event_date date`.
- `Competition.eventDate` (date-only `DateTime?`); `fromJson` reads
  `event_date`; `toInsertJson` sends it as `YYYY-MM-DD` only when set.
- Create form: an optional date `ListTile` opening `showDatePicker`
  (`competitionDateFieldKey`), with a clear action.
- `CompetitionsScreen` becomes stateful: an app-bar calendar toggle
  (`competitionCalendarToggleKey`); a `_CompetitionCalendar` (dots on days with
  a competition, month nav, tap-to-select / tap-again-to-clear); a "Vis alle"
  clear (`competitionCalendarClearKey`); the active list is filtered to the
  selected day by `dateKey(eventDate) == selectedDay`.

## Verification
### Unit tests
- `Competition.fromJson` reads `event_date`; `toInsertJson` includes it as
  `YYYY-MM-DD` when set and omits it when null.

### System tests
- Two competitions (one dated this month, one undated): both show; opening the
  calendar and tapping the dated day shows only it; "Vis alle" restores both.
- The create form offers the optional date field.

## Open questions
- A future step could share one calendar widget between competitions and "Mine
  økter", and add a list-card date badge or month grouping.
