// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art.dart';

/// Renders a composed hold [FeltHoldArt] (spec 0079): the paper, the coloured
/// backing plates, each figure (fill + inner-treff ring) and the black
/// vertical separators, scaled from the hold's pixel space to the paint size.
class FeltHoldArtPainter extends CustomPainter {
  /// Creates a painter for [art].
  const FeltHoldArtPainter(this.art);

  /// The composed hold to draw.
  final FeltHoldArt art;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = art.paper)
      ..save()
      ..scale(size.width / art.size.width, size.height / art.size.height);
    for (final plate in art.plates) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(plate.rect, Radius.circular(plate.radius)),
        Paint()..color = plate.color,
      );
    }
    for (final figure in art.figures) {
      canvas.drawPath(feltArtFigurePath(figure), Paint()..color = figure.fill);
      final ring = figure.ring;
      if (ring != null) {
        canvas.drawCircle(
          Offset(ring.cx, ring.cy),
          ring.r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = ring.strokeWidth
            ..color = ring.color,
        );
      }
    }
    for (final sep in art.separators) {
      canvas.drawRect(sep.rect, Paint()..color = sep.color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(FeltHoldArtPainter old) => old.art != art;
}

/// Builds the outline [Path] for [figure] in the hold's pixel space (0079).
/// Circles and ellipses are exact; the C-figure is a circle cut flat across the
/// bottom; polygons pass through their points.
Path feltArtFigurePath(FeltArtFigure figure) {
  switch (figure.shape) {
    case FeltArtShape.polygon:
      return Path()..addPolygon(figure.points, true);
    case FeltArtShape.circle:
      return Path()..addOval(
        Rect.fromCircle(
          center: Offset(figure.cx, figure.cy),
          radius: figure.r,
        ),
      );
    case FeltArtShape.tcircle:
      return _truncatedCirclePath(figure);
    case FeltArtShape.ellipse:
      return _ellipsePath(figure);
  }
}

/// A circle cut flat across the bottom at [FeltArtFigure.bottomY]: the arc over
/// the top closed by the flat chord (spec 0079).
Path _truncatedCirclePath(FeltArtFigure f) {
  final cx = f.cx;
  final cy = f.cy;
  final r = f.r;
  if (f.bottomY >= cy + r - 0.5) {
    return Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
  }
  final s = ((f.bottomY - cy) / r).clamp(-1.0, 1.0);
  final phi = math.asin(s);
  final end = -(math.pi + phi);
  const steps = 96;
  final path = Path();
  for (var i = 0; i <= steps; i++) {
    final a = phi + (end - phi) * i / steps;
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

/// An ellipse with semi-axes [FeltArtFigure.a]/[FeltArtFigure.b] rotated by
/// [FeltArtFigure.thetaDeg], sampled to a smooth polygon.
Path _ellipsePath(FeltArtFigure f) {
  final th = f.thetaDeg * math.pi / 180;
  final ct = math.cos(th);
  final st = math.sin(th);
  const steps = 72;
  final path = Path();
  for (var i = 0; i <= steps; i++) {
    final t = 2 * math.pi * i / steps;
    final ex = f.a * math.cos(t);
    final ey = f.b * math.sin(t);
    final x = f.cx + ct * ex - st * ey;
    final y = f.cy + st * ex + ct * ey;
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  return path..close();
}

/// A composed hold drawn at its natural aspect ratio (spec 0079), on a white
/// card so it reads the same in any theme — the real targets are on white.
class FeltHoldArtView extends StatelessWidget {
  /// Creates a view of [art].
  const FeltHoldArtView({required this.art, super.key});

  /// The composed hold to draw.
  final FeltHoldArt art;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
      child: AspectRatio(
        aspectRatio: art.size.width / art.size.height,
        child: CustomPaint(painter: FeltHoldArtPainter(art)),
      ),
    ),
  );
}
