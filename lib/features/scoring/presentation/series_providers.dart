// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/domain/program.dart';
import 'package:treffpunkt/features/scoring/domain/series.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';

/// The program (discipline) being recorded on the current screen.
///
/// Overridden where a series screen is mounted; the default throws so a missing
/// override fails loudly instead of guessing a discipline.
final currentProgramProvider = Provider<Program>(
  (ref) => throw UnimplementedError('override currentProgramProvider'),
);

/// The in-progress series together with its drag and sealed state.
class SeriesRecording {
  /// Creates a recording of [series].
  const SeriesRecording({
    required this.series,
    this.draggingIndex,
    this.sealed = false,
  });

  /// The series recorded so far.
  final Series series;

  /// The index of the shot currently picked up for dragging, or `null`.
  final int? draggingIndex;

  /// Whether the series has been sealed (completed); no more edits are made.
  final bool sealed;

  /// Whether a placed shot is currently picked up.
  bool get isDragging => draggingIndex != null;

  /// Copies the recording, changing the given fields.
  ///
  /// Pass [clearDragging] to drop the picked-up shot (set [draggingIndex] back
  /// to `null`).
  SeriesRecording copyWith({
    Series? series,
    int? draggingIndex,
    bool clearDragging = false,
    bool? sealed,
  }) {
    return SeriesRecording(
      series: series ?? this.series,
      draggingIndex: clearDragging
          ? null
          : (draggingIndex ?? this.draggingIndex),
      sealed: sealed ?? this.sealed,
    );
  }
}

/// Records the current series: placing, moving and sealing shots.
class SeriesNotifier extends Notifier<SeriesRecording> {
  @override
  SeriesRecording build() {
    final program = ref.watch(currentProgramProvider);
    return SeriesRecording(series: program.newSeries());
  }

  /// Places the next shot at [shot], unless the series is sealed or full.
  void placeShot(Shot shot) {
    if (state.sealed || state.series.isComplete) return;
    state = state.copyWith(series: state.series.placeShot(shot));
  }

  /// Picks up the placed shot at [index] for dragging.
  void pickUp(int index) {
    if (state.sealed) return;
    state = state.copyWith(draggingIndex: index);
  }

  /// Moves the picked-up shot to [shot].
  void dragTo(Shot shot) {
    final index = state.draggingIndex;
    if (index == null) return;
    state = state.copyWith(series: state.series.moveShot(index, shot));
  }

  /// Drops the picked-up shot, ending the drag.
  void drop() => state = state.copyWith(clearDragging: true);

  /// Seals the series once it is complete; no further edits are accepted.
  void seal() {
    if (state.series.isComplete) state = state.copyWith(sealed: true);
  }
}

/// The current series recording.
final seriesProvider = NotifierProvider<SeriesNotifier, SeriesRecording>(
  SeriesNotifier.new,
);
