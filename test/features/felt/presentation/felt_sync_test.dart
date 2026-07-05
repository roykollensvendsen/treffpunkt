// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Tests for syncing finished felt rounds to the account (spec 0083).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/domain/competition.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/felt/data/felt_history_store.dart';
import 'package:treffpunkt/features/felt/data/felt_session_repository.dart';
import 'package:treffpunkt/features/felt/domain/felt_competition.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';

import '../../auth/fake_auth_repository.dart';

FeltSessionRecord _record(String id) => FeltSessionRecord(
  id: id,
  capturedAt: DateTime.utc(2026, 7, 5),
  session: const FeltSessionSnapshot(
    group: FeltShooterGroup.one,
    currentHold: 0,
    holds: <List<FeltPlacedShot>>[
      <FeltPlacedShot>[FeltPlacedShot(dx: 1, dy: 2, figureIndex: 0)],
    ],
  ),
);

ProviderContainer _container({
  required FakeAuthRepository auth,
  required InMemoryFeltSessionRepository repository,
  required InMemoryFeltHistoryStore history,
}) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      feltSessionRepositoryProvider.overrideWithValue(repository),
      feltHistoryStoreProvider.overrideWithValue(history),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('deleteById removes the account round (spec 0089)', () async {
    final repository = InMemoryFeltSessionRepository();
    await repository.upload(_record('a'));
    await repository.upload(_record('b'));

    await repository.deleteById('a');

    expect((await repository.list()).map((r) => r.id), <String>['b']);
  });

  test(
    'uploadAll uploads the local rounds when signed in (spec 0083)',
    () async {
      final repository = InMemoryFeltSessionRepository();
      final history = InMemoryFeltHistoryStore();
      await history.save(<FeltSessionRecord>[_record('a'), _record('b')]);
      final container = _container(
        auth: FakeAuthRepository(initial: const SignedIn(AppUser(id: 'u1'))),
        repository: repository,
        history: history,
      );

      await container.read(feltSyncProvider.notifier).uploadAll();

      expect((await repository.list()).map((r) => r.id).toSet(), {'a', 'b'});
    },
  );

  test('signed out, nothing is uploaded (spec 0083)', () async {
    final repository = InMemoryFeltSessionRepository();
    final history = InMemoryFeltHistoryStore();
    await history.save(<FeltSessionRecord>[_record('a')]);
    final container = _container(
      auth: FakeAuthRepository(),
      repository: repository,
      history: history,
    );

    await container.read(feltSyncProvider.notifier).uploadAll();
    await container.read(feltSyncProvider.notifier).uploadOne(_record('c'));

    expect(await repository.list(), isEmpty);
  });

  test('signing in flushes the local rounds (spec 0083)', () async {
    final repository = InMemoryFeltSessionRepository();
    final history = InMemoryFeltHistoryStore();
    await history.save(<FeltSessionRecord>[_record('a')]);
    final auth = FakeAuthRepository();
    final container = _container(
      auth: auth,
      repository: repository,
      history: history,
    );
    // Build the notifier so it registers its auth listener (kept alive by the
    // container, like the app root keeps the ring queue alive); the pumps below
    // drive it, so this is not a cascade.
    // ignore: cascade_invocations
    container.read(feltSyncProvider.notifier);
    expect(await repository.list(), isEmpty);

    // Signing in flushes the local rounds to the account.
    await container.pump();
    auth.emit(const SignedIn(AppUser(id: 'u1')));
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    await container.pump();

    expect((await repository.list()).single.id, 'a');
  });
  test(
    'a competition round submits its result on upload (spec 0140)',
    () async {
      final auth = FakeAuthRepository(
        initial: const SignedIn(AppUser(id: 'me', email: 'me@example.com')),
      );
      final repository = InMemoryFeltSessionRepository();
      final competitions = InMemoryCompetitionRepository(currentUserId: 'me');
      await competitions.createCompetition(
        Competition(
          id: 'felt-c1',
          name: 'Feltcup',
          program: feltCompetitionProgram(FeltShooterGroup.two),
          ownerId: 'me',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          feltSessionRepositoryProvider.overrideWithValue(repository),
          feltHistoryStoreProvider.overrideWithValue(
            InMemoryFeltHistoryStore(),
          ),
          competitionRepositoryProvider.overrideWithValue(competitions),
        ],
      );
      addTearDown(container.dispose);

      final record = FeltSessionRecord(
        id: 'felt-r1',
        capturedAt: DateTime.utc(2026, 7, 5).toLocal(),
        competitionId: 'felt-c1',
        session: const FeltSessionSnapshot(
          group: FeltShooterGroup.two,
          currentHold: 7,
          holds: <List<FeltPlacedShot>>[
            <FeltPlacedShot>[
              FeltPlacedShot(dx: 1, dy: 2, figureIndex: 0, inner: true),
              FeltPlacedShot(dx: 3, dy: 4, figureIndex: 0),
            ],
          ],
        ),
      );
      await container.read(feltSyncProvider.notifier).uploadOne(record);

      final results = await competitions.resultsOf('felt-c1');
      expect(results, hasLength(1));
      final result = results.single;
      // 2 treff + 1 figur = 3 points; 1 inner as the tiebreak; group max 47.
      expect(result.total, 3);
      expect(result.innerTens, 1);
      expect(result.maxTotal, 47);
      expect(result.program, feltCompetitionProgram(FeltShooterGroup.two));
      // The payload round-trips as a felt record (the result screen's path).
      expect(FeltSessionRecord.fromJson(result.payload).id, 'felt-r1');
    },
  );
}
