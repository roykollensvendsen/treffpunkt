// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_weapon.dart';

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

  group('DryFireEntry weapon (spec 0165)', () {
    DryFireEntry withWeapon(DryFireWeapon? weapon) => DryFireEntry(
      id: 'abc',
      recordedAt: DateTime(2026, 7, 27, 9, 30),
      discipline: DryFireDiscipline.presisjon,
      triggerPulls: 25,
      weapon: weapon,
    );

    test('an entry with a weapon round-trips and stores its wireName', () {
      final entry = withWeapon(DryFireWeapon.grovpistol);
      expect(entry.toJson()['weapon'], 'grovpistol');
      expect(DryFireEntry.fromJson(entry.toJson()), entry);
    });

    test('a legacy map with no weapon key parses to no weapon', () {
      final legacy = withWeapon(null).toJson()..remove('weapon');
      final parsed = DryFireEntry.fromJson(legacy);
      expect(parsed.weapon, isNull);
      // Equal to the same entry built without a weapon.
      expect(parsed, withWeapon(null));
    });

    test('a null, non-string or unknown weapon value degrades to null', () {
      // The list store is all-or-nothing: an unreadable weapon must not throw.
      for (final bad in <Object?>[null, 42, 'bueskyting']) {
        final json = withWeapon(DryFireWeapon.finpistol).toJson()
          ..['weapon'] = bad;
        expect(DryFireEntry.fromJson(json).weapon, isNull);
      }
    });

    test('weapon participates in equality and hashCode', () {
      expect(withWeapon(DryFireWeapon.luftpistol), isNot(withWeapon(null)));
      expect(
        withWeapon(DryFireWeapon.luftpistol),
        isNot(withWeapon(DryFireWeapon.finpistol)),
      );
      expect(
        withWeapon(DryFireWeapon.luftpistol).hashCode,
        isNot(withWeapon(DryFireWeapon.finpistol).hashCode),
      );
    });
  });
}
