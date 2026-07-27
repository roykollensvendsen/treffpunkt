// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';

void main() {
  group('DryFireEntry (spec 0161)', () {
    // Local wall-clock, as the app records it (DateTime.now()); the wire form
    // is UTC and reads back local, so a local original round-trips to itself.
    final entry = DryFireEntry(
      id: 'abc',
      recordedAt: DateTime(2026, 7, 27, 9, 30),
      discipline: DryFireDiscipline.duell,
      triggerPulls: 25,
    );

    test('toJson/fromJson round-trips losslessly', () {
      expect(DryFireEntry.fromJson(entry.toJson()), entry);
    });

    test('discipline is stored as its stable wireName', () {
      expect(entry.toJson()['discipline'], 'duell');
    });

    test('an unknown discipline wireName throws from fromJson', () {
      final json = entry.toJson()..['discipline'] = 'skarpskyting';
      expect(() => DryFireEntry.fromJson(json), throwsFormatException);
    });

    test('a malformed map throws from fromJson', () {
      expect(
        () => DryFireEntry.fromJson(const {'id': 'x'}),
        throwsA(anything),
      );
    });

    test('fromWireName maps both disciplines', () {
      expect(
        DryFireDiscipline.fromWireName('presisjon'),
        DryFireDiscipline.presisjon,
      );
      expect(
        DryFireDiscipline.fromWireName('duell'),
        DryFireDiscipline.duell,
      );
    });
  });
}
