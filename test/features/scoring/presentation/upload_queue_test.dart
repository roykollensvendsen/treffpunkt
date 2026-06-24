// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Provider tests for the durable upload queue (spec 0025): completing a
// session enqueues it (never losing it); a flush uploads and removes it when
// signed in; signed out it stays queued and uploads on sign-in; a throwing
// repository keeps the record queued; the same id dedups to one; on app start
// a queue loaded with pending records flushes them.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/domain/competition.dart';
import 'package:treffpunkt/features/competitions/domain/competition_invitation.dart';
import 'package:treffpunkt/features/competitions/domain/competition_member.dart';
import 'package:treffpunkt/features/competitions/domain/competition_result.dart';
import 'package:treffpunkt/features/competitions/domain/profile.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/scoring/data/pending_uploads_store.dart';
import 'package:treffpunkt/features/scoring/data/session_repository.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/upload_queue.dart';

import '../../auth/fake_auth_repository.dart';

// One stage of one series of two shots, so a session completes after a single
// seal — the smallest complete session.
const ProgramDefinition _program = ProgramDefinition(
  name: 'Test',
  discipline: Discipline.pistol,
  stages: <StageDefinition>[
    StageDefinition(
      name: 'A',
      geometry: TargetGeometry.pistol25mPrecision(),
      shotsPerSeries: 2,
      seriesCount: 1,
    ),
  ],
);
const Shot _centre = Shot(dxMm: 0, dyMm: 0);

SessionRecord _record(
  String id, {
  int total = 50,
  int innerTens = 0,
  String? competitionId,
}) => SessionRecord(
  id: id,
  program: '10 m Air Pistol',
  total: total,
  maxTotal: 100,
  innerTens: innerTens,
  payload: <String, dynamic>{'id': id},
  competitionId: competitionId,
);

/// Records the result ids submitted, and can be made to fail — to prove the
/// queue submits competition results and keeps a record queued until it lands.
class _SpyCompetitionRepository implements CompetitionRepository {
  final List<String> submittedIds = <String>[];
  bool fail = false;

  @override
  Future<void> submitResult(CompetitionResult result) async {
    if (fail) throw const CompetitionSyncException('submit failed');
    submittedIds.add(result.id);
  }

  @override
  Future<void> upsertOwnProfile(Profile profile) async {}
  @override
  Future<void> createCompetition(Competition competition) async =>
      throw UnimplementedError();
  @override
  Future<List<Competition>> listMine() async => throw UnimplementedError();
  @override
  Future<void> invite(String competitionId, String email) async =>
      throw UnimplementedError();
  @override
  Future<List<CompetitionInvitation>> listMyInvitations() async =>
      throw UnimplementedError();
  @override
  Future<void> acceptInvitation(String competitionId) async =>
      throw UnimplementedError();
  @override
  Future<List<CompetitionMember>> membersOf(String competitionId) async =>
      throw UnimplementedError();
  @override
  Future<List<CompetitionResult>> resultsOf(String competitionId) async =>
      throw UnimplementedError();
}

/// A repository whose [upload] always throws, to prove the queue keeps the
/// record and never breaks completion.
class _ThrowingSessionRepository implements SessionRepository {
  int callCount = 0;

  @override
  Future<void> upload(SessionRecord record) async {
    callCount++;
    throw Exception('upload failed');
  }

  @override
  Future<List<SessionRecord>> list() async => const <SessionRecord>[];
}

/// A repository whose first [upload] parks on a [Completer] (so a flush is
/// still in flight when a later operation arrives), recording each uploaded id.
class _BlockingSessionRepository implements SessionRepository {
  _BlockingSessionRepository(this.gate);

  /// Completed by the test to release the parked upload.
  final Completer<void> gate;
  final List<String> uploadedIds = <String>[];
  bool _firstAwaited = false;

  @override
  Future<void> upload(SessionRecord record) async {
    // Only the first upload parks on the gate; later ones complete at once, so
    // the test can drive an in-flight flush precisely.
    if (!_firstAwaited) {
      _firstAwaited = true;
      await gate.future;
    }
    uploadedIds.add(record.id);
  }

  @override
  Future<List<SessionRecord>> list() async => const <SessionRecord>[];
}

/// A repository that uploads id `ok` but throws for id `bad` — until [heal] is
/// flipped, after which `bad` uploads too (proving a later flush drains it).
class _SelectiveSessionRepository implements SessionRepository {
  final List<String> uploadedIds = <String>[];
  bool heal = false;

  @override
  Future<void> upload(SessionRecord record) async {
    if (record.id == 'bad' && !heal) {
      throw Exception('bad upload failed');
    }
    uploadedIds.add(record.id);
  }

  @override
  Future<List<SessionRecord>> list() async => const <SessionRecord>[];
}

