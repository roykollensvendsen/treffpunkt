// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Tests for the compact message-time format (spec 0065): time only today, the
// day and month earlier this year, and the full date in an earlier year.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/message_time.dart';

void main() {
  final now = DateTime(2026, 6, 30, 18, 5);

  test('today shows only the time', () {
    expect(formatMessageTime(DateTime(2026, 6, 30, 9, 7), now: now), '09:07');
  });

  test('earlier this year shows day, month and time', () {
    expect(
      formatMessageTime(DateTime(2026, 3, 4, 14, 32), now: now),
      '04.03 14:32',
    );
  });

  test('an earlier year shows the full date', () {
    expect(
      formatMessageTime(DateTime(2025, 12, 24, 8), now: now),
      '24.12.2025 08:00',
    );
  });
}
