// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/data/image_source_service.dart';
import 'package:treffpunkt/features/scoring/data/location_service.dart';
import 'package:treffpunkt/features/scoring/data/pending_uploads_store.dart';
import 'package:treffpunkt/features/scoring/data/session_repository.dart';
import 'package:treffpunkt/features/scoring/data/session_store.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/series.dart';
import 'package:treffpunkt/features/scoring/domain/session.dart';
import 'package:treffpunkt/features/scoring/domain/session_metadata.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/domain/session_snapshot.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/presentation/upload_queue.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';
import 'package:uuid/uuid.dart';

/// The program being recorded on the current screen.
///
/// Overridden where a session screen is mounted; the default throws so a
/// forgotten override fails loudly instead of guessing a discipline.
final currentProgramDefinitionProvider = Provider<ProgramDefinition>(
  (ref) =>
      throw UnimplementedError('override currentProgramDefinitionProvider'),
);

/// The metadata (when and where) captured for the current session, or `null`.
///
/// Overridden by the screen that mounts the session with the values gathered in
/// the setup step (spec 0008); defaults to `null` (no metadata).
final currentSessionMetadataProvider = Provider<SessionMetadata?>(
  (ref) => null,
);

/// The weapon chosen for the current session, or `null` when none was picked.
///
/// Overridden by the screen that mounts the session with the weapon chosen in
/// the setup step (spec 0008 wiring); defaults to `null` (no weapon).
final currentWeaponProvider = Provider<Weapon?>((ref) => null);

/// The competition this session is being shot for (spec 0012), or `null` for a
/// personal session. Overridden by `SeriesScreen` when launched from a
/// competition; read at completion to tag the record so the upload queue also
/// submits a result.
final currentCompetitionIdProvider = Provider<String?>((ref) => null);

/// The app's [SessionStore] for offline persistence (spec 0009).
///
/// Defaults to an in-memory store so tests and a fresh app never touch real
/// storage; `main()` overrides it with the `shared_preferences`-backed store.
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => InMemorySessionStore(),
);

/// The app's [SessionRepository] for uploading completed sessions (spec 0024).
///
/// Defaults to an in-memory repository so tests and the integration harness
/// never reach a real backend; `main()` overrides it with the Supabase-backed
/// repository.
final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => InMemorySessionRepository(),
);

/// The app's [PendingUploadsStore] for the upload queue (spec 0025).
///
/// Defaults to an in-memory store so tests and the integration harness never
/// touch real storage; `main()` overrides it with the `shared_preferences`-
/// backed store. The completed sessions waiting to upload live here (the
/// durable outbox behind [uploadQueueProvider]).
final pendingUploadsStoreProvider = Provider<PendingUploadsStore>(
  (ref) => InMemoryPendingUploadsStore(),
);

/// Mints a new stable client-generated id for a recording (spec 0024).
///
/// Defaults to a random UUID v4. Overridden in tests with a deterministic
/// generator so the id under test is predictable. The domain never reads this —
/// the id is generated here in the presentation layer and supplied to the value
/// types — so the domain stays pure (ADR-0017).
final sessionIdGeneratorProvider = Provider<String Function()>(
  (ref) => const Uuid().v4,
);

/// A recording to resume into, or `null` to start fresh (spec 0009).
///
/// Overridden by the screen that resumes a saved session; the notifier reads it
/// in `build` and seeds its state from it instead of starting a new session.
final restoredRecordingProvider = Provider<SessionRecording?>((ref) => null);

/// The saved active recording read back from the [sessionStoreProvider], or
/// `null` when none is stored (spec 0009).
///
/// The program picker watches this to offer a "resume" affordance.
final savedRecordingProvider = FutureProvider<SessionRecording?>((ref) async {
  final snapshot = await ref.watch(sessionStoreProvider).load();
  if (snapshot == null) return null;
  return SessionRecording.fromSnapshot(
    snapshot,
    fallbackId: ref.watch(sessionIdGeneratorProvider),
  );
});

