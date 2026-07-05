// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/competitions/domain/competition_result.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/felt/data/felt_group_store.dart';
import 'package:treffpunkt/features/felt/data/felt_history_store.dart';
import 'package:treffpunkt/features/felt/data/felt_session_repository.dart';
import 'package:treffpunkt/features/felt/data/felt_session_store.dart';
import 'package:treffpunkt/features/felt/domain/felt_competition.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
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

/// The app's store of the last-used felt group (spec 0099). Defaults to
/// in-memory; `main()` overrides it with the `shared_preferences` one.
final feltGroupStoreProvider = Provider<FeltGroupStore>(
  (ref) => InMemoryFeltGroupStore(),
);

/// The last-used group loaded at launch (spec 0099), seeding the recorder.
/// `main()` reads the saved choice once and overrides this; defaults to
/// null, so a fresh app and every test start on the picker unless seeded.
final initialFeltGroupProvider = Provider<FeltShooterGroup?>((ref) => null);

/// The finished felt rounds, newest-first, watched by "Mine økter" (spec 0082).
final feltHistoryProvider = FutureProvider<List<FeltSessionRecord>>(
  (ref) => ref.watch(feltHistoryStoreProvider).load(),
);

/// Prepends [record] to the finished-round history and refreshes readers
/// (spec 0082). Upserts by id (spec 0091): a record saved again — the save
/// button pressed twice, or any repeated path — replaces its stored copy
/// instead of duplicating it.
Future<void> saveFeltRound(WidgetRef ref, FeltSessionRecord record) async {
  final store = ref.read(feltHistoryStoreProvider);
  final current = await store.load();
  await store.save(<FeltSessionRecord>[
    record,
    for (final round in current)
      if (round.id != record.id) round,
  ]);
  ref.invalidate(feltHistoryProvider);
}

/// Removes the finished round [id] from the local history and refreshes
/// readers (spec 0089).
Future<void> deleteFeltRound(WidgetRef ref, String id) async {
  final store = ref.read(feltHistoryStoreProvider);
  final current = await store.load();
  await store.save(<FeltSessionRecord>[
    for (final round in current)
      if (round.id != id) round,
  ]);
  ref.invalidate(feltHistoryProvider);
}

/// The account's felt-round sync backend (spec 0083). Defaults to in-memory;
/// `main()` overrides it with the Supabase repository.
final feltSessionRepositoryProvider = Provider<FeltSessionRepository>(
  (ref) => InMemoryFeltSessionRepository(),
);

/// The account's synced felt rounds, read in the background for "Mine økter"
/// (spec 0083). A failed read surfaces as this provider's error and is treated
/// as a non-blocking notice — the local rounds still show.
final feltSyncedSessionsProvider = FutureProvider<List<FeltSessionRecord>>(
  (ref) => ref.watch(feltSessionRepositoryProvider).list(),
);

/// Keeps finished felt rounds synced to the account (spec 0083): uploads the
/// local rounds on sign-in and at app start, and one round on finish. Kept
/// alive by the app root (like the ring upload queue); best-effort throughout.
final feltSyncProvider = NotifierProvider<FeltSyncNotifier, void>(
  FeltSyncNotifier.new,
);

/// The notifier behind [feltSyncProvider].
class FeltSyncNotifier extends Notifier<void> {
  Future<void>? _tail;

  @override
  void build() {
    ref.listen<AsyncValue<AuthStatus>>(authStateChangesProvider, (prev, next) {
      final wasSignedIn = prev?.value is SignedIn;
      final isSignedIn = next.value is SignedIn;
      if (isSignedIn && !wasSignedIn) unawaited(uploadAll());
    });
    unawaited(uploadAll());
  }

  bool get _signedIn {
    try {
      return ref.read(authStateChangesProvider).value is SignedIn;
    } on Object {
      return false;
    }
  }

  /// Uploads every locally-stored finished round (a sign-in / start reconcile).
  Future<void> uploadAll() => _run(() async {
    if (!_signedIn) return;
    final repository = ref.read(feltSessionRepositoryProvider);
    final local = await ref.read(feltHistoryStoreProvider).load();
    for (final round in local) {
      await repository.upload(round);
    }
  });

  /// Uploads one just-finished [record] (best-effort; a no-op when signed out).
  Future<void> uploadOne(FeltSessionRecord record) => _run(() async {
    if (!_signedIn) return;
    await ref.read(feltSessionRepositoryProvider).upload(record);
    await _submitResult(record);
  });

  /// Submits the round as a competition result (spec 0140): points as the
  /// total, inner hits as the tiebreak, the round as the payload — the
  /// felt mirror of the ring queue's submit. Idempotent by round id.
  Future<void> _submitResult(FeltSessionRecord record) async {
    final competitionId = record.competitionId;
    if (competitionId == null) return;
    final tally = record.tally;
    await ref
        .read(competitionRepositoryProvider)
        .submitResult(
          CompetitionResult(
            id: record.id,
            competitionId: competitionId,
            program: feltCompetitionProgram(record.session.group),
            total: tally.points,
            maxTotal: feltCourseMaxPoints(record.session.group),
            innerTens: tally.inner,
            capturedAt: record.capturedAt,
            payload: record.toJson(),
          ),
        );
  }

  Future<void> _run(Future<void> Function() task) {
    final previous = _tail ?? Future<void>.value();
    final next = previous.then((_) => task());
    _tail = next.catchError((Object _, StackTrace _) {});
    return next;
  }
}
