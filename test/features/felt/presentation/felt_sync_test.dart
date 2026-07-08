// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Tests for the durable felt upload queue (spec 0144, over specs 0083/0140):
// a finished round is enqueued durably and flushed on start / sign-in / after
// enqueue; the flush uploads AND submits a competition result no matter when
// it runs — the offline-competition regression — failures keep the round
// queued, a delete dequeues it, and history alone is never re-uploaded.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/domain/competition_result.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/felt/data/felt_history_store.dart';
import 'package:treffpunkt/features/felt/data/felt_pending_uploads_store.dart';
import 'package:treffpunkt/features/felt/data/felt_session_repository.dart';
import 'package:treffpunkt/features/felt/domain/felt_competition.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';

import '../../../support/records.dart';
import '../../auth/fake_auth_repository.dart';

FeltSessionRecord _record(String id, {String? competitionId}) =>
    feltSessionRecord(
      id: id,
      capturedAt: DateTime.utc(2026, 7, 5),
      competitionId: competitionId,
    );

/// A repository that throws on [upload] until [heal] is flipped — to prove a
/// failed upload keeps the round queued and a later flush drains it.
class _ThrowingFeltSessionRepository extends InMemoryFeltSessionRepository {
  bool heal = false;
  int uploadAttempts = 0;

  @override
  Future<void> upload(FeltSessionRecord record) {
    uploadAttempts++;
    if (!heal) throw const FeltSyncException('upload failed');
    return super.upload(record);
  }
}

/// Counts result submissions and can be made to fail — to prove the queue
/// submits competition results (and only for competition rounds) and keeps a
/// round queued until its result lands.
class _SpyCompetitionRepository extends InMemoryCompetitionRepository {
  _SpyCompetitionRepository({super.currentUserId});

  bool fail = false;
  int submitCalls = 0;

  @override
  Future<void> submitResult(CompetitionResult result) {
    submitCalls++;
    if (fail) throw const CompetitionSyncException('submit failed');
    return super.submitResult(result);
  }
}

ProviderContainer _container({
  required FakeAuthRepository auth,
  FeltSessionRepository? repository,
  FeltPendingUploadsStore? pending,
  InMemoryFeltHistoryStore? history,
  CompetitionRepository? competitions,
}) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      feltSessionRepositoryProvider.overrideWithValue(
        repository ?? InMemoryFeltSessionRepository(),
      ),
      feltPendingUploadsStoreProvider.overrideWithValue(
        pending ?? InMemoryFeltPendingUploadsStore(),
      ),
      feltHistoryStoreProvider.overrideWithValue(
        history ?? InMemoryFeltHistoryStore(),
      ),
      if (competitions != null)
        competitionRepositoryProvider.overrideWithValue(competitions),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Lets the queue's fire-and-forget chain (load → enqueue → flush) settle.
