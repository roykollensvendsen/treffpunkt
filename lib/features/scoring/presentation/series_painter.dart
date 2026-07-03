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

    // The printed ring values (spec 0113, gtr-2026): each numbered ring's
    // digit centred in its band — along both axes, or vertically only on
    // the duel face — white on the black like the real sheets. Skipped
    // when the sheet-true size would be unreadably small (mini targets).
    final labelMax = geometry.ringLabelMaxValue;
    if (labelMax != null) {
      final fontSize = geometry.ringLabelHeightMm * scale;
      if (fontSize >= 4) {
        for (var ring = geometry.lowestRingValue; ring <= labelMax; ring++) {
          final outerRadiusMm = geometry.outerDiameterMm(ring) / 2;
          final innerRadiusMm = ring == geometry.highestRing
              ? 0.0
              : geometry.outerDiameterMm(ring + 1) / 2;
          final bandMidMm = (outerRadiusMm + innerRadiusMm) / 2;
          final onBlack = bandMidMm * 2 <= geometry.blackBullDiameterMm;
          final label = TextPainter(
            text: TextSpan(
              text: '$ring',
              style: TextStyle(
                color: onBlack ? Colors.white70 : Colors.black54,
                fontSize: fontSize,
                height: 1,
                // The app's default face, pinned so the digits render the
                // same in golden/screenshot harnesses that load it.
                fontFamily: 'Roboto',
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final radius = bandMidMm * scale;
          final positions = <Offset>[
            Offset(centre.dx, centre.dy - radius),
            Offset(centre.dx, centre.dy + radius),
            if (geometry.ringLabelsBothAxes) ...[
              Offset(centre.dx - radius, centre.dy),
              Offset(centre.dx + radius, centre.dy),
            ],
          ];
          for (final position in positions) {
            label.paint(
              canvas,
              position - Offset(label.width / 2, label.height / 2),
            );
          }
          label.dispose();
        }
      }
    }

    // The duel faces' white sighting lines (specs 0113/0121): bars running
    // inward from the outermost ring's edge, replacing the side values and
    // notching the black where they reach it (the § 5.1.18.1.2 figure). On
    // the all-black 25 m face the black IS the outermost ring, so this is
    // the same anchor as ever.
    final sightingLengthMm = geometry.sightingLineLengthMm;
    if (sightingLengthMm != null) {
      final outerRadius = geometry.ringOuterDiametersMm.first / 2 * scale;
      final halfWidth = geometry.sightingLineWidthMm / 2 * scale;
      final length = sightingLengthMm * scale;
      final white = Paint()..color = Colors.white;
      canvas
        ..drawRect(
          Rect.fromLTRB(
            centre.dx - outerRadius,
            centre.dy - halfWidth,
            centre.dx - outerRadius + length,
            centre.dy + halfWidth,
          ),
          white,
        )
        ..drawRect(
          Rect.fromLTRB(
            centre.dx + outerRadius - length,
            centre.dy - halfWidth,
            centre.dx + outerRadius,
            centre.dy + halfWidth,
          ),
          white,
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
