// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:treffpunkt/features/felt/domain/felt_figure.dart';
import 'package:treffpunkt/features/felt/presentation/felt_figure_paths.dart';

/// Renders a single field figure at a real scale (spec 0068): the silhouette
/// plus its inner zone, sized [pxPerCm] pixels per centimetre so a hold's
/// figures keep their true relative sizes.
///
/// The NorgesFelt figures are printed in the hold's [colour] on a white plate,
/// so we draw them that way (independent of the app theme) and ring the inner
/// zone in white — the real targets' look — so the preview reads in any theme.
class FeltFigureView extends StatelessWidget {
  /// Creates a figure view drawn in [colour] (defaults to black).
  const FeltFigureView({
    required this.figure,
    required this.pxPerCm,
    this.colour = feltFigureBlack,
    super.key,
  });

  /// The black of a black-hold figure (spec 0078).
  static const Color feltFigureBlack = Color(0xFF101010);

  /// The figure to draw.
  final FeltFigure figure;

  /// Pixels per centimetre.
  final double pxPerCm;

  /// The colour to fill the silhouette with (the hold's colour, spec 0078).
  final Color colour;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: Colors.black12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: CustomPaint(
        size: Size(figure.widthCm * pxPerCm, figure.heightCm * pxPerCm),
        painter: FeltFigurePainter(
          figure: figure,
          colour: colour,
          innerColour: Colors.white,
        ),
      ),
    ),
  );
}

/// The real colour for a hold's [colour] enum (spec 0078).
Color feltHoldColour(FeltHoldColour colour) => switch (colour) {
  FeltHoldColour.black => FeltFigureView.feltFigureBlack,
  FeltHoldColour.green => const Color(0xFF00683F),
  FeltHoldColour.red => const Color(0xFFED1C24),
};

/// Paints a field figure: a filled silhouette with the inner-zone circle.
class FeltFigurePainter extends CustomPainter {
  /// Creates the painter.
  const FeltFigurePainter({
    required this.figure,
    required this.colour,
    required this.innerColour,
  });

  /// The figure.
  final FeltFigure figure;

  /// The silhouette fill colour.
  final Color colour;

  /// The inner-zone outline colour (drawn over the silhouette).
  final Color innerColour;

  @override
  void paint(Canvas canvas, Size size) {
    final path = figurePath(figure.type, size);
    canvas.drawPath(path, Paint()..color = colour);

    // The inner zone (innertreff): a circle at the figure's centre of mass,
    // not the bounding-box centre — so it sits over the body of an asymmetric
    // figure (a triangle's lower third, an animal's chest) the way the real
    // targets place it.
    final pxPerCm = size.width / figure.widthCm;
    final innerR = figure.effectiveInnerCm * pxPerCm / 2;
    canvas.drawCircle(
      figureCentroid(figure.type, size),
      innerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = innerColour,
    );
  }

  @override
  bool shouldRepaint(FeltFigurePainter old) =>
      old.figure != figure ||
      old.colour != colour ||
      old.innerColour != innerColour;
}

/// Builds the silhouette [Path] for [type], filling [size]. Circles and ovals
/// are exact ellipses; every other figure is a polygon traced from the official
/// NorgesFelt blink images (spec 0077).
Path figurePath(FeltFigureType type, Size size) {
  switch (type) {
    case FeltFigureType.circle:
      // The C-figures are a circle cut flat across the bottom (spec 0077).
      return _truncatedCircle(size);
    case FeltFigureType.oval:
      return Path()..addOval(Offset.zero & size);
    case FeltFigureType.stripe:
      // A near-rectangular vertical bar (the "størenstripe" plates).
      return Path()..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(3),
        ),
      );
    case FeltFigureType.triangle:
      return _polygon(feltTriangleOutline, size);
    case FeltFigureType.rightTriangle:
      return _polygon(feltRightTriangleOutline, size);
    case FeltFigureType.hexagon:
      return _polygon(feltHexagonOutline, size);
    case FeltFigureType.egg:
      return _polygon(feltEggOutline, size);
    case FeltFigureType.bowlingPin:
      return _polygon(feltBowlingPinOutline, size);
    case FeltFigureType.reducedFigure:
      return _polygon(feltReducedFigureOutline, size);
    case FeltFigureType.hare:
      return _polygon(feltHareOutline, size);
    case FeltFigureType.wolfHead:
      return _polygon(feltWolfHeadOutline, size);
    case FeltFigureType.ptarmigan:
      return _polygon(feltPtarmiganOutline, size);
  }
}

