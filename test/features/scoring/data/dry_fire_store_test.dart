// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Exercises both DryFireStore bindings (spec 0161): the in-memory fake and the
// shared_preferences-backed implementation (driven by mock initial values, so
// no real platform storage is touched).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/features/scoring/data/dry_fire_store.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';

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
  });
}
