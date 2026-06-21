// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

/// Paints a shooting target and an optional placed shot.
///
/// Target millimetres are mapped to pixels so the full scoring area fits the
/// shortest side of the paint area, centred.
class TargetPainter extends CustomPainter {
  /// Creates a painter for [geometry], marking [shot] if non-null.
  const TargetPainter({required this.geometry, required this.shot});

  /// The target whose rings are drawn.
  final TargetGeometry geometry;

  /// The placed shot to mark, or `null`.
  final Shot? shot;

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

    for (var ring = 1; ring <= geometry.highestRing; ring++) {
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

    final placedShot = shot;
    if (placedShot != null) {
      final markerCentre =
          centre + Offset(placedShot.dxMm * scale, placedShot.dyMm * scale);
      final radius = geometry.pelletRadiusMm * scale;
      canvas
        ..drawCircle(markerCentre, radius, Paint()..color = Colors.amber)
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
  bool shouldRepaint(TargetPainter oldDelegate) =>
      oldDelegate.shot != shot || oldDelegate.geometry != geometry;
}
