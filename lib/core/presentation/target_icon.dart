// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

/// The app's "shoot" glyph (spec 0100): a target of concentric rings with a
/// filled bull — used for every start-shooting affordance, so the map icons
/// (`my_location`, `gps_fixed`) can mean location and nothing else.
///
/// Drawn, not a font glyph, so it renders identically on every platform and
/// takes the ambient [IconTheme] colour and size like a real [Icon].
class TargetIcon extends StatelessWidget {
  /// Creates the icon; [size] and [color] fall back to the [IconTheme].
  const TargetIcon({
    this.size,
    this.color,
    this.bullColor,
    this.bullFraction = 0.24,
    super.key,
  });

  /// Diameter, defaulting to the ambient icon size (24).
  final double? size;

  /// Colour, defaulting to the ambient icon colour.
  final Color? color;

  /// The bull's colour, defaulting to [color] — set it to the signal red for
  /// the logo mark (spec 0101).
  final Color? bullColor;

  /// The bull's radius as a fraction of the icon radius. The default reads
  /// as a fine-ringed precision target; a heavier bull (≈0.45) reads as the
  /// large black of a 25 m target (spec 0101).
  final double bullFraction;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final side = size ?? iconTheme.size ?? 24;
    final paintColor = color ?? iconTheme.color ?? Colors.black;
    return SizedBox(
      width: side,
      height: side,
      child: CustomPaint(
        painter: _TargetPainter(
          paintColor,
          bullColor ?? paintColor,
          bullFraction,
        ),
      ),
    );
  }
}

class _TargetPainter extends CustomPainter {
  const _TargetPainter(this.color, this.bullColor, this.bullFraction);

  final Color color;
  final Color bullColor;
  final double bullFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide / 12
      ..color = color;
    canvas
      ..drawCircle(centre, r * 0.92, stroke)
      ..drawCircle(centre, r * 0.58, stroke)
      ..drawCircle(centre, r * bullFraction, Paint()..color = bullColor);
  }

  @override
  bool shouldRepaint(_TargetPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.bullColor != bullColor ||
      oldDelegate.bullFraction != bullFraction;
}
