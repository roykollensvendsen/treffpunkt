// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/sync/upload_queue_engine.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/competitions/domain/competition_result.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/felt/data/felt_history_store.dart';
import 'package:treffpunkt/features/felt/data/felt_pending_uploads_store.dart';
import 'package:treffpunkt/features/felt/data/felt_session_repository.dart';
import 'package:treffpunkt/features/felt/data/felt_session_store.dart';
import 'package:treffpunkt/features/felt/domain/felt_competition.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';

/// The app's felt-session store for save/resume (spec 0081). Defaults to the
/// in-memory store; `main()` overrides it with the `shared_preferences` one.
final feltSessionStoreProvider = Provider<FeltSessionStore>(
  (ref) => InMemoryFeltSessionStore(),
);

/// The saved in-progress felt round read back from the store, or null. Watched
/// by the course preview to show the "Fortsett felt-økt" card (spec 0081).
final feltSavedSessionProvider = FutureProvider<FeltSessionSnapshot?>(
  (ref) => ref.watch(feltSessionStoreProvider).load(),
);

/// The app's store of finished felt rounds (spec 0082). Defaults to in-memory;
/// `main()` overrides it with the `shared_preferences` one.
final feltHistoryStoreProvider = Provider<FeltHistoryStore>(
  (ref) => InMemoryFeltHistoryStore(),
);

/// The finished felt rounds, newest-first, watched by "Mine økter" (spec 0082).
final feltHistoryProvider = FutureProvider<List<FeltSessionRecord>>(
  (ref) => ref.watch(feltHistoryStoreProvider).load(),
);

/// Prepends [record] to the finished-round history and refreshes readers
/// (spec 0082). Upserts by id (spec 0091): a record saved again — the save
/// button pressed twice, or any repeated path — replaces its stored copy
/// instead of duplicating it. The saved round is also enqueued on the durable
/// upload queue (spec 0144), fire-and-forget so the save never waits on the
/// network: the enqueue persists the round before any upload attempt.
Future<void> saveFeltRound(WidgetRef ref, FeltSessionRecord record) async {
  final store = ref.read(feltHistoryStoreProvider);
  final current = await store.load();
  await store.save(<FeltSessionRecord>[
    record,
    for (final round in current)
      if (round.id != record.id) round,
  ]);
  ref.invalidate(feltHistoryProvider);
  unawaited(
    ref
        .read(feltSyncProvider.notifier)
        .enqueue(record)
        .catchError((Object _) {}),
  );
}

/// Removes the finished round [id] from the local history — and from the
/// durable upload queue (spec 0144), so a deleted round can never upload
/// afterwards — and refreshes readers (spec 0089).
Future<void> deleteFeltRound(WidgetRef ref, String id) async {
  final store = ref.read(feltHistoryStoreProvider);
  final current = await store.load();
  await store.save(<FeltSessionRecord>[
    for (final round in current)
      if (round.id != id) round,
  ]);
  await ref.read(feltSyncProvider.notifier).deleteById(id);
  ref.invalidate(feltHistoryProvider);
}

/// The account's felt-round sync backend (spec 0083). Defaults to in-memory;
/// `main()` overrides it with the Supabase repository.
final feltSessionRepositoryProvider = Provider<FeltSessionRepository>(
  (ref) => InMemoryFeltSessionRepository(),
);

/// The durable store behind the felt upload queue (spec 0144). Defaults to
/// in-memory; `main()` overrides it with the `shared_preferences` one, like
/// the ring's pending-uploads store (spec 0025).
final feltPendingUploadsStoreProvider = Provider<FeltPendingUploadsStore>(
  (ref) => InMemoryFeltPendingUploadsStore(),
);

/// The account's synced felt rounds, read in the background for "Mine økter"
/// (spec 0083). A failed read surfaces as this provider's error and is treated
/// as a non-blocking notice — the local rounds still show.
final feltSyncedSessionsProvider = FutureProvider<List<FeltSessionRecord>>(
  (ref) => ref.watch(feltSessionRepositoryProvider).list(),
);

/// The durable upload queue for finished felt rounds (spec 0144).
///
/// A finished round is enqueued here the instant it is saved (persisted to the
/// [FeltPendingUploadsStore] so it survives a restart or an offline session)
/// and flushed — uploaded *and*, for a competition round, its result submitted
/// (spec 0140) — whenever that becomes possible: on save, on app start, and
/// when the user signs in. Kept alive by the app root (like the ring upload
/// queue); best-effort throughout.
final feltSyncProvider =
    NotifierProvider<FeltSyncNotifier, List<FeltSessionRecord>>(
      FeltSyncNotifier.new,
    );