void main() {
  ProviderContainer makeContainer({
    required AuthStatus auth,
    required SessionRepository repository,
    required PendingUploadsStore pendingStore,
    String id = 'fixed-id',
    FakeAuthRepository? authRepository,
    CompetitionRepository? competitionRepository,
  }) {
    final authRepo = authRepository ?? FakeAuthRepository(initial: auth);
    return ProviderContainer(
      overrides: [
        currentProgramDefinitionProvider.overrideWithValue(_program),
        authRepositoryProvider.overrideWithValue(authRepo),
        sessionRepositoryProvider.overrideWithValue(repository),
        pendingUploadsStoreProvider.overrideWithValue(pendingStore),
        sessionIdGeneratorProvider.overrideWithValue(() => id),
        restoredRecordingProvider.overrideWithValue(null),
        if (competitionRepository != null)
          competitionRepositoryProvider.overrideWithValue(
            competitionRepository,
          ),
      ],
    );
  }

  void completeSession(ProviderContainer container) {
    container.read(sessionProvider.notifier)
      ..placeShot(_centre)
      ..placeShot(_centre)
      ..advance();
    expect(container.read(sessionProvider).isComplete, isTrue);
  }

  test(
    'completing while signed in enqueues then uploads it; queue ends empty',
    () async {
      final repository = InMemorySessionRepository();
      final pendingStore = InMemoryPendingUploadsStore();
      final container = makeContainer(
        auth: const SignedIn(AppUser(id: 'u1')),
        repository: repository,
        pendingStore: pendingStore,
        id: 'recording-1',
      );
      addTearDown(container.dispose);

      completeSession(container);
      await container.pump();
      // Let the fire-and-forget enqueue/flush microtasks settle.
      await Future<void>.delayed(Duration.zero);
      await container.pump();

      // Uploaded with the recording id and the all-centre score.
      expect(repository.uploads, hasLength(1));
      expect(repository.uploads.single.id, 'recording-1');
      expect(repository.uploads.single.total, 20);
      expect(repository.uploads.single.innerTens, 2);
      // The queue drained and nothing is left persisted.
      expect(container.read(uploadQueueProvider), isEmpty);
      expect(await pendingStore.load(), isEmpty);
    },
  );

  test(
    'completing while signed out enqueues it and it stays queued (no loss)',
    () async {
      final repository = InMemorySessionRepository();
      final pendingStore = InMemoryPendingUploadsStore();
      final container = makeContainer(
        auth: const SignedOut(),
        repository: repository,
        pendingStore: pendingStore,
        id: 'offline-1',
      );
      addTearDown(container.dispose);

      completeSession(container);
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      await container.pump();

      // Nothing uploaded — but the record is safe in the queue and persisted.
      expect(repository.uploads, isEmpty);
      expect(container.read(uploadQueueProvider).map((r) => r.id), <String>[
        'offline-1',
      ]);
      final stored = await pendingStore.load();
      expect(stored.map((r) => r.id), <String>['offline-1']);
      expect(stored.single.total, 20);
    },
  );

  test(
    'signing in flushes a queued (signed-out) session and uploads it',
    () async {
      final repository = InMemorySessionRepository();
      final pendingStore = InMemoryPendingUploadsStore();
      final authRepository = FakeAuthRepository();
      addTearDown(authRepository.dispose);
      final container = makeContainer(
        auth: const SignedOut(),
        repository: repository,
        pendingStore: pendingStore,
        id: 'later-1',
        authRepository: authRepository,
      );
      addTearDown(container.dispose);

      // Complete signed out: queued, not uploaded.
      completeSession(container);
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      expect(repository.uploads, isEmpty);
      expect(container.read(uploadQueueProvider).map((r) => r.id), <String>[
        'later-1',
      ]);

      // Now sign in — the transition flushes the queue.
      authRepository.emit(const SignedIn(AppUser(id: 'u1')));
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      await container.pump();

      expect(repository.uploads.map((r) => r.id), <String>['later-1']);
      expect(repository.uploads.single.total, 20);
      expect(container.read(uploadQueueProvider), isEmpty);
      expect(await pendingStore.load(), isEmpty);
    },
  );

  test(
    'a throwing repository leaves the record queued, not breaking completion',
    () async {
      final repository = _ThrowingSessionRepository();
      final pendingStore = InMemoryPendingUploadsStore();
      final container = makeContainer(
        auth: const SignedIn(AppUser(id: 'u1')),
        repository: repository,
        pendingStore: pendingStore,
        id: 'throws-1',
      );
      addTearDown(container.dispose);

      completeSession(container);
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      await container.pump();

      // The upload was attempted and threw, but completion is intact and the
      // record is not lost — it waits in the queue for the next flush.
      expect(repository.callCount, greaterThanOrEqualTo(1));
      expect(container.read(sessionProvider).isComplete, isTrue);
      expect(container.read(uploadQueueProvider).map((r) => r.id), <String>[
        'throws-1',
      ]);
      expect((await pendingStore.load()).map((r) => r.id), <String>[
        'throws-1',
      ]);
    },
  );

  test(
    'enqueuing the same id twice keeps exactly one pending record',
    () async {
      final repository = _ThrowingSessionRepository(); // keep them queued
      final pendingStore = InMemoryPendingUploadsStore();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          sessionRepositoryProvider.overrideWithValue(repository),
          pendingUploadsStoreProvider.overrideWithValue(pendingStore),
        ],
      );
      addTearDown(container.dispose);

      final queue = container.read(uploadQueueProvider.notifier);
      await queue.enqueue(_record('dup', total: 30));
      await queue.enqueue(_record('dup', total: 70));

      final pending = container.read(uploadQueueProvider);
      expect(pending, hasLength(1));
      expect(pending.single.id, 'dup');
      // The latest enqueue won (an idempotent upsert).
      expect(pending.single.total, 70);
      expect((await pendingStore.load()).single.total, 70);
    },
  );

  test(
    'on app start, a queue loaded with pending records flushes them when '
    'signed in',
    () async {
      final repository = InMemorySessionRepository();
      // The store already holds two records, as if persisted on a prior run.
      final pendingStore = InMemoryPendingUploadsStore();
      await pendingStore.save(<SessionRecord>[
        _record('start-a', total: 88),
        _record('start-b', total: 77),
      ]);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(initial: const SignedIn(AppUser(id: 'u1'))),
          ),
          sessionRepositoryProvider.overrideWithValue(repository),
          pendingUploadsStoreProvider.overrideWithValue(pendingStore),
        ],
      );
      addTearDown(container.dispose);

      // Building the queue (app start) loads and flushes the pending records.
      container.read(uploadQueueProvider);
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      await container.pump();

      expect(
        repository.uploads.map((r) => r.id).toSet(),
        <String>{'start-a', 'start-b'},
      );
      expect(repository.uploads.firstWhere((r) => r.id == 'start-a').total, 88);
      expect(container.read(uploadQueueProvider), isEmpty);
      expect(await pendingStore.load(), isEmpty);
    },
  );

  test(
    'overlapping enqueues on the serial chain upload each exactly once '
    '(no double A, no dropped B)',
    () async {
      // A's flush parks on this gate, so B is enqueued while A is in flight —
      // forcing the two operations to overlap on the serial chain.
      final gate = Completer<void>();
      final repository = _BlockingSessionRepository(gate);
      final pendingStore = InMemoryPendingUploadsStore();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(initial: const SignedIn(AppUser(id: 'u1'))),
          ),
          sessionRepositoryProvider.overrideWithValue(repository),
          pendingUploadsStoreProvider.overrideWithValue(pendingStore),
        ],
      );
      addTearDown(container.dispose);

      final queue = container.read(uploadQueueProvider.notifier);
      // Enqueue A: its flush starts and parks on the slow (gated) upload.
      final enqueueA = queue.enqueue(_record('A', total: 11));
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      expect(repository.uploadedIds, isEmpty); // still parked on the gate

      // While A is in flight, enqueue B. On the serial chain it must wait its
      // turn — it cannot interleave with A's in-flight flush.
      final enqueueB = queue.enqueue(_record('B', total: 22));
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      expect(repository.uploadedIds, isEmpty); // B has not jumped ahead

      // Release the parked upload and let the whole chain drain.
      gate.complete();
      await enqueueA;
      await enqueueB;
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      await container.pump();

      // Each uploaded exactly once — no duplicate A, no dropped B.
      expect(repository.uploadedIds..sort(), <String>['A', 'B']);
      expect(repository.uploadedIds.where((id) => id == 'A'), hasLength(1));
      expect(repository.uploadedIds.where((id) => id == 'B'), hasLength(1));
      expect(container.read(uploadQueueProvider), isEmpty);
      expect(await pendingStore.load(), isEmpty);
    },
  );

  test(
    'a partial-failure flush uploads only the good record, keeps the bad one, '
    'and drains it on a later flush',
    () async {
      final repository = _SelectiveSessionRepository();
      final pendingStore = InMemoryPendingUploadsStore();
      // Two records waiting: one the repo will accept, one it will reject.
      await pendingStore.save(<SessionRecord>[
        _record('ok', total: 33),
        _record('bad', total: 44),
      ]);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(initial: const SignedIn(AppUser(id: 'u1'))),
          ),
          sessionRepositoryProvider.overrideWithValue(repository),
          pendingUploadsStoreProvider.overrideWithValue(pendingStore),
        ],
      );
      addTearDown(container.dispose);

      // First flush (app start): 'ok' uploads, 'bad' throws and stays queued.
      container.read(uploadQueueProvider);
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      await container.pump();

      expect(repository.uploadedIds, <String>['ok']);
      expect(container.read(uploadQueueProvider).map((r) => r.id), <String>[
        'bad',
      ]);
      expect((await pendingStore.load()).map((r) => r.id), <String>['bad']);

      // Once 'bad' starts succeeding, a second flush drains it.
      repository.heal = true;
      await container.read(uploadQueueProvider.notifier).flush();
      await container.pump();
      await Future<void>.delayed(Duration.zero);

      expect(repository.uploadedIds..sort(), <String>['bad', 'ok']);
      expect(container.read(uploadQueueProvider), isEmpty);
      expect(await pendingStore.load(), isEmpty);
    },
  );

  test(
    'loading a store pre-seeded with two records sharing an id keeps the last',
    () async {
      // A corrupt double-write: two persisted records share an id, the second
      // (the "last") carrying the newer data. Load must dedup to one record,
      // last-wins.
      final pendingStore = InMemoryPendingUploadsStore();
      await pendingStore.save(<SessionRecord>[
        _record('same', total: 11),
        _record('same', total: 99),
      ]);
      // Signed out so the load's flush no-ops and the loaded list is readable.
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          sessionRepositoryProvider.overrideWithValue(
            InMemorySessionRepository(),
          ),
          pendingUploadsStoreProvider.overrideWithValue(pendingStore),
        ],
      );
      addTearDown(container.dispose);

      // Building the queue loads and dedups the pending list.
      container.read(uploadQueueProvider);
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      await container.pump();

      final loaded = container.read(uploadQueueProvider);
      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'same');
      // The last record's data won (the dedup tiebreak).
      expect(loaded.single.total, 99);
    },
  );

  test('a session shot for a competition submits both the session and the '
      'result', () async {
    final sessionRepo = InMemorySessionRepository();
    final compRepo = _SpyCompetitionRepository();
    final container = makeContainer(
      auth: const SignedIn(AppUser(id: 'u1')),
      repository: sessionRepo,
      pendingStore: InMemoryPendingUploadsStore(),
      competitionRepository: compRepo,
    );
    addTearDown(container.dispose);
    container.read(uploadQueueProvider);
    await container.pump();

    await container
        .read(uploadQueueProvider.notifier)
        .enqueue(_record('s1', competitionId: 'c1'));
    await container.pump();

    expect(sessionRepo.uploads.map((r) => r.id), <String>['s1']);
    expect(compRepo.submittedIds, <String>['s1']);
    expect(container.read(uploadQueueProvider), isEmpty);
  });

  test(
    'a failed result submission keeps the record queued until it lands',
    () async {
      final sessionRepo = InMemorySessionRepository();
      final compRepo = _SpyCompetitionRepository()..fail = true;
      final container = makeContainer(
        auth: const SignedIn(AppUser(id: 'u1')),
        repository: sessionRepo,
        pendingStore: InMemoryPendingUploadsStore(),
        competitionRepository: compRepo,
      );
      addTearDown(container.dispose);
      container.read(uploadQueueProvider);
      await container.pump();

      await container
          .read(uploadQueueProvider.notifier)
          .enqueue(_record('s1', competitionId: 'c1'));
      await container.pump();

      // The session uploaded, but the result submission failed → still queued.
      expect(sessionRepo.uploads.map((r) => r.id), <String>['s1']);
      expect(compRepo.submittedIds, isEmpty);
      expect(
        container.read(uploadQueueProvider).map((r) => r.id),
        <String>['s1'],
      );

      // Heal and flush again → the result lands and the record is dropped (the
      // session re-upload is an idempotent no-op).
      compRepo.fail = false;
      await container.read(uploadQueueProvider.notifier).flush();
      await container.pump();
      expect(compRepo.submittedIds, <String>['s1']);
      expect(container.read(uploadQueueProvider), isEmpty);
    },
  );

  test('a personal session never submits a competition result', () async {
    final sessionRepo = InMemorySessionRepository();
    final compRepo = _SpyCompetitionRepository();
    final container = makeContainer(
      auth: const SignedIn(AppUser(id: 'u1')),
      repository: sessionRepo,
      pendingStore: InMemoryPendingUploadsStore(),
      competitionRepository: compRepo,
    );
    addTearDown(container.dispose);
    container.read(uploadQueueProvider);
    await container.pump();

    await container
        .read(uploadQueueProvider.notifier)
        .enqueue(_record('s1')); // no competitionId
    await container.pump();

    expect(sessionRepo.uploads.map((r) => r.id), <String>['s1']);
    expect(compRepo.submittedIds, isEmpty);
    expect(container.read(uploadQueueProvider), isEmpty);
  });
}
