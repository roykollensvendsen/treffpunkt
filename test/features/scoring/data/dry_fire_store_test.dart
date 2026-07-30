// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Exercises both DryFireStore bindings (spec 0161): the in-memory fake and the
// shared_preferences-backed implementation (driven by mock initial values, so
// no real platform storage is touched).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/features/scoring/data/dry_fire_store.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_weapon.dart';

DryFireEntry _entry(
  String id, {
  DryFireDiscipline discipline = DryFireDiscipline.presisjon,
  int pulls = 20,
}) => DryFireEntry(
  id: id,
  recordedAt: DateTime(2026, 7, 27, 9, 30),
  discipline: discipline,
  triggerPulls: pulls,
);

void main() {
  group('InMemoryDryFireStore', () {
    test('load is empty before any save', () async {
      expect(await InMemoryDryFireStore().load(), isEmpty);
    });

    test(
      'saves then loads an equal list, and an empty list clears it',
      () async {
        final store = InMemoryDryFireStore();
        final entries = [
          _entry('a', pulls: 30),
          _entry('b', discipline: DryFireDiscipline.duell, pulls: 25),
        ];

        await store.save(entries);
        expect(await store.load(), entries);

        await store.save(const <DryFireEntry>[]);
        expect(await store.load(), isEmpty);
      },
    );
  });

  group('SharedPreferencesDryFireStore', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('load is empty before any save', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(await SharedPreferencesDryFireStore(prefs).load(), isEmpty);
    });

    test('entries persist across a fresh store (restart)', () async {
      final prefs = await SharedPreferences.getInstance();
      final entries = [
        _entry('a', pulls: 40),
        _entry('b', discipline: DryFireDiscipline.duell, pulls: 15),
      ];

      await SharedPreferencesDryFireStore(prefs).save(entries);

      // A brand-new store over the same prefs models an app restart.
      final reopened = await SharedPreferencesDryFireStore(prefs).load();
      expect(reopened, entries);
    });

    test('a corrupt stored value loads as an empty log', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'dry_fire_log': 'not json',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(await SharedPreferencesDryFireStore(prefs).load(), isEmpty);
    });

    test('an old-format blob (no weapon key) loads with no weapon', () async {
      // Written before the weapon field existed (spec 0165). The whole log must
      // survive — a missing weapon key is not corruption.
      final legacy = jsonEncode(<Map<String, dynamic>>[
        {
          'id': 'legacy',
          'recordedAt': '2026-07-20T08:00:00.000Z',
          'discipline': 'presisjon',
          'triggerPulls': 10,
        },
      ]);
      SharedPreferences.setMockInitialValues(<String, Object>{
        'dry_fire_log': legacy,
      });
      final prefs = await SharedPreferences.getInstance();

      final loaded = await SharedPreferencesDryFireStore(prefs).load();
      expect(loaded.single.id, 'legacy');
      expect(loaded.single.weapon, isNull);
    });

    test('an entry with a weapon persists across a restart', () async {
      final prefs = await SharedPreferences.getInstance();
      final entries = [
        _entry('a', pulls: 40),
        DryFireEntry(
          id: 'g',
          recordedAt: DateTime(2026, 7, 27, 9, 30),
          discipline: DryFireDiscipline.duell,
          triggerPulls: 15,
          weapon: DryFireWeapon.grovpistol,
        ),
      ];

      await SharedPreferencesDryFireStore(prefs).save(entries);
      final reopened = await SharedPreferencesDryFireStore(prefs).load();
      expect(reopened, entries);
      expect(reopened.last.weapon, DryFireWeapon.grovpistol);
    });
  });
}
