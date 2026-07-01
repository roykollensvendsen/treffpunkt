// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the felt session stores (spec 0081).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/features/felt/data/felt_session_store.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';

FeltSessionSnapshot _snapshot() => const FeltSessionSnapshot(
  group: FeltShooterGroup.two,
  currentHold: 1,
  holds: <List<FeltPlacedShot>>[
    <FeltPlacedShot>[FeltPlacedShot(dx: 1, dy: 2, figureIndex: 0, inner: true)],
    <FeltPlacedShot>[],
  ],
);

void main() {
  group('InMemoryFeltSessionStore', () {
    test('load is null before any save (spec 0081)', () async {
      expect(await InMemoryFeltSessionStore().load(), isNull);
    });

    test(
      'saves, loads an equal snapshot, then clears it (spec 0081)',
      () async {
        final store = InMemoryFeltSessionStore();
        await store.save(_snapshot());
        expect(await store.load(), _snapshot());
        await store.clear();
        expect(await store.load(), isNull);
      },
    );
  });

  group('SharedPreferencesFeltSessionStore', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test(
      'saves, loads an equal snapshot, then clears it (spec 0081)',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = SharedPreferencesFeltSessionStore(prefs);
        expect(await store.load(), isNull);
        await store.save(_snapshot());
        expect(await store.load(), _snapshot());
        await store.clear();
        expect(await store.load(), isNull);
      },
    );
  });
}
