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
import 'package:treffpunkt/features/scoring/data/pending_uploads_store.dart';
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
/// A thin Riverpod shell over the shared [UploadQueueEngine] (ADR-0028), which
/// owns the queue algorithm: the serial task chain, dedup-by-id,
/// persist-before-upload and keep-on-failure. This notifier contributes the
/// ring-specific capabilities — the session repository, the pending-uploads
/// store, the competition-result fan-out (spec 0012) and the signed-in gate —
/// and mirrors the engine's pending list into its Riverpod state for the
/// screens that watch it. Every capability is **best-effort**: a throwing
/// repository or a failed persist never escapes, so the queue can never break
/// the completion flow.
class UploadQueueNotifier extends Notifier<List<SessionRecord>> {
  /// The shared queue engine, wired to this feature's capabilities. One engine
  /// per notifier instance, so its serial chain spans the notifier's lifetime.
  late final UploadQueueEngine<SessionRecord> _engine =
      UploadQueueEngine<SessionRecord>(
        idOf: (record) => record.id,
        load: _loadPending,
        persist: _persist,
        tryUpload: _tryUpload,
        isSignedIn: _isSignedIn,
        onState: (pending) => state = pending,
      );

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
    // and the engine mirrors `state` in as its chain resolves.
    unawaited(_engine.start());
    return <SessionRecord>[];
  }

  /// Enqueues [record], replacing any pending record with the same id, persists
  /// the list, then flushes (spec 0025).
  Future<void> enqueue(SessionRecord record) => _engine.enqueue(record);

  /// Removes the pending record [id] from the queue and its durable store (spec
  /// 0033), run on the serial chain so it never races a flush.
  Future<void> deleteById(String id) => _engine.deleteById(id);

  /// Attempts to upload every pending record, dropping the ones that succeed
  /// and keeping the ones that fail (spec 0025).
  Future<void> flush() => _engine.flush();

  /// Uploads [record] and, when it was shot for a competition (spec 0012), also
  /// submits its result; returns whether **everything** succeeded.
  ///
  /// Swallows every error so a throwing repository leaves the record queued
  /// instead of breaking flush. The record is dropped only when both the
  /// session upload and (if any) the result submission succeed; both are
  /// idempotent, so a retry of a partially-synced record re-runs safely.
  Future<bool> _tryUpload(SessionRecord record) async {
    try {
      await ref.read(sessionRepositoryProvider).upload(record);
    } on Object catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to upload a queued session: $error');
      }
      return false;
    }

    final competitionId = record.competitionId;
    if (competitionId != null) {
      try {
        await ref
            .read(competitionRepositoryProvider)
            .submitResult(
              CompetitionResult.fromSessionRecord(
                record,
                competitionId: competitionId,
              ),
            );
      } on Object catch (error) {
        if (!kReleaseMode) {
          debugPrint('Failed to submit the competition result: $error');
        }
        return false;
      }
    }
    return true;
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
