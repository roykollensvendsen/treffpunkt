// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_weekly_volume.dart';

DryFireEntry _entry(
  DateTime at, {
  DryFireDiscipline discipline = DryFireDiscipline.presisjon,
  int pulls = 10,
}) => DryFireEntry(
  id: '$at-$discipline',
  recordedAt: at,
  discipline: discipline,
  triggerPulls: pulls,
);

void main() {
  group('dryFireWeeklyVolume (spec 0164)', () {
    // Monday 2026-07-27 is the reference "now" week.
    final now = DateTime(2026, 7, 29); // a Wednesday

    test('always returns exactly [weeks] buckets, oldest first', () {
      final weeks = dryFireWeeklyVolume(const [], now: now, weeks: 8);
      expect(weeks, hasLength(8));
      expect(weeks.first.weekStart.isBefore(weeks.last.weekStart), isTrue);
      // The last bucket is the week containing `now` (Monday 2026-07-27).
      expect(weeks.last.weekStart, DateTime(2026, 7, 27));
      expect(weeks.every((w) => w.total == 0), isTrue);
    });

    test('sums the current week per discipline', () {
      final weeks = dryFireWeeklyVolume([
        _entry(DateTime(2026, 7, 27), pulls: 20),
        _entry(DateTime(2026, 7, 29), discipline: DryFireDiscipline.duell, pulls: 15),
        _entry(DateTime(2026, 7, 28), pulls: 5),
      ], now: now);
      final current = weeks.last;
      expect(current.presisjon, 25);
      expect(current.duell, 15);
      expect(current.total, 40);
    });

    test('buckets a previous week separately', () {
      final weeks = dryFireWeeklyVolume([
        _entry(DateTime(2026, 7, 20), pulls: 30), // previous Monday
      ], now: now);
      expect(weeks[weeks.length - 2].total, 30);
      expect(weeks.last.total, 0);
    });

    test('omits entries older than the window', () {
      final weeks = dryFireWeeklyVolume([
        _entry(DateTime(2026, 1, 1), pulls: 99),
      ], now: now, weeks: 4);
      expect(weeks.every((w) => w.total == 0), isTrue);
    });
  });
}
