// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the in-memory session repository (spec 0024): it records
// uploads and is idempotent by id, like the real upsert.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/data/session_repository.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';

import '../../../support/records.dart';

SessionRecord _record(String id, {int total = 100}) => sessionRecord(
  id: id,
  program: '10 m Air Pistol',
  total: total,
  maxTotal: 100,
);

void main() {
  test('records an uploaded record and exposes it by id', () async {
    final repository = InMemorySessionRepository();
    expect(repository.uploads, isEmpty);

    await repository.upload(_record('a'));

    expect(repository.uploads, hasLength(1));
    expect(repository.uploads.single.id, 'a');
  });

  test(
    'a second upload of the same id keeps exactly one (idempotent)',
    () async {
      final repository = InMemorySessionRepository();

      await repository.upload(_record('a', total: 90));
      await repository.upload(_record('a', total: 95));

      expect(repository.uploads, hasLength(1));
      // The re-upload overwrote in place, as the real upsert would.
      expect(repository.uploads.single.total, 95);
    },
  );

  test('two different ids keep two records', () async {
    final repository = InMemorySessionRepository();

    await repository.upload(_record('a'));
    await repository.upload(_record('b'));

    expect(repository.uploads.map((r) => r.id), <String>['a', 'b']);
  });

  group('list (spec 0026)', () {
    test('returns an empty list before any upload', () async {
      final repository = InMemorySessionRepository();

      expect(await repository.list(), isEmpty);
    });

    test('returns the uploaded records', () async {
      final repository = InMemorySessionRepository();

      await repository.upload(_record('a', total: 90));
      await repository.upload(_record('b', total: 95));

      final listed = await repository.list();
      expect(listed.map((r) => r.id), <String>['a', 'b']);
      expect(listed.map((r) => r.total), <int>[90, 95]);
    });
  });
}
