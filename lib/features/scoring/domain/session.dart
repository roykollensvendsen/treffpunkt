// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/series.dart';

/// A recording of one shooting session: the chosen [program] and the sealed
/// series so far, grouped by stage.
///
/// Pure value type — sealing a series returns a new session that has advanced
/// to the next series (a fresh face) or the next stage (a different face).
class Session {
  const Session._({required this.program, required this.sealedSeriesByStage});

  /// Starts an empty session for [program].
  factory Session.start(ProgramDefinition program) {
    return Session._(
      program: program,
      sealedSeriesByStage: List<List<Series>>.unmodifiable(
        List<List<Series>>.filled(program.stages.length, const <Series>[]),
      ),
    );
  }

  /// The program being shot.
  final ProgramDefinition program;

  /// Sealed series grouped by stage index (outer length is
  /// `program.stages.length`); both levels are unmodifiable.
  final List<List<Series>> sealedSeriesByStage;

  /// Index of the stage currently being shot, or `program.stages.length` once
  /// the whole session is complete.
  int get currentStageIndex {
    for (var i = 0; i < program.stages.length; i++) {
      if (sealedSeriesByStage[i].length < program.stages[i].seriesCount) {
        return i;
      }
    }
    return program.stages.length;
  }

  /// Whether every series of every stage has been sealed.
  bool get isComplete => currentStageIndex >= program.stages.length;

  /// The stage currently being shot, or `null` when [isComplete].
  StageDefinition? get currentStage =>
      isComplete ? null : program.stages[currentStageIndex];

  /// 1-based number of the series being shot in the current stage, or 0 when
  /// [isComplete].
  int get currentSeriesNumber =>
      isComplete ? 0 : sealedSeriesByStage[currentStageIndex].length + 1;

  /// A fresh empty series for the current stage's face, or `null` if complete.
  Series? newSeries() {
    final stage = currentStage;
    return stage == null
        ? null
        : Series(geometry: stage.geometry, capacity: stage.shotsPerSeries);
  }

  /// Records [series] as a sealed series in the current stage and advances.
  ///
  /// Throws a [StateError] if the session is already complete.
  Session sealSeries(Series series) {
    if (isComplete) {
      throw StateError('session is already complete');
    }
    final index = currentStageIndex;
    final next = <List<Series>>[
      for (var i = 0; i < sealedSeriesByStage.length; i++)
        if (i == index)
          List<Series>.unmodifiable(<Series>[
            ...sealedSeriesByStage[i],
            series,
          ])
        else
          sealedSeriesByStage[i],
    ];
    return Session._(
      program: program,
      sealedSeriesByStage: List<List<Series>>.unmodifiable(next),
    );
  }
}