/// The app's [LocationService].
///
/// Defaults to one that never has a fix, so "use my location" degrades to
/// manual entry until a real GPS implementation is wired (ADR-0015). Overridden
/// in tests with a fake.
final locationServiceProvider = Provider<LocationService>(
  (ref) => const UnavailableLocationService(),
);

/// The app's [ImageSourceService] for the camera "Skann skive" scan (0039).
///
/// Defaults to one that can never pick an image, so the scan feature degrades
/// cleanly until the real `image_picker`-backed service is wired; `main()`
/// overrides it. Tests inject a fake.
final imageSourceServiceProvider = Provider<ImageSourceService>(
  (ref) => const UnavailableImageSourceService(),
);

/// The in-progress session together with the current (unsealed) series and its
/// drag state.
class SessionRecording {
  /// Creates a recording with the stable client-generated [id] (spec 0024).
  const SessionRecording({
    required this.session,
    required this.id,
    this.current,
    this.draggingIndex,
  });

  /// Rebuilds a recording from a stored [snapshot] (spec 0009).
  ///
  /// Keeps the snapshot's [SessionSnapshot.id] so a resumed session uploads
  /// under the same id (spec 0024); a snapshot written before spec 0024 has no
  /// id, so [fallbackId] mints a fresh one.
  SessionRecording.fromSnapshot(
    SessionSnapshot snapshot, {
    required String Function() fallbackId,
  }) : session = snapshot.session,
       current = snapshot.current,
       id = snapshot.id ?? fallbackId(),
       draggingIndex = null;

  /// The session so far (sealed series, grouped by stage).
  final Session session;

  /// The recording's stable client-generated id; the upload key (spec 0024).
  final String id;

  /// The series currently being shot, or `null` when the session is complete.
  final Series? current;

  /// The index of the shot being dragged in [current], or `null`.
  final int? draggingIndex;

  /// Whether the whole session is complete (no current series).
  bool get isComplete => session.isComplete;

  /// Whether a placed shot is currently picked up.
  bool get isDragging => draggingIndex != null;

  /// A persistable snapshot of this recording (drops the transient drag state).
  SessionSnapshot toSnapshot() =>
      SessionSnapshot(session: session, current: current, id: id);
}

/// Records a guided session: placing shots in the current series, then sealing
/// it to advance to the next series or stage.
class SessionNotifier extends Notifier<SessionRecording> {
  static const ScoringService _scoring = ScoringService();

  @override
  SessionRecording build() {
    final restored = ref.watch(restoredRecordingProvider);
    if (restored != null) return restored;
    final program = ref.watch(currentProgramDefinitionProvider);
    final metadata = ref.watch(currentSessionMetadataProvider);
    final weapon = ref.watch(currentWeaponProvider);
    final session = Session.start(
      program,
      metadata: metadata,
      weapon: weapon,
    );
    return SessionRecording(
      session: session,
      // A stable client-generated id minted once when recording starts; it
      // survives a save/resume because it is serialized in the snapshot (spec
      // 0024). A resumed recording keeps its own id via the restored branch.
      id: ref.read(sessionIdGeneratorProvider)(),
      current: session.newSeries(),
    );
  }

