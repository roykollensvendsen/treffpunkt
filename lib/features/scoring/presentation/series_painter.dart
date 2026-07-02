// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:treffpunkt/core/presentation/app_theme.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

/// Paints a shooting target and the shots of a series.
///
/// Target millimetres are mapped to pixels so the full scoring area fits the
/// shortest side of the paint area, centred.
class SeriesPainter extends CustomPainter {
  /// Creates a painter for [geometry] marking every shot in [shots]. The shot
  /// at [draggingIndex] (if any) is drawn as picked-up.
  const SeriesPainter({
    required this.geometry,
    required this.shots,
    required this.draggingIndex,
    this.highlightLast = true,
    this.colors = TreffColors.light,
  });

  /// The target whose rings are drawn.
  final TargetGeometry geometry;

  /// The placed shots, in firing order.
  final List<Shot> shots;

  /// The index of the shot currently picked up, or `null`.
  final int? draggingIndex;

  /// Whether to halo the most recently placed shot. `false` for a silhouette
  /// mini-target, whose single shot should not be emphasised (spec 0067).
  final bool highlightLast;

  /// The theme's sport colours (spec 0100): the latest shot in signal red,
  /// older shots neutral — the convention of the range monitors shooters
  /// already know. Callers pass `TreffColors.of(context)`.
  final TreffColors colors;

  /// The index of the shot to emphasise — the most recently placed (highest
  /// index) — or `null` when the series has no shots.
  ///
  /// Exposed so the highlight rule is unit-testable without rendering.
  int? get highlightedIndex =>
      (shots.isEmpty || !highlightLast) ? null : shots.length - 1;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final centre = Offset(size.width / 2, size.height / 2);
    final scale = (side / 2) / geometry.maxScoringRadiusMm;

    canvas
      ..drawRect(Offset.zero & size, Paint()..color = colors.paper)
      ..drawCircle(
        centre,
        geometry.blackBullDiameterMm / 2 * scale,
        Paint()..color = Colors.black,
      );

    for (
      var ring = geometry.lowestRingValue;
      ring <= geometry.highestRing;
      ring++
    ) {
      final radiusMm = geometry.outerDiameterMm(ring) / 2;
      final onBlack = radiusMm * 2 <= geometry.blackBullDiameterMm;
      canvas.drawCircle(
        centre,
        radiusMm * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = onBlack ? Colors.white70 : Colors.black54,
      );
    }

    // The inner-ten ring (spec 0103), on the faces that have one — drawn
    // like the scoring rings, white on the black bull.
    final innerTenMm = geometry.innerTenDiameterMm;
    if (innerTenMm != null) {
      final onBlack = innerTenMm <= geometry.blackBullDiameterMm;
      canvas.drawCircle(
        centre,
        innerTenMm / 2 * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = onBlack ? Colors.white70 : Colors.black54,
      );
    }

    final radius = geometry.pelletRadiusMm * scale;
    for (var i = 0; i < shots.length; i++) {
      final shot = shots[i];
      final markerCentre =
          centre + Offset(shot.dxMm * scale, shot.dyMm * scale);
      final dragging = i == draggingIndex;
      // Precedence: drag styling wins over the last-shot highlight, which wins
      // over an ordinary marker. A dragged shot is never given the halo.
      final highlighted = !dragging && i == highlightedIndex;
      final fill = dragging
          ? colors.draggedShot
          : highlighted
          ? colors.lastShot
          : colors.olderShot;
      canvas
        ..drawCircle(markerCentre, radius, Paint()..color = fill)
        ..drawCircle(
          markerCentre,
          radius,
          // The marker edge matches the marker fill, so there is no contrasting
          // black ring around each shot.
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = fill,
        );
      if (highlighted) {
        // The latest shot is emphasised by a halo ring, at the same marker
        // size as the others (not enlarged).
        canvas.drawCircle(
          markerCentre,
          radius + 2.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = colors.lastShot,
        );
      }
    }
  }

  @override
  bool shouldRepaint(SeriesPainter oldDelegate) =>
      oldDelegate.draggingIndex != draggingIndex ||
      oldDelegate.geometry != geometry ||
      oldDelegate.highlightLast != highlightLast ||
      oldDelegate.colors != colors ||
      !listEquals(oldDelegate.shots, shots);
}
