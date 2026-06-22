// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the pure date/time merge helper used by the setup screen
// (spec 0008, req 4.1: see and edit the date and time).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/presentation/date_time_merge.dart';

void main() {
  final base = DateTime(2026, 6, 21, 14, 30, 45, 123);

  test('merges a new date with a new time', () {
    final merged = mergeDateTime(
      base,
      date: DateTime(2026, 12, 24),
      hour: 9,
      minute: 5,
    );
    expect(merged, DateTime(2026, 12, 24, 9, 5, 45, 123));
  });

  test('changing only the time keeps the date', () {
    final merged = mergeDateTime(base, hour: 8, minute: 0);
    expect(merged, DateTime(2026, 6, 21, 8, 0, 45, 123));
  });

  test('changing only the date keeps the time', () {
    final merged = mergeDateTime(base, date: DateTime(2027, 1, 2));
    expect(merged, DateTime(2027, 1, 2, 14, 30, 45, 123));
  });

  test('no date and no time returns the base moment unchanged', () {
    expect(mergeDateTime(base), base);
  });

  test('keeps the UTC/local mode of the base moment', () {
    final utcBase = DateTime.utc(2026, 6, 21, 14, 30);
    final merged = mergeDateTime(utcBase, hour: 7, minute: 15);
    expect(merged.isUtc, isTrue);
    expect(merged, DateTime.utc(2026, 6, 21, 7, 15));
  });
}
