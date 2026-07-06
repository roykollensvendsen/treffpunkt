// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Tests for the personal-weapons store: the in-memory fake and the
// shared_preferences-backed implementation (driven by mock initial values, so
// no real platform storage is touched).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/weapons/data/weapon_store.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';

const Weapon _walther = Weapon(
  id: 'w1',
  name: 'My Walther',
  discipline: Discipline.pistol,
  caliberLabel: '.22 LR',
  classLabel: '.22 LR',
  make: 'Walther',
  model: 'GSP',
);

const Weapon _airRifle = Weapon(
  id: 'w2',
  name: 'Air rifle',
  discipline: Discipline.rifle,
  caliberLabel: '4.5 mm',
  classLabel: 'Air 4.5 mm',
);

void main() {
  group('InMemoryWeaponStore', () {
    test('load is empty before any save', () async {
      expect(await InMemoryWeaponStore().load(), isEmpty);
    });

    test('saves then loads an equal list', () async {
      final store = InMemoryWeaponStore();
      await store.save(<Weapon>[_walther, _airRifle]);
      expect(await store.load(), <Weapon>[_walther, _airRifle]);
    });

    test('save overwrites a previous list', () async {
      final store = InMemoryWeaponStore();
      await store.save(<Weapon>[_walther]);
      await store.save(<Weapon>[_airRifle]);
      expect(await store.load(), <Weapon>[_airRifle]);
    });

    test('saving an empty list clears the weapons', () async {
      final store = InMemoryWeaponStore();
      await store.save(<Weapon>[_walther]);
      await store.save(const <Weapon>[]);
      expect(await store.load(), isEmpty);
    });
  });

  group('SharedPreferencesWeaponStore', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('load is empty before any save', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(await SharedPreferencesWeaponStore(prefs).load(), isEmpty);
    });

    test('saves then loads an equal list, full and partial weapons', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesWeaponStore(prefs);

      await store.save(<Weapon>[_walther, _airRifle]);
      final loaded = await store.load();
      expect(loaded, <Weapon>[_walther, _airRifle]);
      expect(loaded.first.make, 'Walther');
      expect(loaded.last.make, isNull);
    });

    test('save overwrites the previous list', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesWeaponStore(prefs);
      await store.save(<Weapon>[_walther]);
      await store.save(<Weapon>[_airRifle]);
      expect(await store.load(), <Weapon>[_airRifle]);
    });

    test('malformed stored JSON loads as empty, like never-saved', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'personal_weapons': 'not JSON',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(await SharedPreferencesWeaponStore(prefs).load(), isEmpty);
    });
  });
}
