// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

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
    for (var ring = geometry.highestRing; ring >= 1; ring--) {
      if (d <= geometry.scoringRadiusMm(ring)) {
        return ring;
      }
    }
    return 0;
  }

  /// Decimal score (e.g. 10.4) for [shot], capped at 10.9, or 0.0 for a miss.
  ///
  /// Assumes evenly spaced rings, which holds for 10 m air rifle (spec 0001).
  double decimalScore(TargetGeometry geometry, Shot shot) {
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
}