/// A circle as wide as [size] cut flat across the bottom of the box: the arc
/// over the top, closed by the chord at the bottom (spec 0077). A square box
/// (height == width) yields a full circle.
Path _truncatedCircle(Size size) {
  final w = size.width;
  final h = size.height;
  final r = w / 2;
  if (h >= w) return Path()..addOval(Offset.zero & size);
  final cx = w / 2;
  final cy = r;
  // Angle of the right-hand chord end, where the circle meets the flat bottom.
  final chordAngle = math.asin(((h - cy) / r).clamp(-1.0, 1.0));
  final sweep = -(math.pi + 2 * chordAngle); // over the top, right end → left
  const steps = 80;
  final path = Path();
  for (var i = 0; i <= steps; i++) {
    final a = chordAngle + sweep * i / steps;
    final x = cx + r * math.cos(a);
    final y = cy + r * math.sin(a);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  return path..close();
}

Path _polygon(List<Offset> points, Size size) {
  final path = Path()
    ..moveTo(points.first.dx * size.width, points.first.dy * size.height);
  for (final p in points.skip(1)) {
    path.lineTo(p.dx * size.width, p.dy * size.height);
  }
  return path..close();
}

/// The point to centre the inner zone on for [type], filling [size]: the
/// figure's centre of mass (spec 0068). Symmetric shapes use the box centre; a
/// triangle's mass sits at two-thirds down; the animals use their traced
/// polygon's area centroid (which lands on the body/head, matching the photos).
Offset figureCentroid(FeltFigureType type, Size size) {
  switch (type) {
    case FeltFigureType.triangle:
      return _polygonCentroid(feltTriangleOutline, size);
    case FeltFigureType.rightTriangle:
      return _polygonCentroid(feltRightTriangleOutline, size);
    case FeltFigureType.hexagon:
      return _polygonCentroid(feltHexagonOutline, size);
    case FeltFigureType.egg:
      return _polygonCentroid(feltEggOutline, size);
    case FeltFigureType.bowlingPin:
      return _polygonCentroid(feltBowlingPinOutline, size);
    case FeltFigureType.reducedFigure:
      return _polygonCentroid(feltReducedFigureOutline, size);
    case FeltFigureType.hare:
      return _polygonCentroid(feltHareOutline, size);
    case FeltFigureType.wolfHead:
      return _polygonCentroid(feltWolfHeadOutline, size);
    case FeltFigureType.ptarmigan:
      return _polygonCentroid(feltPtarmiganOutline, size);
    case FeltFigureType.circle:
      // Concentric with the circle (its centre is a radius down from the top).
      return Offset(size.width / 2, math.min(size.width / 2, size.height));
    case FeltFigureType.oval:
    case FeltFigureType.stripe:
      return size.center(Offset.zero);
  }
}

/// The area centroid of the closed polygon [points] (normalised 0..1), scaled
/// to [size]. Uses the shoelace formula; degenerate rings fall back to the
/// mean of the vertices.
Offset _polygonCentroid(List<Offset> points, Size size) {
  var area = 0.0;
  var cx = 0.0;
  var cy = 0.0;
  for (var i = 0; i < points.length; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];
    final cross = a.dx * b.dy - b.dx * a.dy;
    area += cross;
    cx += (a.dx + b.dx) * cross;
    cy += (a.dy + b.dy) * cross;
  }
  area *= 0.5;
  if (area.abs() < 1e-9) {
    final mx = points.map((p) => p.dx).reduce((a, b) => a + b) / points.length;
    final my = points.map((p) => p.dy).reduce((a, b) => a + b) / points.length;
    return Offset(mx * size.width, my * size.height);
  }
  return Offset(cx / (6 * area) * size.width, cy / (6 * area) * size.height);
}
