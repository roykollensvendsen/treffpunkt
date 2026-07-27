// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';

/// One week's dry-fire trigger-pull volume, split by discipline (spec 0164).
@immutable
class DryFireWeek {
  /// Creates a week bucket starting on [weekStart] (a Monday, date-only).
  const DryFireWeek({
    required this.weekStart,
    required this.presisjon,
    required this.duell,
  });

  /// The Monday the week starts on (date-only).
  final DateTime weekStart;

  /// Trigger pulls on the precision target that week.
  final int presisjon;

  /// Trigger pulls on the duel target that week.
  final int duell;

  /// Total trigger pulls that week.
  int get total => presisjon + duell;
}

/// The Monday (date-only) of the week containing [date].
DateTime dryFireWeekStart(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  final monday = day.subtract(Duration(days: day.weekday - 1));
  return DateTime(monday.year, monday.month, monday.day);
}

/// The trigger-pull volume per week for the last [weeks] weeks ending at the
/// week containing [now], oldest first (spec 0164).
///
/// A pure fold: entries outside the window are omitted; empty weeks are kept as
/// zero buckets so the series is always [weeks] long and evenly spaced.
List<DryFireWeek> dryFireWeeklyVolume(
  Iterable<DryFireEntry> entries, {
  required DateTime now,
  int weeks = 8,
}) {
  final currentMonday = dryFireWeekStart(now);
  final starts = <DateTime>[
    for (var back = weeks - 1; back >= 0; back--)
      dryFireWeekStart(currentMonday.subtract(Duration(days: 7 * back))),
  ];
  final presisjon = <DateTime, int>{for (final start in starts) start: 0};
  final duell = <DateTime, int>{for (final start in starts) start: 0};

  for (final entry in entries) {
    final start = dryFireWeekStart(entry.recordedAt);
    if (!presisjon.containsKey(start)) continue;
    switch (entry.discipline) {
      case DryFireDiscipline.presisjon:
        presisjon[start] = presisjon[start]! + entry.triggerPulls;
      case DryFireDiscipline.duell:
        duell[start] = duell[start]! + entry.triggerPulls;
    }
  }

  return <DryFireWeek>[
    for (final start in starts)
      DryFireWeek(
        weekStart: start,
        presisjon: presisjon[start]!,
        duell: duell[start]!,
      ),
  ];
}
