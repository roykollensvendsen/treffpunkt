// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_totals.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_weapon.dart';

DryFireEntry _entry(
  DryFireDiscipline discipline,
  int pulls, {
  DryFireWeapon? weapon,
}) => DryFireEntry(
  id: '$discipline-$weapon-$pulls',
  recordedAt: DateTime.utc(2026, 7, 27),
  discipline: discipline,
  triggerPulls: pulls,
  weapon: weapon,
);

void main() {
  group('DryFireTotals (spec 0161)', () {
    test('empty log totals to zero everywhere', () {
      final totals = DryFireTotals.of(const []);
      expect(totals.forDiscipline(DryFireDiscipline.presisjon), 0);
      expect(totals.forDiscipline(DryFireDiscipline.duell), 0);
      expect(totals.grandTotal, 0);
      expect(totals.isEmpty, isTrue);
    });

    test('sums per discipline and overall across a mixed log', () {
      final totals = DryFireTotals.of([
        _entry(DryFireDiscipline.presisjon, 20),
        _entry(DryFireDiscipline.duell, 25),
        _entry(DryFireDiscipline.presisjon, 30),
      ]);
      expect(totals.forDiscipline(DryFireDiscipline.presisjon), 50);
      expect(totals.forDiscipline(DryFireDiscipline.duell), 25);
      expect(totals.grandTotal, 75);
      expect(totals.isEmpty, isFalse);
    });
  });

  group('DryFireTotals per weapon (spec 0166)', () {
    test('empty log totals to zero for every weapon and without-weapon', () {
      final totals = DryFireTotals.of(const []);
      for (final weapon in DryFireWeapon.values) {
        expect(totals.forWeapon(weapon), 0);
      }
      expect(totals.withoutWeapon, 0);
      expect(totals.grandTotal, 0);
    });

    test('sums per weapon, folds weapon-less entries into without-weapon', () {
      final totals = DryFireTotals.of([
        _entry(
          DryFireDiscipline.presisjon,
          20,
          weapon: DryFireWeapon.luftpistol,
        ),
        _entry(DryFireDiscipline.duell, 30, weapon: DryFireWeapon.finpistol),
        _entry(
          DryFireDiscipline.presisjon,
          10,
          weapon: DryFireWeapon.luftpistol,
        ),
        _entry(DryFireDiscipline.duell, 15, weapon: DryFireWeapon.grovpistol),
        // A bout recorded before the weapon was tracked.
        _entry(DryFireDiscipline.presisjon, 5),
      ]);

      expect(totals.forWeapon(DryFireWeapon.luftpistol), 30);
      expect(totals.forWeapon(DryFireWeapon.finpistol), 30);
      expect(totals.forWeapon(DryFireWeapon.grovpistol), 15);
      expect(totals.withoutWeapon, 5);
      // Every pull counted exactly once.
      expect(
        totals.forWeapon(DryFireWeapon.luftpistol) +
            totals.forWeapon(DryFireWeapon.finpistol) +
            totals.forWeapon(DryFireWeapon.grovpistol) +
            totals.withoutWeapon,
        totals.grandTotal,
      );
      // The discipline totals are unaffected by the weapon.
      expect(totals.forDiscipline(DryFireDiscipline.presisjon), 35);
      expect(totals.forDiscipline(DryFireDiscipline.duell), 45);
    });

    test('a single-weapon log leaves the other weapons at zero', () {
      final totals = DryFireTotals.of([
        _entry(
          DryFireDiscipline.presisjon,
          40,
          weapon: DryFireWeapon.finpistol,
        ),
      ]);
      expect(totals.forWeapon(DryFireWeapon.finpistol), 40);
      expect(totals.forWeapon(DryFireWeapon.luftpistol), 0);
      expect(totals.forWeapon(DryFireWeapon.grovpistol), 0);
      expect(totals.withoutWeapon, 0);
      expect(totals.grandTotal, 40);
    });
  });
}
