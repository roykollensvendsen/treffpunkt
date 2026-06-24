// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Pure date helpers for the "Mine økter" calendar view (spec 0038).
///
/// No Flutter imports — the grid maths and the day key are plain Dart, so they
/// are unit-testable in isolation.
library;

/// The local date-only key for [moment]: midnight on its local year/month/day.
///
/// Sessions are grouped and compared by this, so two times on the same local
/// day share one key regardless of the hour or the source time zone.
DateTime dateKey(DateTime moment) {
  final local = moment.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// The first day (date-only) of the month containing [anchor].
DateTime firstOfMonth(DateTime anchor) => DateTime(anchor.year, anchor.month);

/// The 42 day cells (6 weeks × 7) of [anchor]'s month, Monday-first.
///
/// Starts on the Monday on or before the 1st of the month and runs 42 days, so
/// the grid always covers the whole month with leading/trailing days from the
/// adjacent months. Every entry is a [dateKey] (midnight, local). Monday-first
/// matches the Norwegian week.
List<DateTime> monthGrid(DateTime anchor) {
  final first = firstOfMonth(anchor);
  // DateTime.weekday is 1 (Mon) … 7 (Sun); offset back to the Monday on/before.
  final leading = first.weekday - DateTime.monday;
  final start = first.subtract(Duration(days: leading));
  return <DateTime>[
    for (var i = 0; i < 42; i++)
      DateTime(start.year, start.month, start.day + i),
  ];
}
