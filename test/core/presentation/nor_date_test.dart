// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the shared Norwegian date format (specs 0096/0118).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/nor_date.dart';

void main() {
  test('formats dd.MM.yyyy HH:mm (spec 0096)', () {
    expect(norDateTime(DateTime(2026, 7, 2, 21, 5)), '02.07.2026 21:05');
  });

  test('a UTC moment is shown on the local clock (spec 0118)', () {
    final utc = DateTime.utc(2026, 7, 2, 19, 30);
    final local = utc.toLocal();
    expect(norDateTime(utc), norDateTime(local));
    // And the output really is the local wall clock, whatever the zone.
    expect(
      norDateTime(utc),
      '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}',
    );
  });
}
