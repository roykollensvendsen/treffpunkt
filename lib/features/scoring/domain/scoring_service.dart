// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/scoring/domain/series.dart';
import 'package:treffpunkt/features/scoring/domain/series_score.dart';
import 'package:treffpunkt/features/scoring/domain/session.dart';
import 'package:treffpunkt/features/scoring/domain/session_score.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

/// Turns a shot position into a score for a given target.
///
/// Both methods are pure functions of the shot and the target geometry; see
/// docs/specs/0001-10m-air-rifle-target-and-scoring.md for the rules and the
/// verification vectors.
class ScoringService {
  /// Creates a scoring service.
  const ScoringService();

  /// Whole-ring score (1..[TargetGeometry.highestRing]) for [shot], or 0 for a
  /// miss. Applies the gauge "next ring outward" rule.
  int integerScore(TargetGeometry geometry, Shot shot) {
    final d = shot.distanceMm;
    final lowest = geometry.lowestRingValue;
    for (var ring = geometry.highestRing; ring >= lowest; ring--) {
      if (d <= geometry.scoringRadiusMm(ring)) {
        return ring;
      }
    }
    return 0;
  }

  /// Decimal score (e.g. 10.4) for [shot], capped at 10.9, or 0.0 for a miss.
  ///
  /// Assumes evenly spaced rings, which holds for 10 m air rifle (spec 0001);
  /// the assert guards against misuse on a non-uniform target (e.g. pistol).
  double decimalScore(TargetGeometry geometry, Shot shot) {
    assert(
      geometry.hasUniformRings && geometry.lowestRingValue == 1,
      'decimalScore assumes a full, evenly spaced 1..N ring face (spec 0001)',
    );
    final d = shot.distanceMm;
    if (d > geometry.maxScoringRadiusMm) {
      return 0;
    }
    final highest = geometry.highestRing;
    // Width of one ring in centre-distance terms (e.g. 2.5 mm for air rifle).
    final ringWidthMm =
        geometry.scoringRadiusMm(1) - geometry.scoringRadiusMm(2);
    final stepMm = ringWidthMm / 10;
    final step = (d / stepMm).ceil();
    final referenceTenths = (highest + 1) * 10; // 110 -> 11.0 for air rifle
    final maxTenths = highest * 10 + 9; // 109 -> 10.9 for air rifle
    final tenths = (referenceTenths - step).clamp(0, maxTenths);
    return tenths / 10;
  }

  /// Whether [shot] counts as an inner ten ("X") on [geometry].
  ///
  /// Always false when the geometry records no inner ten
  /// ([TargetGeometry.hasInnerTen] is false).
  bool isInnerTen(TargetGeometry geometry, Shot shot) {
    final radius = geometry.innerTenScoringRadiusMm;
    return radius != null && shot.distanceMm <= radius;
  }

  /// Scores every placed shot in [series], plus the running total and maximum.
  SeriesScore scoreSeries(Series series) {
    final geometry = series.geometry;
    final shotScores = <ShotScore>[
      for (final shot in series.shots)
        ShotScore(
          ring: integerScore(geometry, shot),
          isInnerTen: isInnerTen(geometry, shot),
        ),
    ];
    var total = 0;
    var innerTens = 0;
    for (final shotScore in shotScores) {
      total += shotScore.ring;
      if (shotScore.isInnerTen) innerTens++;
    }
    return SeriesScore(
      shots: List<ShotScore>.unmodifiable(shotScores),
      total: total,
      innerTens: innerTens,
      maxTotal: series.capacity * geometry.highestRing,
    );
  }

  /// Rolls up [session] into a per-stage and grand total score.
  SessionScore scoreSession(Session session) {
    final stageScores = <StageScore>[];
    var grandTotal = 0;
    var grandInnerTens = 0;
    var grandMaxTotal = 0;
    for (var i = 0; i < session.program.stages.length; i++) {
      final stage = session.program.stages[i];
      var total = 0;
      var innerTens = 0;
      for (final series in session.sealedSeriesByStage[i]) {
        final score = scoreSeries(series);
        total += score.total;
        innerTens += score.innerTens;
      }
      final maxTotal = stage.totalShots * stage.geometry.highestRing;
      stageScores.add(
        StageScore(total: total, innerTens: innerTens, maxTotal: maxTotal),
      );
      grandTotal += total;
      grandInnerTens += innerTens;
      grandMaxTotal += maxTotal;
    }
    return SessionScore(
      stages: List<StageScore>.unmodifiable(stageScores),
      total: grandTotal,
      innerTens: grandInnerTens,
      maxTotal: grandMaxTotal,
    );
  }
}