Future<void> _settle(ProviderContainer container) async {
  for (var i = 0; i < 4; i++) {
    await container.pump();
    await Future<void>.delayed(Duration.zero);
  }
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
    'a round finished signed out is queued (persisted), not uploaded; '
    'sign-in uploads it AND submits its competition result (spec 0144)',
    () async {
      // The offline-competition regression (spec 0144): before the durable
      // queue, a competition round finished offline was uploaded by the later
      // reconcile but its result never reached the scoreboard.
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final repository = InMemoryFeltSessionRepository();
      final pending = InMemoryFeltPendingUploadsStore();
      final competitions = _SpyCompetitionRepository(currentUserId: 'me');
      final container = _container(
        auth: auth,
        repository: repository,
        pending: pending,
        competitions: competitions,
      );
      final notifier = container.read(feltSyncProvider.notifier);
      await _settle(container);

      // Finish the competition round while signed out: queued, persisted,
      // NOT uploaded, no result submitted.
      await notifier.enqueue(_record('offline-1', competitionId: 'felt-c1'));
      expect(await repository.list(), isEmpty);
      expect(competitions.submitCalls, 0);
      expect(container.read(feltSyncProvider).map((r) => r.id), <String>[
        'offline-1',
      ]);
      expect((await pending.load()).map((r) => r.id), <String>['offline-1']);

      // Sign in — the transition flushes: upload AND result submission.
      auth.emit(const SignedIn(AppUser(id: 'me')));
      await _settle(container);

      expect((await repository.list()).single.id, 'offline-1');
      final results = await competitions.resultsOf('felt-c1');
      // The result id is the round id mapped to a deterministic uuid — the
      // results table's id column is `uuid`, so the raw radix-36 round id
      // would be rejected by the real backend (spec 0140).
      expect(results.map((r) => r.id), <String>[
        feltCompetitionResultId('offline-1'),
      ]);
      expect(container.read(feltSyncProvider), isEmpty);
      expect(await pending.load(), isEmpty);
    },
  );

  test(
    'a round finished signed in uploads immediately and leaves the queue '
    '(spec 0144)',
    () async {
      final repository = InMemoryFeltSessionRepository();
      final pending = InMemoryFeltPendingUploadsStore();
      final container = _container(
        auth: FakeAuthRepository(initial: const SignedIn(AppUser(id: 'u1'))),
        repository: repository,
        pending: pending,
      );

      await container.read(feltSyncProvider.notifier).enqueue(_record('a'));

      expect((await repository.list()).single.id, 'a');
      expect(container.read(feltSyncProvider), isEmpty);
      expect(await pending.load(), isEmpty);
    },
  );

  test(
    'a failing repository keeps the round queued; a later flush retries and '
    'drains it (spec 0144)',
    () async {
      final repository = _ThrowingFeltSessionRepository();
      final pending = InMemoryFeltPendingUploadsStore();
      final container = _container(
        auth: FakeAuthRepository(initial: const SignedIn(AppUser(id: 'u1'))),
        repository: repository,
        pending: pending,
      );

      await container.read(feltSyncProvider.notifier).enqueue(_record('a'));

      // The upload was attempted and threw: the round is not lost — it waits
      // in the queue (and the durable store) for the next flush.
      expect(repository.uploadAttempts, 1);
      expect(container.read(feltSyncProvider).map((r) => r.id), <String>['a']);
      expect((await pending.load()).map((r) => r.id), <String>['a']);

      repository.heal = true;
      await container.read(feltSyncProvider.notifier).flush();

      expect((await repository.list()).single.id, 'a');
      expect(container.read(feltSyncProvider), isEmpty);
      expect(await pending.load(), isEmpty);
    },
  );

  test(
    'a failed result submission keeps the round queued until it lands '
    '(spec 0144)',
    () async {
      final repository = InMemoryFeltSessionRepository();
      final competitions = _SpyCompetitionRepository(currentUserId: 'me')
        ..fail = true;
      final container = _container(
        auth: FakeAuthRepository(initial: const SignedIn(AppUser(id: 'me'))),
        repository: repository,
        competitions: competitions,
      );

      await container
          .read(feltSyncProvider.notifier)
          .enqueue(_record('r1', competitionId: 'felt-c1'));

      // The round uploaded, but the result submission failed → still queued
      // (tryUpload is true only when everything succeeded).
      expect((await repository.list()).single.id, 'r1');
      expect(await competitions.resultsOf('felt-c1'), isEmpty);
      expect(container.read(feltSyncProvider).map((r) => r.id), <String>['r1']);

      // Heal and flush again → the result lands and the round is dropped (the
      // re-upload is an idempotent no-op).
      competitions.fail = false;
      await container.read(feltSyncProvider.notifier).flush();
      expect(
        (await competitions.resultsOf('felt-c1')).single.id,
        feltCompetitionResultId('r1'),
      );
      expect(container.read(feltSyncProvider), isEmpty);
    },
  );

  test('a training round never submits a competition result', () async {
    final competitions = _SpyCompetitionRepository(currentUserId: 'me');
    final container = _container(
      auth: FakeAuthRepository(initial: const SignedIn(AppUser(id: 'me'))),
      competitions: competitions,
    );

    await container.read(feltSyncProvider.notifier).enqueue(_record('a'));

    expect(competitions.submitCalls, 0);
    expect(container.read(feltSyncProvider), isEmpty);
  });

  test(
    'the queue survives a restart: a pending round loads from the store and '
    'uploads (spec 0144)',
    () async {
      // The store already holds a round, as if persisted on a prior run that
      // died (or stayed offline) before the upload.
      final pending = InMemoryFeltPendingUploadsStore();
      await pending.save(<FeltSessionRecord>[_record('kept-1')]);
      final repository = InMemoryFeltSessionRepository();
      final container = _container(
        auth: FakeAuthRepository(initial: const SignedIn(AppUser(id: 'u1'))),
        repository: repository,
        pending: pending,
      );

      // Building the notifier (app start) loads and flushes the pending round
      // (the state starts empty until the engine's load resolves).
      expect(container.read(feltSyncProvider), isEmpty);
      await _settle(container);

      expect((await repository.list()).single.id, 'kept-1');
      expect(container.read(feltSyncProvider), isEmpty);
      expect(await pending.load(), isEmpty);
    },
  );

  test(
    'deleting a pending round removes it from the queue and the store; it '
    'never uploads (spec 0144)',
    () async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final repository = InMemoryFeltSessionRepository();
      final pending = InMemoryFeltPendingUploadsStore();
      final container = _container(
        auth: auth,
        repository: repository,
        pending: pending,
      );
      final notifier = container.read(feltSyncProvider.notifier);
      await _settle(container);
      await notifier.enqueue(_record('doomed'));
      expect((await pending.load()).map((r) => r.id), <String>['doomed']);

      await notifier.deleteById('doomed');

      expect(container.read(feltSyncProvider), isEmpty);
      expect(await pending.load(), isEmpty);

      // Signing in later finds nothing to flush — the round never uploads.
      auth.emit(const SignedIn(AppUser(id: 'u1')));
      await _settle(container);
      expect(await repository.list(), isEmpty);
    },
  );

  test(
    'start and sign-in do not re-upload rounds that are only in history '
    '(spec 0144)',
    () async {
      // Two rounds live in the local history (already synced on an earlier
      // run) but none is pending: the old whole-history reconcile would have
      // re-uploaded both; the durable queue must not.
      final auth = FakeAuthRepository(
        initial: const SignedIn(AppUser(id: 'u1')),
      );
      addTearDown(auth.dispose);
      final repository = InMemoryFeltSessionRepository();
      final history = InMemoryFeltHistoryStore();
      await history.save(<FeltSessionRecord>[_record('h1'), _record('h2')]);
      final container = _container(
        auth: auth,
        repository: repository,
        history: history,
      );

      // Building the notifier (app start) must not touch the history rounds.
      expect(container.read(feltSyncProvider), isEmpty);
      await _settle(container);
      expect(await repository.list(), isEmpty);

      // Nor does a fresh sign-in transition.
      auth
        ..emit(const SignedOut())
        ..emit(const SignedIn(AppUser(id: 'u1')));
      await _settle(container);
      expect(await repository.list(), isEmpty);
    },
  );

  testWidgets(
    'saveFeltRound enqueues the round and deleteFeltRound dequeues it '
    '(spec 0144)',
    (tester) async {
      // The wiring test: the save flow must enqueue (not just store history)
      // and the delete flow must also remove the pending entry.
      final pending = InMemoryFeltPendingUploadsStore();
      final history = InMemoryFeltHistoryStore();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          feltPendingUploadsStoreProvider.overrideWithValue(pending),
          feltHistoryStoreProvider.overrideWithValue(history),
        ],
      );
      addTearDown(container.dispose);
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await saveFeltRound(capturedRef, _record('w1', competitionId: 'c1'));
      await tester.pump();
      expect((await history.load()).map((r) => r.id), <String>['w1']);
      expect((await pending.load()).map((r) => r.id), <String>['w1']);

      await deleteFeltRound(capturedRef, 'w1');
      await tester.pump();
      expect(await history.load(), isEmpty);
      expect(await pending.load(), isEmpty);
    },
  );

  test(
    'a competition round submits its result on upload (spec 0140)',
    () async {
      final auth = FakeAuthRepository(
        initial: const SignedIn(AppUser(id: 'me', email: 'me@example.com')),
      );
      final repository = InMemoryFeltSessionRepository();
      final competitions = InMemoryCompetitionRepository(currentUserId: 'me');
      final container = _container(
        auth: auth,
        repository: repository,
        competitions: competitions,
      );

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
      await container.read(feltSyncProvider.notifier).enqueue(record);

      final results = await competitions.resultsOf('felt-c1');
      expect(results, hasLength(1));
      final result = results.single;
      // The id is the deterministic uuid for the round (spec 0140): the
      // results table's id column is `uuid`, and retries must map the same
      // round to the same result.
      expect(result.id, feltCompetitionResultId('felt-r1'));
      // 2 treff + 1 figur = 3 points; 1 inner as the tiebreak; the gruppe-2
      // maximum is computed: 40 treff + 30 figur = 70 (spec 0148).
      expect(result.total, 3);
      expect(result.innerTens, 1);
      expect(result.maxTotal, 70);
      expect(
        result.program,
        feltCompetitionProgram(norgesfelt2026Course, FeltShooterGroup.two),
      );
      // The payload round-trips as a felt record (the result screen's path).
      expect(FeltSessionRecord.fromJson(result.payload).id, 'felt-r1');
    },
  );
}
