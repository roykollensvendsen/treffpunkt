// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/scoring/data/location_service.dart';
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

  /// Uploads the completed session to the shooter's account when signed in
  /// (spec 0024).
  ///
  /// Fire-and-forget and best-effort: it runs only when signed in, never blocks
  /// the UI, and a throwing repository is swallowed so completion is unharmed.
  /// Idempotent by the recording's id — a re-upload (e.g. a resumed-then-
  /// completed session) overwrites the same row.
  void _uploadIfSignedIn() {
    if (!_isSignedIn()) return;
    final session = state.session;
    final record = SessionRecord.fromSession(
      session,
      _scoring.scoreSession(session),
      id: state.id,
    );
    // Read the repository and invoke the upload synchronously (the provider may
    // be disposed before a deferred read runs), but do not await it — it is
    // fire-and-forget off the happy path. A synchronous throw is caught here
    // and a rejected future is swallowed by `catchError`, so a throwing
    // repository can never break completion (the real Supabase repo also
    // swallows internally).
    final repository = ref.read(sessionRepositoryProvider);
    try {
      unawaited(
        repository.upload(record).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          if (!kReleaseMode) {
            debugPrint('Failed to upload the completed session: $error');
          }
        }),
      );
    } on Object catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to upload the completed session: $error');
      }
    }
  }

  /// Whether a user is currently signed in.
  ///
  /// Best-effort: a scoring-only screen may mount without the auth providers
  /// wired (they are overridden at the app root, not in `SeriesScreen`'s nested
  /// scope), in which case reading the status throws — treat that as signed out
  /// so completion is never blocked.
  bool _isSignedIn() {
    try {
      return ref.read(authStateChangesProvider).value is SignedIn;
    } on Object {
      return false;
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
    // Sealing the last series completes the session: upload it to the
    // shooter's account when signed in (spec 0024). Fire-and-forget and
    // best-effort, so it never blocks reaching the scorecard.
    if (state.isComplete) _uploadIfSignedIn();
  }
}

/// The current session recording.
final sessionProvider = NotifierProvider<SessionNotifier, SessionRecording>(
  SessionNotifier.new,
);
