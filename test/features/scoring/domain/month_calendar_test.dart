// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the calendar date helpers (spec 0038): the day key strips the
// time, and the month grid is a Monday-first 6-week block covering the month.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/month_calendar.dart';

void main() {
  test('dateKey strips the time to local midnight', () {
    final key = dateKey(DateTime(2026, 6, 21, 14, 35, 9));
    expect(key, DateTime(2026, 6, 21));
    expect(key.hour, 0);
    expect(key.minute, 0);
  });

  test('monthGrid has 42 cells and starts on a Monday', () {
    final grid = monthGrid(DateTime(2026, 6, 15));
    expect(grid, hasLength(42));
    expect(grid.first.weekday, DateTime.monday);
    // Every cell is midnight (a dateKey).
    expect(grid.every((d) => d.hour == 0 && d.minute == 0), isTrue);
  });

  test('monthGrid covers every day of the month', () {
    for (final month in <DateTime>[
      DateTime(2026, 6), // 30 days, the 1st is a Monday
      DateTime(2026, 7), // 31 days
      DateTime(2026, 2), // 28 days
      DateTime(2024, 2), // 29 days (leap)
    ]) {
      final grid = monthGrid(month);
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      for (var day = 1; day <= daysInMonth; day++) {
        expect(
          grid.contains(DateTime(month.year, month.month, day)),
          isTrue,
          reason: 'grid for ${month.year}-${month.month} misses day $day',
        );
      }
    }
  });

  test('monthGrid starts on or before the 1st and spans it', () {
    final grid = monthGrid(DateTime(2026, 6)); // June 1 2026 is a Monday
    expect(grid.first, DateTime(2026, 6)); // no leading days needed
    final jan = monthGrid(DateTime(2027)); // Jan 1 2027 is a Friday
    expect(jan.first, DateTime(2026, 12, 28)); // the Monday before
    expect(jan.contains(DateTime(2027)), isTrue);
  });
}
