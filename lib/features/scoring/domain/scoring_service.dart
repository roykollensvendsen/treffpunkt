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
  /// The tenth subdivides the shot's own scoring band into ten equal parts
  /// (spec 0114), so `floor(decimal) == integerScore` holds on **every**
  /// face by construction — the gauge rule can make the innermost band a
  /// different width from the rest (25 m faces), which the spec-0001
  /// fixed-step model did not account for. On the 10 m air faces, where
  /// the bands are all one step wide, this is exactly the spec-0001 model.
  double decimalScore(TargetGeometry geometry, Shot shot) {
    final ring = integerScore(geometry, shot);
    if (ring == 0) return 0;
    final bandOuterMm = geometry.scoringRadiusMm(ring);
    final bandInnerMm = ring == geometry.highestRing
        ? 0.0
        : geometry.scoringRadiusMm(ring + 1);
    final fraction =
        (bandOuterMm - shot.distanceMm) / (bandOuterMm - bandInnerMm);
    final tenth = (fraction * 10).floor().clamp(0, 9);
    return (ring * 10 + tenth) / 10;
  }

  /// The shot's decimal value in tenths (e.g. 94 for 9,4) on a face that
  /// supports decimals (spec 0107): the plotted ring plus the manually
  /// picked tenth when one is set, otherwise the position-derived decimal
  /// (spec 0001). A miss is 0 — a picked tenth cannot resurrect it.
  int decimalTenths(TargetGeometry geometry, Shot shot) {
    final ring = integerScore(geometry, shot);
    final tenth = shot.tenth;
    if (ring == 0) return 0;
    if (tenth != null) return ring * 10 + tenth;
    return (decimalScore(geometry, shot) * 10).round();
  }

  /// Returns [shot] moved radially so its position *is* the picked decimal
  /// (spec 0110): the centre distance of the [tenth]'s band within the
  /// shot's plotted ring (its midpoint, so the derived decimal reads back
  /// exactly), along the shot's own direction from the centre. A dead-centre
  /// shot is given a direction (straight up); a miss is returned untouched —
  /// there is nothing to position. The moved shot carries [tenth].
  Shot shotAtDecimalTenth(TargetGeometry geometry, Shot shot, int tenth) {
    final ring = integerScore(geometry, shot);
    if (ring == 0) return shot;
    final bandOuterMm = geometry.scoringRadiusMm(ring);
    final bandInnerMm = ring == geometry.highestRing
        ? 0.0
        : geometry.scoringRadiusMm(ring + 1);
    // The midpoint of the tenth's sub-band: reads back as exactly [tenth].
    final distanceMm =
        bandOuterMm - (tenth + 0.5) / 10 * (bandOuterMm - bandInnerMm);
    final currentDistance = shot.distanceMm;
    final dirX = currentDistance > 0 ? shot.dxMm / currentDistance : 0.0;
    final dirY = currentDistance > 0 ? shot.dyMm / currentDistance : -1.0;
    return Shot(
      dxMm: dirX * distanceMm,
      dyMm: dirY * distanceMm,
      tenth: tenth,
    );
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
    final decimal = geometry.supportsDecimalScore;
    final shotScores = <ShotScore>[
      for (final shot in series.shots)
        ShotScore(
          ring: integerScore(geometry, shot),
          isInnerTen: isInnerTen(geometry, shot),
          decimal: decimal ? decimalTenths(geometry, shot) / 10 : null,
        ),
    ];
    var total = 0;
    var innerTens = 0;
    // Summed as integer tenths so 60 shots never accumulate float drift.
    var decimalTenthsTotal = 0;
    for (final shot in series.shots) {
      if (decimal) decimalTenthsTotal += decimalTenths(geometry, shot);
    }
    for (final shotScore in shotScores) {
      total += shotScore.ring;
      if (shotScore.isInnerTen) innerTens++;
    }
    return SeriesScore(
      shots: List<ShotScore>.unmodifiable(shotScores),
      total: total,
      innerTens: innerTens,
      maxTotal: series.capacity * geometry.highestRing,
      decimalTotal: decimal ? decimalTenthsTotal / 10 : null,
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
      final seriesScores = <SeriesScore>[];
      var total = 0;
      var innerTens = 0;
      for (final series in session.sealedSeriesByStage[i]) {
        final score = scoreSeries(series);
        seriesScores.add(score);
        total += score.total;
        innerTens += score.innerTens;
      }
      final maxTotal = stage.totalShots * stage.geometry.highestRing;
      stageScores.add(
        StageScore(
          series: List<SeriesScore>.unmodifiable(seriesScores),
          total: total,
          innerTens: innerTens,
          maxTotal: maxTotal,
          decimalTotal: _decimalSum(
            seriesScores.map((score) => score.decimalTotal),
          ),
        ),
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
      decimalTotal: _decimalSum(
        stageScores.map((score) => score.decimalTotal),
      ),
    );
  }

  /// The running decimal total of a session in progress (spec 0111): the
  /// sealed series plus the [current] one, in exact tenths — or null the
  /// moment any involved series is on a face without decimals (a mixed
  /// program's duel stage), where a partial "running decimal" would lie.
  double? runningDecimalTotal(Session session, Series? current) {
    var tenths = 0;
    for (final stage in session.sealedSeriesByStage) {
      for (final series in stage) {
        final part = scoreSeries(series).decimalTotal;
        if (part == null) return null;
        tenths += (part * 10).round();
      }
    }
    final currentPart = current == null
        ? 0.0
        : scoreSeries(current).decimalTotal;
    if (currentPart == null) return null;
    return (tenths + (currentPart * 10).round()) / 10;
  }

  /// The sum of [parts] in exact tenths, or null when any part has no
  /// decimal (a stage on a 5–10 face) — a partial decimal sum would lie.
  static double? _decimalSum(Iterable<double?> parts) {
    var tenths = 0;
    var any = false;
    for (final part in parts) {
      if (part == null) return null;
      any = true;
      tenths += (part * 10).round();
    }
    return any ? tenths / 10 : null;
  }
}
