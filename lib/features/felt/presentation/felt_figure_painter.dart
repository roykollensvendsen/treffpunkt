// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:treffpunkt/features/felt/domain/felt_figure.dart';
import 'package:treffpunkt/features/felt/presentation/felt_animal_paths.dart';

/// Renders a single field figure at a real scale (spec 0068): the silhouette
/// plus its inner zone, sized [pxPerCm] pixels per centimetre so a hold's
/// figures keep their true relative sizes.
class FeltFigureView extends StatelessWidget {
  /// Creates a figure view.
  const FeltFigureView({
    required this.figure,
    required this.pxPerCm,
    super.key,
  });

  /// The figure to draw.
  final FeltFigure figure;

  /// Pixels per centimetre.
  final double pxPerCm;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(figure.widthCm * pxPerCm, figure.heightCm * pxPerCm),
    painter: FeltFigurePainter(
      figure: figure,
      colour: Theme.of(context).colorScheme.onSurface,
      innerColour: Theme.of(context).colorScheme.surface,
    ),
  );
}

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

    // The inner zone (innertreff): a centred circle scaled like the figure.
    final pxPerCm = size.width / figure.widthCm;
    final innerR = figure.effectiveInnerCm * pxPerCm / 2;
    canvas.drawCircle(
      size.center(Offset.zero),
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

/// Builds the silhouette [Path] for [type], filling [size]. Geometric shapes
/// are parametric; the animals are traced polygons (spec 0068).
Path figurePath(FeltFigureType type, Size size) {
  final w = size.width;
  final h = size.height;
  switch (type) {
    case FeltFigureType.circle:
    case FeltFigureType.oval:
    case FeltFigureType.egg:
      // Circle/oval exactly; egg is approximated by its ellipse for now.
      return Path()..addOval(Offset.zero & size);
    case FeltFigureType.triangle:
      return Path()
        ..moveTo(w / 2, 0)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
    case FeltFigureType.hexagon:
      return Path()
        ..moveTo(0.25 * w, 0)
        ..lineTo(0.75 * w, 0)
        ..lineTo(w, 0.5 * h)
        ..lineTo(0.75 * w, h)
        ..lineTo(0.25 * w, h)
        ..lineTo(0, 0.5 * h)
        ..close();
    case FeltFigureType.stripe:
      // A rounded vertical bar.
      return Path()..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(w / 2),
        ),
      );
    case FeltFigureType.bowlingPin:
    case FeltFigureType.reducedFigure:
      // Approximated by a rounded rectangle until traced (spec 0068).
      return Path()..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(0.3 * (w < h ? w : h)),
        ),
      );
    case FeltFigureType.hare:
      return _polygon(feltHareOutline, size);
    case FeltFigureType.wolfHead:
      return _polygon(feltWolfHeadOutline, size);
    case FeltFigureType.ptarmigan:
      return _polygon(feltPtarmiganOutline, size);
  }
}

Path _polygon(List<Offset> points, Size size) {
  final path = Path()
    ..moveTo(points.first.dx * size.width, points.first.dy * size.height);
  for (final p in points.skip(1)) {
    path.lineTo(p.dx * size.width, p.dy * size.height);
  }
  return path..close();
}
