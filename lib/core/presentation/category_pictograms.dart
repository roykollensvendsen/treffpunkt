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

// Natural ammunition colours (spec 0154): lead for the pellet, copper and
// brass for the cartridge. Fixed — these pictograms are coloured, not tinted
// by the theme like the monochrome silhouette / felt ones.
const Color _leadLight = Color(0xFFAEB2BB);
const Color _leadDark = Color(0xFF70747D);
const Color _brass = Color(0xFFC4963A);
const Color _copper = Color(0xFFB2603A);

/// The NSF Luft category's pictogram (spec 0154): a 10 m match wadcutter
/// pellet in natural lead, its outline an octagon measured from the official
/// COAL data-sheet pellet. Two-tone — a lighter flat head over a darker
/// hollow skirt.
class PelletPictogram extends StatelessWidget {
  /// Creates the pictogram; [size] falls back to the ambient [IconTheme].
  const PelletPictogram({this.size, super.key});

  /// Height, defaulting to the ambient icon size (24).
  final double? size;

  /// Width ÷ height of the pellet (stubby, a touch taller than wide).
  static const double aspect = 0.856;

  /// The flat head (over the waist) and the flared hollow skirt, as fractions
  /// of the pellet's own box; the head is drawn lighter, the skirt darker.
  static const List<Offset> head = <Offset>[
    Offset(0.069, 0),
    Offset(0.029, 0.136),
    Offset(0.196, 0.39),
    Offset(0.804, 0.39),
    Offset(0.971, 0.136),
    Offset(0.931, 0),
  ];

  /// The flared hollow skirt below the waist (drawn darker).
  static const List<Offset> skirt = <Offset>[
    Offset(0.196, 0.39),
    Offset(0, 1),
    Offset(1, 1),
    Offset(0.804, 0.39),
  ];

  @override
  Widget build(BuildContext context) {
    final side = size ?? IconTheme.of(context).size ?? 24;
    return SizedBox(
      width: side,
      height: side,
      child: const CustomPaint(painter: _PelletPainter()),
    );
  }
}

class _PelletPainter extends CustomPainter {
  const _PelletPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = _fit(size, PelletPictogram.aspect);
    canvas
      ..drawPath(
        _polyPath(PelletPictogram.skirt, rect),
        Paint()..color = _leadDark,
      )
      ..drawPath(
        _polyPath(PelletPictogram.head, rect),
        Paint()..color = _leadLight,
      );
  }

  @override
  bool shouldRepaint(_PelletPainter oldDelegate) => false;
}

/// The NSF Fin/Grov category's pictogram (spec 0154): a .22 LR cartridge in
/// natural colours — a copper bullet over a brass case and rim — its outline
/// traced from the public-domain SAAMI-style dimensional drawing.
class CartridgePictogram extends StatelessWidget {
  /// Creates the pictogram; [size] falls back to the ambient [IconTheme].
  const CartridgePictogram({this.size, super.key});

  /// Height, defaulting to the ambient icon size (24).
  final double? size;

  /// Width ÷ height of the cartridge (tall and slim).
  static const double aspect = 0.3077;

  /// The case + rim (brass) and the bullet (copper), each as fractions of the
  /// whole cartridge's box so they align.
  static const List<Offset> caseAndRim = <Offset>[
    Offset(0.9394, 1),
    Offset(0.991, 0.9889),
    Offset(1, 0.9738),
    Offset(0.9691, 0.9603),
    Offset(0.9201, 0.9556),
    Offset(0.9304, 0.9524),
    Offset(0.9304, 0.3164),
    Offset(0.9201, 0.3132),
    Offset(0.0799, 0.3132),
    Offset(0.0696, 0.3164),
    Offset(0.0696, 0.9524),
    Offset(0.0799, 0.9556),
    Offset(0.0309, 0.9603),
    Offset(0, 0.9738),
    Offset(0.009, 0.9889),
    Offset(0.0606, 1),
  ];

  /// The bullet above the case mouth (drawn copper).
  static const List<Offset> bullet = <Offset>[
    Offset(0.857, 0.3125),
    Offset(0.8673, 0.3093),
    Offset(0.8673, 0.295),
    Offset(0.8466, 0.2062),
    Offset(0.8131, 0.1443),
    Offset(0.7822, 0.1079),
    Offset(0.7332, 0.0674),
    Offset(0.6688, 0.0333),
    Offset(0.5889, 0.0087),
    Offset(0.5206, 0),
    Offset(0.4794, 0),
    Offset(0.4111, 0.0087),
    Offset(0.3312, 0.0333),
    Offset(0.2668, 0.0674),
    Offset(0.2178, 0.1079),
    Offset(0.1869, 0.1443),
    Offset(0.1534, 0.2062),
    Offset(0.1327, 0.295),
    Offset(0.1327, 0.3093),
    Offset(0.143, 0.3125),
  ];

  @override
  Widget build(BuildContext context) {
    final side = size ?? IconTheme.of(context).size ?? 24;
    return SizedBox(
      width: side,
      height: side,
      child: const CustomPaint(painter: _CartridgePainter()),
    );
  }
}

class _CartridgePainter extends CustomPainter {
  const _CartridgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = _fit(size, CartridgePictogram.aspect);
    canvas
      ..drawPath(
        _polyPath(CartridgePictogram.caseAndRim, rect),
        Paint()..color = _brass,
      )
      ..drawPath(
        _polyPath(CartridgePictogram.bullet, rect),
        Paint()..color = _copper,
      );
  }

  @override
  bool shouldRepaint(_CartridgePainter oldDelegate) => false;
}

/// The rect a figure of [aspect] (width ÷ height) fills inside [size], scaled
/// to the box height and centred, with a small margin.
Rect _fit(Size size, double aspect) {
  const margin = 0.08;
  final h = size.height * (1 - 2 * margin);
  final w = h * aspect;
  return Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
}

/// A closed [Path] for [points] (each a 0..1 fraction of [rect]).
Path _polyPath(List<Offset> points, Rect rect) {
  final path = Path()
    ..moveTo(
      rect.left + points.first.dx * rect.width,
      rect.top + points.first.dy * rect.height,
    );
  for (final p in points.skip(1)) {
    path.lineTo(rect.left + p.dx * rect.width, rect.top + p.dy * rect.height);
  }
  return path..close();
}
