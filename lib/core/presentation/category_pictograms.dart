// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

/// The MIL category's pictogram (spec 0101): the head-and-shoulders
/// silhouette the military programs are shot on. Drawn like [Icon] — it
/// takes the ambient [IconTheme] colour and size.
class SilhouettePictogram extends StatelessWidget {
  /// Creates the pictogram; [size] and [color] fall back to the [IconTheme].
  const SilhouettePictogram({this.size, this.color, super.key});

  /// Height/width, defaulting to the ambient icon size (24).
  final double? size;

  /// Colour, defaulting to the ambient icon colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final side = size ?? iconTheme.size ?? 24;
    final paintColor = color ?? iconTheme.color ?? Colors.black;
    return SizedBox(
      width: side,
      height: side,
      child: CustomPaint(painter: _SilhouettePainter(paintColor)),
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  const _SilhouettePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..color = color;
    canvas
      // The head: a circle in the upper half…
      ..drawCircle(Offset(w / 2, h * 0.28), w * 0.18, fill)
      // …on rounded shoulders filling the lower half.
      ..drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(w * 0.13, h * 0.52, w * 0.87, h),
          topLeft: Radius.circular(w * 0.22),
          topRight: Radius.circular(w * 0.22),
        ),
        fill,
      );
  }

  @override
  bool shouldRepaint(_SilhouettePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// The Felt category's pictogram (spec 0101): the square-and-circle figure
/// pair of the NorgesFelt holds. Drawn like [Icon] — it takes the ambient
/// [IconTheme] colour and size.
class FeltFiguresPictogram extends StatelessWidget {
  /// Creates the pictogram; [size] and [color] fall back to the [IconTheme].
  const FeltFiguresPictogram({this.size, this.color, super.key});

  /// Height/width, defaulting to the ambient icon size (24).
  final double? size;

  /// Colour, defaulting to the ambient icon colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final side = size ?? iconTheme.size ?? 24;
    final paintColor = color ?? iconTheme.color ?? Colors.black;
    return SizedBox(
      width: side,
      height: side,
      child: CustomPaint(painter: _FeltFiguresPainter(paintColor)),
    );
  }
}

class _FeltFiguresPainter extends CustomPainter {
  const _FeltFiguresPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide / 10
      ..color = color;
    // A square and a circle figure side by side, the way the figures stand
    // in a row on a hold — clearly two separate målfigurer, not an
    // overlapping "copy" glyph.
    canvas
      ..drawRect(
        Rect.fromLTRB(w * 0.06, h * 0.29, w * 0.48, h * 0.71),
        stroke,
      )
      ..drawCircle(Offset(w * 0.73, h * 0.5), w * 0.21, stroke);
  }

  @override
  bool shouldRepaint(_FeltFiguresPainter oldDelegate) =>
      oldDelegate.color != color;
}
