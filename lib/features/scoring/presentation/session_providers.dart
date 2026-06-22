// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/data/location_service.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/series.dart';
import 'package:treffpunkt/features/scoring/domain/session.dart';
import 'package:treffpunkt/features/scoring/domain/session_metadata.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';

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
  /// Creates a recording.
  const SessionRecording({
    required this.session,
    this.current,
    this.draggingIndex,
  });

  /// The session so far (sealed series, grouped by stage).
  final Session session;

  /// The series currently being shot, or `null` when the session is complete.
  final Series? current;

  /// The index of the shot being dragged in [current], or `null`.
  final int? draggingIndex;

  /// Whether the whole session is complete (no current series).
  bool get isComplete => session.isComplete;

  /// Whether a placed shot is currently picked up.
  bool get isDragging => draggingIndex != null;
}

/// Records a guided session: placing shots in the current series, then sealing
/// it to advance to the next series or stage.
class SessionNotifier extends Notifier<SessionRecording> {
  @override
  SessionRecording build() {
    final program = ref.watch(currentProgramDefinitionProvider);
    final metadata = ref.watch(currentSessionMetadataProvider);
    final weapon = ref.watch(currentWeaponProvider);
    final session = Session.start(
      program,
      metadata: metadata,
      weapon: weapon,
    );
    return SessionRecording(session: session, current: session.newSeries());
  }

  /// Places the next shot in the current series, unless it is full.
  void placeShot(Shot shot) {
    final current = state.current;
    if (current == null || current.isComplete) return;
    state = SessionRecording(
      session: state.session,
      current: current.placeShot(shot),
      draggingIndex: state.draggingIndex,
    );
  }

  /// Picks up the placed shot at [index] in the current series.
  void pickUp(int index) {
    if (state.current == null) return;
    state = SessionRecording(
      session: state.session,
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
      current: current.moveShot(index, shot),
      draggingIndex: index,
    );
  }

  /// Drops the picked-up shot, ending the drag.
  void drop() => state = SessionRecording(
    session: state.session,
    current: state.current,
  );

  /// Seals the current (full) series and advances to the next series or stage,
  /// completing the session after the last series.
  void advance() {
    final current = state.current;
    if (current == null || !current.isComplete) return;
    final next = state.session.sealSeries(current);
    state = SessionRecording(session: next, current: next.newSeries());
  }
}

/// The current session recording.
final sessionProvider = NotifierProvider<SessionNotifier, SessionRecording>(
  SessionNotifier.new,
);
