// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the finished felt-round history store (spec 0082).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/features/felt/data/felt_history_store.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';

List<FeltSessionRecord> _records() => <FeltSessionRecord>[
  FeltSessionRecord(
    id: 'r1',
    capturedAt: DateTime.utc(2026, 7, 1, 12),
    session: const FeltSessionSnapshot(
      group: FeltShooterGroup.two,
      currentHold: 0,
      holds: <List<FeltPlacedShot>>[
        <FeltPlacedShot>[FeltPlacedShot(dx: 1, dy: 2, figureIndex: 0)],
      ],
    ),
  ),
];

void main() {
  group('InMemoryFeltHistoryStore', () {
    test('load is empty before any save (spec 0082)', () async {
      expect(await InMemoryFeltHistoryStore().load(), isEmpty);
    });

    test('saves and loads the records (spec 0082)', () async {
      final store = InMemoryFeltHistoryStore();
      await store.save(_records());
      expect(await store.load(), _records());
    });
  });

  group('SharedPreferencesFeltHistoryStore', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test(
      'saves, loads the records, and empties on save([]) (spec 0082)',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = SharedPreferencesFeltHistoryStore(prefs);
        expect(await store.load(), isEmpty);
        await store.save(_records());
        expect(await store.load(), _records());
        await store.save(const <FeltSessionRecord>[]);
        expect(await store.load(), isEmpty);
      },
    );
  });
}
