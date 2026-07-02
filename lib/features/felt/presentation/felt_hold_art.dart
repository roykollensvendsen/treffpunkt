// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:ui';

import 'package:meta/meta.dart';

/// The kind of shape a [FeltArtFigure] draws (spec 0079).
enum FeltArtShape {
  /// A closed polygon through [FeltArtFigure.points].
  polygon,

  /// A full circle centred at ([FeltArtFigure.cx], [FeltArtFigure.cy]).
  circle,

  /// A circle cut flat across the bottom at [FeltArtFigure.bottomY]: the
  /// NorgesFelt C-figures.
  tcircle,

  /// An ellipse with semi-axes [FeltArtFigure.a]/[FeltArtFigure.b] rotated by
  /// [FeltArtFigure.thetaDeg].
  ellipse,
}

/// A figure's inner-treff ring (spec 0079): a stroked circle at ([cx], [cy]).
@immutable
class FeltArtRing {
  /// Creates an inner-treff ring.
  const FeltArtRing({
    required this.cx,
    required this.cy,
    required this.r,
    required this.strokeWidth,
    required this.color,
  });

  /// Ring centre x, in the hold's pixel space.
  final double cx;

  /// Ring centre y, in the hold's pixel space.
  final double cy;

  /// Ring radius, in the hold's pixel space.
  final double r;

  /// Stroke width of the ring outline.
  final double strokeWidth;

  /// Ring colour.
  final Color color;
}

/// A coloured backing plate a hold's figures sit on (spec 0079).
@immutable
class FeltArtPlate {
  /// Creates a backing plate.
  const FeltArtPlate({
    required this.rect,
    required this.color,
    required this.radius,
  });

  /// The plate rectangle, in the hold's pixel space.
  final Rect rect;

  /// The plate fill colour.
  final Color color;

  /// The plate's corner radius.
  final double radius;
}

/// The black vertical line dividing two målgrupper (spec 0079).
@immutable
class FeltArtSeparator {
  /// Creates a separator line.
  const FeltArtSeparator({required this.rect, required this.color});

  /// The line rectangle, in the hold's pixel space.
  final Rect rect;

  /// The line colour (near-black).
  final Color color;
}

/// One figure of a composed hold (spec 0079): a [shape] with a [fill] and an
/// optional inner [ring]. Only the fields for [shape] are meaningful.
///
/// A figure printed as several shapes — the tre-kvadrater stripes on holds 2
/// and 8 (spec 0086) — keeps one entry per drawn shape; the parts share a
/// [scoreIndex] and the middle square carries [innerZone].
@immutable
class FeltArtFigure {
  /// Creates a figure. Provide the parameters for [shape].
  const FeltArtFigure({
    required this.shape,
    required this.fill,
    this.points = const <Offset>[],
    this.cx = 0,
    this.cy = 0,
    this.r = 0,
    this.bottomY = 0,
    this.a = 0,
    this.b = 0,
    this.thetaDeg = 0,
    this.ring,
    this.scoreIndex,
    this.innerZone = false,
  });

  /// Which kind of shape this is.
  final FeltArtShape shape;

  /// Polygon vertices (for [FeltArtShape.polygon]), in the hold's pixel space.
  final List<Offset> points;

  /// Centre x (circle / tcircle / ellipse).
  final double cx;

  /// Centre y (circle / tcircle / ellipse).
  final double cy;

  /// Radius (circle / tcircle).
  final double r;

  /// The flat-cut y for [FeltArtShape.tcircle].
  final double bottomY;

  /// Major semi-axis (ellipse).
  final double a;

  /// Minor semi-axis (ellipse).
  final double b;

  /// Ellipse rotation, in degrees.
  final double thetaDeg;

  /// The fill colour.
  final Color fill;

  /// The inner-treff ring, if the figure has one.
  final FeltArtRing? ring;

  /// The index of the figure this shape **scores as** (spec 0086), for
  /// figures printed as several shapes: every square of a stripe carries the
  /// first square's index. Unset means the shape scores as itself.
  final int? scoreIndex;

  /// Whether a hit on this shape is an inner-zone hit (spec 0086): the
  /// middle square of a stripe. These figures have no [ring].
  final bool innerZone;
}

/// A whole hold drawn as composed vector art (spec 0079): [plates] and black
/// [separators] with [figures] positioned to real relative scale on [paper].
@immutable
class FeltHoldArt {
  /// Creates a composed hold.
  const FeltHoldArt({
    required this.number,
    required this.size,
    required this.paper,
    required this.plates,
    required this.figures,
    required this.separators,
  });

  /// 1-based hold number.
  final int number;

  /// The hold's pixel canvas size (all coordinates live in this space).
  final Size size;

  /// The paper (background) colour.
  final Color paper;

  /// The coloured backing plates, drawn under the figures.
  final List<FeltArtPlate> plates;

  /// The figures, drawn in order over the plates.
  final List<FeltArtFigure> figures;

  /// The black vertical separators between målgrupper, drawn on top.
  final List<FeltArtSeparator> separators;

  /// Whether each *scoring* figure has an inner-treff zone (spec 0104), in
  /// figure order: shapes sharing a [FeltArtFigure.scoreIndex] (a stripe's
  /// squares, spec 0086) count as one figure, which has inner when any of
  /// its shapes carries a [FeltArtFigure.ring] or is an
  /// [FeltArtFigure.innerZone] square. On the official sheets one figure —
  /// hold 5's big triangle — has no inner zone at all.
  List<bool> get innerByScoringFigure {
    final byScore = <int, bool>{};
    for (var i = 0; i < figures.length; i++) {
      final figure = figures[i];
      final key = figure.scoreIndex ?? i;
      byScore[key] =
          (byScore[key] ?? false) || figure.ring != null || figure.innerZone;
    }
    return List<bool>.unmodifiable(byScore.values);
  }
}
