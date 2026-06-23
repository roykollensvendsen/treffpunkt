// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/scoring/data/pending_uploads_store.dart';
import 'package:treffpunkt/features/scoring/data/session_repository.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

/// The durable upload queue for completed sessions (spec 0025).
///
/// A completed session is [enqueue]d here the instant it finishes (persisted to
/// the [PendingUploadsStore] so it survives a restart) and [flush]ed (uploaded,
/// then removed) whenever that becomes possible: on completion, on app start,
/// and when the user signs in. So no completed session is ever lost; a session
/// finished offline or signed out uploads itself automatically later.
///
/// The state is the list of records still waiting to upload, deduplicated by
/// [SessionRecord.id] (enqueuing the same id twice keeps one, the latest
/// winning, an idempotent upsert like the repository). Every operation is
/// **best-effort**: a throwing repository or a failed persist never escapes, so
/// the queue can never break the completion flow, and a failed upload simply
/// leaves the record queued for the next flush.
///
/// All mutating operations run **serially** on a single task chain
/// ([_run]/[_tail]), so the asynchronous load, an [enqueue] and a [flush] can
/// never interleave: no record is double-uploaded and no race drops one. Each
/// task is a single pass, so the queue cannot spin (ADR-0013).
class UploadQueueNotifier extends Notifier<List<SessionRecord>> {
  /// The tail of the serial task chain; `null` when idle.
  Future<void>? _tail;

  @override
  List<SessionRecord> build() {
    // Flush whenever auth transitions into signed-in: a record queued while
    // signed out can now go up. A single flush per transition (no re-subscribe
    // loop, no timer) — Riverpod tears the listener down with the provider.
    ref.listen<AsyncValue<AuthStatus>>(authStateChangesProvider, (
      previous,
      next,
    ) {
      final wasSignedIn = previous?.value is SignedIn;
      final isSignedIn = next.value is SignedIn;
      if (isSignedIn && !wasSignedIn) {
        unawaited(flush());
      }
    });

    // Load any records waiting from a previous run and flush them (app start).
    // Chained first, so the load completes before any enqueue runs against the
    // loaded list. Fire-and-forget: `build` returns the synchronous empty list
    // and the chain updates `state` as it resolves.
    unawaited(_run(_loadThenState));
    return <SessionRecord>[];
  }

  /// Enqueues [record], replacing any pending record with the same id, persists
  /// the list, then flushes (spec 0025).
  ///
  /// Dedup-by-id keeps the upsert semantics of the whole pipeline: a session
  /// enqueued twice (e.g. a resumed-then-re-completed one) stays one record.
  /// Persisting **before** the upload is what guarantees no loss: the record is
  /// durable the instant it is enqueued, even if the upload then fails or the
  /// app dies mid-upload.
  Future<void> enqueue(SessionRecord record) => _run(() async {
    state = _dedupById(<SessionRecord>[
      for (final pending in state)
        if (pending.id != record.id) pending,
      record,
    ]);
    await _persist(state);
    await _flushOnce();
  });

  /// Attempts to upload every pending record, dropping the ones that succeed
  /// and keeping the ones that fail (spec 0025).
  ///
  /// A no-op when signed out (the records stay queued, unchanged). One pass
  /// over the pending list, run on the serial chain so it never overlaps
  /// another operation: the queue cannot spin (ADR-0013) and a record is never
  /// double-uploaded. Fully best-effort: a throwing repository never escapes.
  Future<void> flush() => _run(_flushOnce);

  /// Runs [task] after any in-flight operation, keeping all mutations serial.
  ///
  /// Chaining on [_tail] (and swallowing a failed predecessor so one failure
  /// cannot poison the chain) means the asynchronous load, an [enqueue] and a
  /// [flush] execute one at a time, in order — no interleaving, no race.
  Future<void> _run(Future<void> Function() task) {
    final previous = _tail ?? Future<void>.value();
    final next = previous.then((_) => task());
    _tail = next.catchError((Object _, StackTrace _) {});
    return next;
  }

  /// Loads the persisted pending list (deduplicated) into [state], then flushes
  /// it (app start).
  Future<void> _loadThenState() async {
    state = _dedupById(await _loadPending());
    await _flushOnce();
  }

  /// One flush pass: upload each pending record, drop the ones that succeed and
  /// keep the ones that fail, then persist the remainder.
  Future<void> _flushOnce() async {
    if (!_isSignedIn()) return;
    final repository = ref.read(sessionRepositoryProvider);
    final remaining = <SessionRecord>[];
    for (final record in state) {
      if (!await _tryUpload(repository, record)) {
        remaining.add(record);
      }
    }
    state = remaining;
    await _persist(remaining);
  }

  /// Uploads [record], returning whether it succeeded; swallows every error so
  /// a throwing repository leaves the record queued instead of breaking flush.
  Future<bool> _tryUpload(
    SessionRepository repository,
    SessionRecord record,
  ) async {
    try {
      await repository.upload(record);
      return true;
    } on Object catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to upload a queued session: $error');
      }
      return false;
    }
  }

  /// Whether a user is currently signed in (best-effort, like the notifier).
  bool _isSignedIn() {
    try {
      return ref.read(authStateChangesProvider).value is SignedIn;
    } on Object {
      return false;
    }
  }

  /// Loads the persisted pending list; an unreadable store yields an empty list
  /// rather than breaking startup.
  Future<List<SessionRecord>> _loadPending() async {
    try {
      return await ref.read(pendingUploadsStoreProvider).load();
    } on Object catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to load the pending uploads: $error');
      }
      return <SessionRecord>[];
    }
  }

  /// Persists [records]; best-effort, so a write failure never breaks the queue
  /// (the in-memory state is authoritative this run).
  Future<void> _persist(List<SessionRecord> records) async {
    try {
      await ref.read(pendingUploadsStoreProvider).save(records);
    } on Object catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to persist the pending uploads: $error');
      }
    }
  }

  /// Keeps the last record per id, preserving order — an idempotent upsert.
  static List<SessionRecord> _dedupById(List<SessionRecord> records) {
    final byId = <String, SessionRecord>{};
    for (final record in records) {
      byId[record.id] = record;
    }
    return List<SessionRecord>.unmodifiable(byId.values);
  }
}

/// The app's upload queue (spec 0025).
///
/// A plain (non-`autoDispose`) `NotifierProvider`, so the notifier is **never**
/// torn down: the always-mounted app root (`TreffpunktApp`) watches it to build
/// it eagerly at app start, and being kept alive guarantees one long-lived
/// notifier — its startup load+flush runs once and its sign-in listener stays
/// registered for the whole app session, so a sign-in transition while the user
/// is merely browsing still flushes the queue.
final uploadQueueProvider =
    NotifierProvider<UploadQueueNotifier, List<SessionRecord>>(
      UploadQueueNotifier.new,
    );
