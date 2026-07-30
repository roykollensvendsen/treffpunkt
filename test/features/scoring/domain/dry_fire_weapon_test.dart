// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_weapon.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/weapons/domain/weapon_catalogue.dart';
import 'package:treffpunkt/features/weapons/domain/weapon_class.dart';

void main() {
  group('DryFireWeapon (spec 0165)', () {
    test('each value has its expected stable label and wireName', () {
      // The wireName is a storage key: pinning it makes a rename a deliberate,
      // reviewed break rather than a silent corruption of stored/synced data.
      expect(DryFireWeapon.luftpistol.label, 'Luftpistol');
      expect(DryFireWeapon.luftpistol.wireName, 'luftpistol');
      expect(DryFireWeapon.finpistol.label, 'Finpistol');
      expect(DryFireWeapon.finpistol.wireName, 'finpistol');
      expect(DryFireWeapon.grovpistol.label, 'Grovpistol');
      expect(DryFireWeapon.grovpistol.wireName, 'grovpistol');
    });

    test('fromWireName maps every value round-trip', () {
      for (final weapon in DryFireWeapon.values) {
        expect(DryFireWeapon.fromWireName(weapon.wireName), weapon);
      }
    });

    test('fromWireName degrades an unknown or null name to null', () {
      // A weapon is optional, so an unreadable value must not throw (the list
      // store empties the whole log on a single throw).
      expect(DryFireWeapon.fromWireName('bueskyting'), isNull);
      expect(DryFireWeapon.fromWireName(null), isNull);
    });

    test('the three types stay in step with the catalogue pistol classes', () {
      // Drift guard: keyed on the WeaponClass objects, not their labels, so a
      // cosmetic label rename does not break the stable wireNames, and adding a
      // non-pistol class never spuriously fails this. Adding, removing or
      // renaming a *pistol* class without updating the dry-fire types does.
      const mapping = <DryFireWeapon, WeaponClass>{
        DryFireWeapon.luftpistol: WeaponCatalogue.airPistol,
        DryFireWeapon.finpistol: WeaponCatalogue.smallborePistol,
        DryFireWeapon.grovpistol: WeaponCatalogue.centreFirePistol,
      };

      // Every value is mapped.
      expect(mapping.keys.toSet(), DryFireWeapon.values.toSet());
      // The mapped classes are exactly the catalogue's pistol classes.
      final pistolClasses = WeaponCatalogue.all
          .where((weaponClass) => weaponClass.discipline == Discipline.pistol)
          .toSet();
      expect(mapping.values.toSet(), pistolClasses);
    });
  });
}
