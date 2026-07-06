// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the wire-timestamp parser (spec 0118): every timestamp
// entering the app becomes phone-local at the boundary.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/time/wire_time.dart';

void main() {
  test('a UTC wire timestamp becomes local (spec 0118)', () {
    final parsed = parseWireTime('2026-07-02T19:30:00.000Z');
    expect(parsed.isUtc, isFalse);
    // Same instant, local clock.
    expect(
      parsed.millisecondsSinceEpoch,
      DateTime.utc(2026, 7, 2, 19, 30).millisecondsSinceEpoch,
    );
  });

  test('an offset carries through to the same instant', () {
    final parsed = parseWireTime('2026-07-02T21:30:00+02:00');
    expect(parsed.isUtc, isFalse);
    expect(
      parsed.millisecondsSinceEpoch,
      DateTime.utc(2026, 7, 2, 19, 30).millisecondsSinceEpoch,
    );
  });

  test('an offset-less local string keeps its wall clock', () {
    final parsed = parseWireTime('2026-07-02T21:30:00');
    expect(parsed.isUtc, isFalse);
    expect(parsed.hour, 21);
    expect(parsed.minute, 30);
  });

  group('parseWireTimeOrNull', () {
    test('a missing timestamp stays null', () {
      expect(parseWireTimeOrNull(null), isNull);
    });

    test('a present timestamp parses exactly like parseWireTime', () {
      const wire = '2026-07-02T19:30:00.000Z';
      expect(parseWireTimeOrNull(wire), parseWireTime(wire));
    });
  });

  group('formatWireTimeUtc', () {
    test('a null instant stays null', () {
      expect(formatWireTimeUtc(null), isNull);
    });

    test('a local instant is written as the same instant in UTC', () {
      final local = DateTime.utc(2026, 7, 2, 19, 30).toLocal();
      expect(formatWireTimeUtc(local), '2026-07-02T19:30:00.000Z');
    });

    test('a UTC instant is written unchanged', () {
      expect(
        formatWireTimeUtc(DateTime.utc(2026, 7, 2, 19, 30)),
        '2026-07-02T19:30:00.000Z',
      );
    });

    test('round-trips through parseWireTimeOrNull to the same instant', () {
      final original = DateTime.utc(2026, 7, 2, 19, 30).toLocal();
      final back = parseWireTimeOrNull(formatWireTimeUtc(original));
      expect(back, original);
    });
  });
}
