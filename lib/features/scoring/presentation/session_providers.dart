// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/series.dart';
import 'package:treffpunkt/features/scoring/domain/session.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';

/// The program being recorded on the current screen.
///
/// Overridden where a session screen is mounted; the default throws so a
/// forgotten override fails loudly instead of guessing a discipline.
final currentProgramDefinitionProvider = Provider<ProgramDefinition>(
  (ref) =>
      throw UnimplementedError('override currentProgramDefinitionProvider'),
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
    final session = Session.start(program);
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
