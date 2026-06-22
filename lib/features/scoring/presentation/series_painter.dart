// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  });

  /// The target whose rings are drawn.
  final TargetGeometry geometry;

  /// The placed shots, in firing order.
  final List<Shot> shots;

  /// The index of the shot currently picked up, or `null`.
  final int? draggingIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final centre = Offset(size.width / 2, size.height / 2);
    final scale = (side / 2) / geometry.maxScoringRadiusMm;

    canvas
      ..drawRect(Offset.zero & size, Paint()..color = Colors.white)
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

    final radius = geometry.pelletRadiusMm * scale;
    for (var i = 0; i < shots.length; i++) {
      final shot = shots[i];
      final markerCentre =
          centre + Offset(shot.dxMm * scale, shot.dyMm * scale);
      final fill = i == draggingIndex ? Colors.lightBlueAccent : Colors.amber;
      canvas
        ..drawCircle(markerCentre, radius, Paint()..color = fill)
        ..drawCircle(
          markerCentre,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.black,
        );
    }
  }

  @override
  bool shouldRepaint(SeriesPainter oldDelegate) =>
      oldDelegate.draggingIndex != draggingIndex ||
      oldDelegate.geometry != geometry ||
      !listEquals(oldDelegate.shots, shots);
}