/// The notifier behind [feltSyncProvider].
///
/// A thin Riverpod shell over the shared [UploadQueueEngine] (ADR-0028), which
/// owns the queue algorithm: the serial task chain, dedup-by-id,
/// persist-before-upload and keep-on-failure. This notifier contributes the
/// felt-specific capabilities — the felt-session repository, the pending
/// store, the competition-result fan-out (spec 0140) and the signed-in gate —
/// and mirrors the engine's pending list into its Riverpod state. Every
/// capability is **best-effort**: a throwing repository or a failed persist
/// never escapes, so the queue can never break the save flow.
class FeltSyncNotifier extends Notifier<List<FeltSessionRecord>> {
  /// The shared queue engine, wired to this feature's capabilities. One engine
  /// per notifier instance, so its serial chain spans the notifier's lifetime.
  late final UploadQueueEngine<FeltSessionRecord> _engine =
      UploadQueueEngine<FeltSessionRecord>(
        idOf: (record) => record.id,
        load: _loadPending,
        persist: _persist,
        tryUpload: _tryUpload,
        isSignedIn: _isSignedIn,
        onState: (pending) => state = pending,
      );

  @override
  List<FeltSessionRecord> build() {
    // Flush whenever auth transitions into signed-in: a round queued while
    // signed out can now go up. A single flush per transition (no re-subscribe
    // loop, no timer) — Riverpod tears the listener down with the provider.
    ref.listen<AsyncValue<AuthStatus>>(authStateChangesProvider, (prev, next) {
      final wasSignedIn = prev?.value is SignedIn;
      final isSignedIn = next.value is SignedIn;
      if (isSignedIn && !wasSignedIn) unawaited(flush());
    });

    // Load any rounds waiting from a previous run and flush them (app start).
    // Chained first, so the load completes before any enqueue runs against the
    // loaded list. Fire-and-forget: `build` returns the synchronous empty list
    // and the engine mirrors `state` in as its chain resolves.
    unawaited(_engine.start());
    return <FeltSessionRecord>[];
  }

  /// Enqueues [record], replacing any pending round with the same id, persists
  /// the list, then flushes (spec 0144).
  Future<void> enqueue(FeltSessionRecord record) => _engine.enqueue(record);

  /// Removes the pending round [id] from the queue and its durable store (spec
  /// 0144), run on the serial chain so it never races a flush.
  Future<void> deleteById(String id) => _engine.deleteById(id);

  /// Attempts to upload every pending round, dropping the ones that succeed
  /// and keeping the ones that fail (spec 0144).
  Future<void> flush() => _engine.flush();

  /// Uploads [record] and, when it was shot for a competition (spec 0140),
  /// also submits its result; returns whether **everything** succeeded.
  ///
  /// Swallows every error so a throwing repository leaves the round queued
  /// instead of breaking flush. The round is dropped only when both the upload
  /// and (if any) the result submission succeed; both are idempotent, so a
  /// retry of a partially-synced round re-runs safely.
  Future<bool> _tryUpload(FeltSessionRecord record) async {
    try {
      await ref.read(feltSessionRepositoryProvider).upload(record);
    } on Object catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to upload a queued felt round: $error');
      }
      return false;
    }

    try {
      await _submitResult(record);
    } on Object catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to submit the felt competition result: $error');
      }
      return false;
    }
    return true;
  }

  /// Submits the round as a competition result (spec 0140): points as the
  /// total, inner hits as the tiebreak, the round as the payload — the
  /// felt mirror of the ring queue's submit. Idempotent by round id — the
  /// result id is [feltCompetitionResultId] of the round id, a deterministic
  /// uuid, because the backend's id column is `uuid` and the raw radix-36
  /// round id is rejected (22P02). A no-op for a training round.
  Future<void> _submitResult(FeltSessionRecord record) async {
    final competitionId = record.competitionId;
    if (competitionId == null) return;
    final tally = record.tally;
    // The round's own course names the program and sets the maximum (spec
    // 0145); a pre-0145 round has no course id and resolves to 2026.
    final course = feltCourseById(record.session.courseId);
    await ref
        .read(competitionRepositoryProvider)
        .submitResult(
          CompetitionResult(
            id: feltCompetitionResultId(record.id),
            competitionId: competitionId,
            program: feltCompetitionProgram(course, record.session.group),
            total: tally.points,
            maxTotal: course.maxPoints(record.session.group),
            innerTens: tally.inner,
            capturedAt: record.capturedAt,
            payload: record.toJson(),
          ),
        );
  }

  /// Whether a user is currently signed in (best-effort, like the notifier).
  bool _isSignedIn() {
    try {
      return ref.read(authStateChangesProvider).value is SignedIn;
    } on Object {
      return false;
    }
  }

  /// Loads the persisted pending list; an unreadable store yields an empty
  /// list rather than breaking startup.
  Future<List<FeltSessionRecord>> _loadPending() async {
    try {
      return await ref.read(feltPendingUploadsStoreProvider).load();
    } on Object catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to load the pending felt uploads: $error');
      }
      return <FeltSessionRecord>[];
    }
  }

  /// Persists [records]; best-effort, so a write failure never breaks the
  /// queue (the in-memory state is authoritative this run).
  Future<void> _persist(List<FeltSessionRecord> records) async {
    try {
      await ref.read(feltPendingUploadsStoreProvider).save(records);
    } on Object catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to persist the pending felt uploads: $error');
      }
    }
  }
}
