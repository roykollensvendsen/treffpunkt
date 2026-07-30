// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/data/dry_fire_repository.dart';
import 'package:treffpunkt/features/scoring/data/supabase_dry_fire_repository.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_weapon.dart';

DryFireEntry _entry(
  String id, {
  DryFireDiscipline discipline = DryFireDiscipline.presisjon,
  int pulls = 20,
  int day = 20,
  DryFireWeapon? weapon,
}) => DryFireEntry(
  id: id,
  recordedAt: DateTime(2026, 7, day),
  discipline: discipline,
  triggerPulls: pulls,
  weapon: weapon,
);

void main() {
  group('InMemoryDryFireRepository (spec 0162)', () {
    test('lists nothing before any upload', () async {
      expect(await InMemoryDryFireRepository().list(), isEmpty);
    });

    test(
      'upserts by id — re-uploading an id replaces, never duplicates',
      () async {
        final repo = InMemoryDryFireRepository();
        await repo.upload([_entry('a', pulls: 10)]);
        await repo.upload([_entry('a', pulls: 99), _entry('b', pulls: 5)]);

        final listed = await repo.list();
        expect(listed, hasLength(2));
        expect(
          listed.firstWhere((e) => e.id == 'a').triggerPulls,
          99,
        );
      },
    );

    test('lists newest first', () async {
      final repo = InMemoryDryFireRepository();
      await repo.upload([
        _entry('old', day: 10),
        _entry('new', day: 25),
      ]);
      expect((await repo.list()).map((e) => e.id), ['new', 'old']);
    });

    test('deleteById drops the entry (spec 0163)', () async {
      final repo = InMemoryDryFireRepository();
      await repo.upload([_entry('a'), _entry('b')]);

      await repo.deleteById('a');

      expect((await repo.list()).map((e) => e.id), ['b']);
    });

    test('round-trips the weapon (spec 0165)', () async {
      final repo = InMemoryDryFireRepository();
      await repo.upload([_entry('a', weapon: DryFireWeapon.grovpistol)]);
      expect((await repo.list()).single.weapon, DryFireWeapon.grovpistol);
    });
  });

  group('SupabaseDryFireRepository row mapping (spec 0165)', () {
    test('rowFor carries the weapon wireName, null for a legacy entry', () {
      expect(
        SupabaseDryFireRepository.rowFor(
          _entry('a', weapon: DryFireWeapon.finpistol),
        )['weapon'],
        'finpistol',
      );
      expect(SupabaseDryFireRepository.rowFor(_entry('b'))['weapon'], isNull);
    });

    Map<String, dynamic> row({Object? weapon = _absent}) => <String, dynamic>{
      'id': 'a',
      'recorded_at': '2026-07-20T08:00:00.000Z',
      'discipline': 'presisjon',
      'trigger_pulls': 20,
      if (weapon != _absent) 'weapon': weapon,
    };

    test('entryFromRow reads a known weapon', () {
      expect(
        SupabaseDryFireRepository.entryFromRow(
          row(weapon: 'luftpistol'),
        ).weapon,
        DryFireWeapon.luftpistol,
      );
    });

    test('a missing, null or unknown weapon column maps to no weapon', () {
      // A pre-feature or foreign row must never break list().
      expect(SupabaseDryFireRepository.entryFromRow(row()).weapon, isNull);
      expect(
        SupabaseDryFireRepository.entryFromRow(row(weapon: null)).weapon,
        isNull,
      );
      expect(
        SupabaseDryFireRepository.entryFromRow(
          row(weapon: 'bueskyting'),
        ).weapon,
        isNull,
      );
    });
  });
}

/// Sentinel distinguishing an absent `weapon` column from an explicit null one.
const Object _absent = Object();
