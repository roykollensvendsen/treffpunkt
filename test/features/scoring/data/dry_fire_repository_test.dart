// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/data/dry_fire_repository.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';

DryFireEntry _entry(
  String id, {
  DryFireDiscipline discipline = DryFireDiscipline.presisjon,
  int pulls = 20,
  int day = 20,
}) => DryFireEntry(
  id: id,
  recordedAt: DateTime(2026, 7, day),
  discipline: discipline,
  triggerPulls: pulls,
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
  });
}
