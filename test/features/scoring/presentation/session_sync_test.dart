// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Provider tests for the auto-upload on completion (spec 0024): completing a
// session while signed in uploads exactly one record (idempotent by a stable
// id); signed out uploads nothing; a throwing repository never breaks
// completion.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/auth/domain/app_user.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/scoring/data/session_repository.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/series.dart';
import 'package:treffpunkt/features/scoring/domain/session.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/domain/session_snapshot.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

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
// A multi-series program: one stage of two series of two shots each, so the
// session needs two seals to complete — the first seal is intermediate (not
// final). Pins that the upload fires only on completion, not on every advance.
const ProgramDefinition _multiSeriesProgram = ProgramDefinition(
  name: 'Multi',
  discipline: Discipline.pistol,
  stages: <StageDefinition>[
    StageDefinition(
      name: 'A',
      geometry: TargetGeometry.pistol25mPrecision(),
      shotsPerSeries: 2,
      seriesCount: 2,
    ),
  ],
);
const Shot _centre = Shot(dxMm: 0, dyMm: 0);

/// A repository whose [upload] always throws, to prove the upload is swallowed.
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

/// A repository that only counts uploads, to pin upload-exactly-once.
class _CountingSessionRepository implements SessionRepository {
  int callCount = 0;

  @override
  Future<void> upload(SessionRecord record) async {
    callCount++;
  }

  @override
  Future<List<SessionRecord>> list() async => const <SessionRecord>[];
}

void main() {
  ProviderContainer makeContainer({
    required AuthStatus auth,
    required SessionRepository repository,
    String id = 'fixed-id',
    SessionRecording? restored,
  }) {
    return ProviderContainer(
      overrides: [
        currentProgramDefinitionProvider.overrideWithValue(_program),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(initial: auth),
        ),
        sessionRepositoryProvider.overrideWithValue(repository),
        sessionIdGeneratorProvider.overrideWithValue(() => id),
        restoredRecordingProvider.overrideWithValue(restored),
      ],
    );
  }

  void completeSession(ProviderContainer container) {
    final notifier = container.read(sessionProvider.notifier)
      ..placeShot(_centre)
      ..placeShot(_centre)
      ..advance();
    expect(notifier, isNotNull);
    expect(container.read(sessionProvider).isComplete, isTrue);
  }

  // Completion now enqueues onto the durable upload queue (spec 0025), which
  // persists then flushes the record across a few async hops; drain those
  // fire-and-forget microtasks before asserting on the repository.
  Future<void> settle(ProviderContainer container) async {
    for (var i = 0; i < 3; i++) {
      await container.pump();
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('completing while signed in uploads exactly one record with the '
      'recording id and score', () async {
    final repository = InMemorySessionRepository();
    final container = makeContainer(
      auth: const SignedIn(AppUser(id: 'u1')),
      repository: repository,
      id: 'recording-1',
    );
    addTearDown(container.dispose);

    completeSession(container);
    await settle(container);

    expect(repository.uploads, hasLength(1));
    final record = repository.uploads.single;
    expect(record.id, 'recording-1');
    expect(record.program, 'Test');
    // Two centre tens = 20, both inner tens.
    expect(record.total, 20);
    expect(record.innerTens, 2);
  });

  test(
    'a multi-series session uploads exactly once, only on completion',
    () async {
      // Sealing an intermediate (non-final) series must NOT upload; only
      // completing the whole program does, exactly once. The id-keyed
      // idempotency would mask an upload-per-`advance` regression, so this
      // counts the calls directly rather than the distinct records.
      final repository = _CountingSessionRepository();
      final container = ProviderContainer(
        overrides: [
          currentProgramDefinitionProvider.overrideWithValue(
            _multiSeriesProgram,
          ),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(initial: const SignedIn(AppUser(id: 'u1'))),
          ),
          sessionRepositoryProvider.overrideWithValue(repository),
          sessionIdGeneratorProvider.overrideWithValue(() => 'multi-id'),
          restoredRecordingProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      // Seal the first (intermediate) series: not complete, nothing uploaded.
      container.read(sessionProvider.notifier)
        ..placeShot(_centre)
        ..placeShot(_centre)
        ..advance();
      await settle(container);
      expect(container.read(sessionProvider).isComplete, isFalse);
      expect(repository.callCount, 0);

      // Seal the second (final) series: now complete, uploaded exactly once.
      container.read(sessionProvider.notifier)
        ..placeShot(_centre)
        ..placeShot(_centre)
        ..advance();
      await settle(container);
      expect(container.read(sessionProvider).isComplete, isTrue);
      expect(repository.callCount, 1);
    },
  );

  test(
    'the id is stable across resume: the upload carries the snapshot id',
    () async {
      // A recording resumed from a snapshot keeps the snapshot's id, not a
      // fresh generated one, so the upload upserts the same row.
      final session = Session.start(_program);
      final snapshot = SessionSnapshot(
        session: session,
        current: Series(
          geometry: _program.stages.first.geometry,
          capacity: 2,
        ).placeShot(_centre),
        id: 'resumed-id',
      );
      final repository = InMemorySessionRepository();
      final container = makeContainer(
        auth: const SignedIn(AppUser(id: 'u1')),
        repository: repository,
        // A *different* fresh id, to prove the resumed id wins.
        id: 'fresh-id',
        restored: SessionRecording.fromSnapshot(
          snapshot,
          fallbackId: () => 'fresh-id',
        ),
      );
      addTearDown(container.dispose);

      expect(container.read(sessionProvider).id, 'resumed-id');

      // Finish the in-progress series (one shot already placed), then seal.
      container.read(sessionProvider.notifier)
        ..placeShot(_centre)
        ..advance();
      await settle(container);

      expect(container.read(sessionProvider).isComplete, isTrue);
      expect(repository.uploads.single.id, 'resumed-id');
    },
  );

  test('completing while signed out uploads nothing', () async {
    final repository = InMemorySessionRepository();
    final container = makeContainer(
      auth: const SignedOut(),
      repository: repository,
    );
    addTearDown(container.dispose);

    completeSession(container);
    await settle(container);

    expect(repository.uploads, isEmpty);
  });

  test(
    'two completions with the same id stay idempotent (one record)',
    () async {
      final repository = InMemorySessionRepository();

      // First completion under id "dup".
      final first = makeContainer(
        auth: const SignedIn(AppUser(id: 'u1')),
        repository: repository,
        id: 'dup',
      );
      completeSession(first);
      await settle(first);
      first.dispose();

      // A second, independent completion under the same id (e.g. a resumed,
      // re-completed session) upserts the same row.
      final second = makeContainer(
        auth: const SignedIn(AppUser(id: 'u1')),
        repository: repository,
        id: 'dup',
      );
      completeSession(second);
      await settle(second);
      second.dispose();

      expect(repository.uploads, hasLength(1));
      expect(repository.uploads.single.id, 'dup');
    },
  );

  test('a repository whose upload throws does not break completion', () async {
    final repository = _ThrowingSessionRepository();
    final container = makeContainer(
      auth: const SignedIn(AppUser(id: 'u1')),
      repository: repository,
    );
    addTearDown(container.dispose);

    // Completing must not throw even though the repository does.
    completeSession(container);
    await settle(container);

    expect(repository.callCount, 1);
    // The UI state is intact: the session reached the complete state.
    expect(container.read(sessionProvider).isComplete, isTrue);
  });
}