  /// Enqueues the completed session onto the durable upload queue (spec 0025).
  ///
  /// Fire-and-forget and best-effort: it never blocks reaching the scorecard,
  /// and the queue swallows any storage or upload error. Enqueuing (not a
  /// direct upload) is what makes completion loss-proof: the record is
  /// persisted the instant it is enqueued and flushed (uploaded, then removed)
  /// whenever possible, so a session finished offline or signed out uploads
  /// itself later. Idempotent by the recording's id (the queue dedups by it).
  void _enqueueCompletedSession() {
    final session = state.session;
    final record = SessionRecord.fromSession(
      session,
      _scoring.scoreSession(session),
      id: state.id,
      competitionId: ref.read(currentCompetitionIdProvider),
    );
    // Read the queue notifier synchronously (the provider may be disposed
    // before a deferred read runs), but do not await the enqueue: it is
    // fire-and-forget off the happy path. A synchronous throw (e.g. the queue's
    // auth providers are not wired in a scoring-only screen scope) is caught
    // here and a rejected future is swallowed, so it never breaks completion.
    try {
      unawaited(
        ref.read(uploadQueueProvider.notifier).enqueue(record).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          if (!kReleaseMode) {
            debugPrint('Failed to enqueue the completed session: $error');
          }
        }),
      );
    } on Object catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to enqueue the completed session: $error');
      }
    }
  }

  /// Saves the recording locally so it survives a restart (spec 0009), or
  /// clears the store once the session is complete so it never resurfaces.
  void _persist() {
    final store = ref.read(sessionStoreProvider);
    final write = state.isComplete
        ? store.clear()
        : store.save(state.toSnapshot());
    // Persistence is best-effort and off the happy path (losing one autosave is
    // not fatal — the in-memory recording is the source of truth this run), but
    // a silent failure would be undiagnosable, so surface it in debug builds.
    unawaited(
      write.catchError((Object error, StackTrace stackTrace) {
        if (!kReleaseMode) {
          debugPrint('Failed to persist the session recording: $error');
        }
      }),
    );
  }

  /// Places the next shot in the current series, unless it is full.
  void placeShot(Shot shot) {
    final current = state.current;
    if (current == null || current.isComplete) return;
    state = SessionRecording(
      session: state.session,
      id: state.id,
      current: current.placeShot(shot),
      draggingIndex: state.draggingIndex,
    );
    _persist();
  }

  /// Appends [shots] to the current series in firing order, stopping when it is
  /// full (spec 0039). Persists once and never seals/advances on its own.
  ///
  /// The camera scan commits a whole photo's shots in one call: extra shots
  /// beyond the series' capacity are dropped (so a stray tap can't overflow),
  /// and sealing stays the existing manual gesture so a scan that fills the
  /// series behaves exactly like tapping the last shot by hand.
  void placeShots(List<Shot> shots) {
    final current = state.current;
    if (current == null) return;
    var next = current;
    for (final shot in shots) {
      if (next.isComplete) break;
      next = next.placeShot(shot);
    }
    if (identical(next, current)) return;
    state = SessionRecording(
      session: state.session,
      id: state.id,
      current: next,
      draggingIndex: state.draggingIndex,
    );
    _persist();
  }

  /// Picks up the placed shot at [index] in the current series.
  void pickUp(int index) {
    if (state.current == null) return;
    state = SessionRecording(
      session: state.session,
      id: state.id,
      current: state.current,
      draggingIndex: index,
    );
  }

  /// Moves the picked-up shot to [shot].
  void dragTo(Shot shot) {
    final current = state.current;
    final index = state.draggingIndex;
    if (current == null || index == null) return;
    state = SessionRecording(
      session: state.session,
      id: state.id,
      current: current.moveShot(index, shot),
      draggingIndex: index,
    );
    _persist();
  }

  /// Drops the picked-up shot, ending the drag.
  void drop() => state = SessionRecording(
    session: state.session,
    id: state.id,
    current: state.current,
  );

  /// Seals the current (full) series and advances to the next series or stage,
  /// completing the session after the last series.
  void advance() {
    final current = state.current;
    if (current == null || !current.isComplete) return;
    final next = state.session.sealSeries(current);
    state = SessionRecording(
      session: next,
      id: state.id,
      current: next.newSeries(),
    );
    _persist();
    // Sealing the last series completes the session: enqueue it on the durable
    // upload queue (spec 0025), which persists it (so it is never lost) and
    // flushes it whenever possible. Fire-and-forget and best-effort, so it
    // never blocks reaching the scorecard.
    if (state.isComplete) _enqueueCompletedSession();
  }
}

/// The current session recording.
final sessionProvider = NotifierProvider<SessionNotifier, SessionRecording>(
  SessionNotifier.new,
);
