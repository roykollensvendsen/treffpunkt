// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Tests for the pending-uploads store (spec 0025): the in-memory fake and the
// shared_preferences-backed implementation (driven by mock initial values, so
// no real platform storage is touched).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/features/scoring/data/pending_uploads_store.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';

import '../../../support/records.dart';

SessionRecord _record(String id, {int total = 100}) => sessionRecord(
  id: id,
  program: '10 m Air Pistol',
  capturedAt: DateTime(2026, 6, 21, 14, 30),
  placeLabel: 'Løvenskiold',
  latitude: 59.9,
  longitude: 10.7,
  weaponName: 'My pistol',
  total: total,
  maxTotal: 100,
  inner: 3,
  payload: <String, dynamic>{'id': id, 'current': null},
);

void expectSameRecords(List<SessionRecord> actual, List<SessionRecord> want) {
  expect(actual.map((r) => r.id), want.map((r) => r.id));
  for (var i = 0; i < want.length; i++) {
    expect(actual[i].total, want[i].total);
    expect(actual[i].innerTens, want[i].innerTens);
    expect(actual[i].placeLabel, want[i].placeLabel);
    expect(actual[i].payload, want[i].payload);
  }
}

void main() {
  group('InMemoryPendingUploadsStore', () {
    test('load is empty before any save', () async {
      expect(await InMemoryPendingUploadsStore().load(), isEmpty);
    });

    test(
      'saves then loads an equal list, and an empty list clears it',
      () async {
        final store = InMemoryPendingUploadsStore();
        final records = <SessionRecord>[_record('a', total: 90), _record('b')];

        await store.save(records);
        expectSameRecords(await store.load(), records);

        await store.save(<SessionRecord>[]);
        expect(await store.load(), isEmpty);
      },
    );
  });

  group('SharedPreferencesPendingUploadsStore', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('load is empty before any save', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesPendingUploadsStore(prefs);
      expect(await store.load(), isEmpty);
    });

    test('saves, loads an equal list, then an empty list clears it', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesPendingUploadsStore(prefs);
      final records = <SessionRecord>[_record('a', total: 90), _record('b')];

      await store.save(records);
      final loaded = await store.load();
      expectSameRecords(loaded, records);
      // The JSON survived the round-trip including the captured time and place.
      expect(loaded.first.capturedAt, DateTime(2026, 6, 21, 14, 30));
      expect(loaded.first.latitude, 59.9);

      await store.save(<SessionRecord>[]);
      expect(await store.load(), isEmpty);
    });

    test('malformed stored JSON loads as empty, like never-saved', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pending_session_uploads': 'not JSON',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(await SharedPreferencesPendingUploadsStore(prefs).load(), isEmpty);
    });
  });
}
