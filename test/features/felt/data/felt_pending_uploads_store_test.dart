// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Tests for the felt pending-uploads store (spec 0144): the in-memory fake and
// the shared_preferences-backed implementation (driven by mock initial values,
// so no real platform storage is touched) — the felt mirror of the ring's
// pending-uploads store (spec 0025).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/features/felt/data/felt_pending_uploads_store.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';

import '../../../support/records.dart';

FeltSessionRecord _record(String id, {String? competitionId}) =>
    feltSessionRecord(
      id: id,
      capturedAt: DateTime(2026, 7, 4, 18, 30),
      competitionId: competitionId,
    );

void _expectSameRecords(
  List<FeltSessionRecord> actual,
  List<FeltSessionRecord> want,
) {
  expect(actual.map((r) => r.id), want.map((r) => r.id));
  for (var i = 0; i < want.length; i++) {
    expect(actual[i].capturedAt, want[i].capturedAt);
    expect(actual[i].competitionId, want[i].competitionId);
    expect(actual[i].session.group, want[i].session.group);
  }
}

void main() {
  group('InMemoryFeltPendingUploadsStore', () {
    test('load is empty before any save', () async {
      expect(await InMemoryFeltPendingUploadsStore().load(), isEmpty);
    });

    test(
      'saves then loads an equal list, and an empty list clears it',
      () async {
        final store = InMemoryFeltPendingUploadsStore();
        final records = <FeltSessionRecord>[
          _record('a', competitionId: 'c1'),
          _record('b'),
        ];

        await store.save(records);
        _expectSameRecords(await store.load(), records);

        await store.save(<FeltSessionRecord>[]);
        expect(await store.load(), isEmpty);
      },
    );
  });

  group('SharedPreferencesFeltPendingUploadsStore', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('load is empty before any save', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesFeltPendingUploadsStore(prefs);
      expect(await store.load(), isEmpty);
    });

    test('saves, loads an equal list, then an empty list clears it', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesFeltPendingUploadsStore(prefs);
      final records = <FeltSessionRecord>[
        _record('a', competitionId: 'c1'),
        _record('b'),
      ];

      await store.save(records);
      final loaded = await store.load();
      _expectSameRecords(loaded, records);
      // The JSON survived the round-trip including the competition binding —
      // that binding is what the offline result submission depends on.
      expect(loaded.first.competitionId, 'c1');

      await store.save(<FeltSessionRecord>[]);
      expect(await store.load(), isEmpty);
    });

    test('malformed stored JSON loads as empty, like never-saved', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'felt_pending_uploads': 'not JSON',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        await SharedPreferencesFeltPendingUploadsStore(prefs).load(),
        isEmpty,
      );
    });
  });
}
