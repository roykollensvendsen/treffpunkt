// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Tests for the local session store: the in-memory fake and the
// shared_preferences-backed implementation (driven by mock initial values, so
// no real platform storage is touched).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/features/scoring/data/session_store.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/session.dart';
import 'package:treffpunkt/features/scoring/domain/session_snapshot.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';

const Shot _shot = Shot(dxMm: 3, dyMm: -4);

SessionSnapshot _snapshot() {
  final session = Session.start(ProgramCatalogue.airRifle10m);
  return SessionSnapshot(
    session: session,
    current: session.newSeries()!.placeShot(_shot),
  );
}

void main() {
  group('InMemorySessionStore', () {
    test('load is null before any save', () async {
      expect(await InMemorySessionStore().load(), isNull);
    });

    test('saves then loads an equal snapshot, and clear empties it', () async {
      final store = InMemorySessionStore();
      final snapshot = _snapshot();

      await store.save(snapshot);
      expect(await store.load(), snapshot);

      await store.clear();
      expect(await store.load(), isNull);
    });

    test('save overwrites a previous snapshot', () async {
      final store = InMemorySessionStore();
      await store.save(_snapshot());
      final second = SessionSnapshot(
        session: Session.start(ProgramCatalogue.finpistol25m),
      );
      await store.save(second);
      expect((await store.load())!.session.program.name, '25 m Finpistol');
    });
  });

  group('SharedPreferencesSessionStore', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('saves, loads an equal snapshot, then clears it', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesSessionStore(prefs);
      final snapshot = _snapshot();

      expect(await store.load(), isNull);

      await store.save(snapshot);
      final loaded = await store.load();
      expect(loaded, snapshot);
      expect(loaded!.current!.shots.single.dxMm, 3);

      await store.clear();
      expect(await store.load(), isNull);
    });

    test('malformed stored JSON loads as null, like never-saved', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'active_session_recording': 'not JSON',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(await SharedPreferencesSessionStore(prefs).load(), isNull);
    });
  });
}
