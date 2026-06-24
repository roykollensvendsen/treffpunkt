<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0038 — Calendar view of "Mine økter"

- **Status:** Accepted
- **Related:** spec 0026 (My sessions list), spec 0008 (session date/place),
  spec 0033 (delete a session)

## Context

"Mine økter" is a flat list, newest first (spec 0026). The NSF domain expert
asked to **find sessions back via a calendar** — an in-app month view (not a
device/Google-calendar export). Sessions already carry a date
(`SessionRecord.capturedAt`), so this is pure presentation: no backend, no
migration, no new dependency (a small custom month grid rather than a calendar
package, keeping dependencies lean).

## Requirements

1. **Toggle.** An app-bar action switches "Mine økter" between the list (default,
   unchanged) and a calendar.
2. **Marked days.** The calendar shows a Monday-first month grid; a day with one
   or more sessions is marked with a dot.
3. **Tap a day.** Selecting a day shows that day's sessions below the grid (the
   same cards as the list, including delete); a day with none shows a short hint.
4. **Navigate months.** Previous/next chevrons page the month; the view opens on
   the newest session's month.
5. **No regression.** Sessions without a recorded date stay visible in the list
   view; they are simply not placed on the calendar.

## Design

- **Pure date helpers** (`lib/features/scoring/domain/month_calendar.dart`):
  `dateKey(DateTime)` (local midnight, the per-day grouping key) and
  `monthGrid(anchor)` (the 42-cell, 6-week, Monday-first block covering the
  month). Pure Dart, unit-tested.
- **`MySessionsScreen`** becomes a `ConsumerStatefulWidget` holding the
  view mode, visible month and selected day (the month/day default to the newest
  dated session). The calendar body is a `SingleChildScrollView` of a
  `_SessionCalendar` (header + weekday row + grid; dots on days with sessions,
  the selected day highlighted) plus the selected day's existing `_SessionCard`s
  (reused from spec 0033) or a `noSessionsOnDayKey` hint. The list body is
  unchanged.

## Rationale

The date is already on every session and the merge of synced + pending entries is
already computed in `build`, so the calendar is a second rendering of the same
data — grouping by `dateKey` and reusing `_SessionCard`. A custom 42-cell grid is
a few dozen lines and avoids a calendar dependency, consistent with the project's
lean-dependency stance. The default month follows the data (newest session), so
the view opens somewhere useful without depending on the wall clock.

## Verification

### Unit (`month_calendar_test.dart`)
- `dateKey` strips the time; `monthGrid` is 42 cells, starts on the Monday on/
  before the 1st, and covers every day across 30/31/28/29-day months and a year
  boundary.

### Widget (`my_sessions_screen_test.dart`)
- Toggling to the calendar opens on the newest session's month; days with
  sessions are dotted; the selected (newest) day's card shows; tapping another
  dated day shows that day's card; an empty day shows the hint; prev/next paging
  changes the month label; toggling back shows the full list.

### Manual
Open "Mine økter", toggle to the calendar, see marked days, tap one to read that
day's sessions, and page between months.

## Known limitations / next increment

The calendar covers dated sessions only (undated ones remain in the list). No
week/agenda view or jump-to-today control yet; the dot is presence-only (it does
not show a per-day count).
