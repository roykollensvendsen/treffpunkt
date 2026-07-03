// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the series painter: the last-shot highlight rule and a
// render proof that the most recently placed marker is drawn emphasised, with
// the dragged shot keeping its drag styling instead.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/app_theme.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/presentation/series_painter.dart';

final TargetGeometry _geometry =
    ProgramCatalogue.airRifle10m.stages.first.geometry;

SeriesPainter _painter(List<Shot> shots, {int? draggingIndex}) => SeriesPainter(
  geometry: _geometry,
  shots: shots,
  draggingIndex: draggingIndex,
);

/// A single `drawCircle` call captured from a [_RecordingCanvas].
class _CircleCall {
  _CircleCall(this.centre, this.radius, this.paint);

  final Offset centre;
  final double radius;
  final Paint paint;
}

/// A [Canvas] that records `drawCircle`, `drawParagraph` and `drawRect`
/// calls so a test can assert how each marker, ring label and sighting
/// line was drawn without producing a real picture.
class _RecordingCanvas implements Canvas {
  final List<_CircleCall> circles = <_CircleCall>[];
  final List<Offset> paragraphs = <Offset>[];
  final List<Rect> rects = <Rect>[];

  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      circles.add(_CircleCall(c, radius, paint));

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) =>
      paragraphs.add(offset);

  @override
  void drawRect(Rect rect, Paint paint) => rects.add(rect);

  @override
  void noSuchMethod(Invocation invocation) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const size = Size(400, 400);
  // The plain pellet radius the painter draws for an ordinary marker.
  final scale = (size.shortestSide / 2) / _geometry.maxScoringRadiusMm;
  final pelletRadius = _geometry.pelletRadiusMm * scale;

  group('highlightedIndex', () {
    test('is null for an empty series', () {
      expect(_painter(const <Shot>[]).highlightedIndex, isNull);
    });

    test('is the only index for a one-shot series', () {
      expect(
        _painter(const <Shot>[Shot(dxMm: 0, dyMm: 0)]).highlightedIndex,
        0,
      );
    });

    test('is the last index for a multi-shot series', () {
      final shots = <Shot>[
        const Shot(dxMm: 0, dyMm: 0),
        const Shot(dxMm: 4, dyMm: 0),
        const Shot(dxMm: -3, dyMm: 2),
      ];
      expect(_painter(shots).highlightedIndex, shots.length - 1);
    });
  });

  group('render proof', () {
    // Three shots placed apart so their markers do not overlap on the canvas.
    final shots = <Shot>[
      const Shot(dxMm: -6, dyMm: 0),
      const Shot(dxMm: 0, dyMm: 0),
      const Shot(dxMm: 6, dyMm: 0),
    ];

    List<_CircleCall> markersNear(_RecordingCanvas canvas, Shot shot) {
      final centre = Offset(size.width / 2, size.height / 2);
      final markerCentre =
          centre + Offset(shot.dxMm * scale, shot.dyMm * scale);
      return canvas.circles
          .where((c) => (c.centre - markerCentre).distance < 0.5)
          .toList();
    }

    test('draws the last marker at normal size with a coloured halo ring', () {
      final canvas = _RecordingCanvas();
      _painter(shots).paint(canvas, size);

      // An earlier marker: a filled disc at the pellet radius plus its single
      // black outline ring — two circles, none larger than the pellet.
      final earlier = markersNear(canvas, shots.first);
      final earlierFills = earlier
          .where((c) => c.paint.style == PaintingStyle.fill)
          .toList();
      expect(earlierFills, hasLength(1));
      expect(earlierFills.single.radius, closeTo(pelletRadius, 0.01));
      expect(earlier.where((c) => c.radius > pelletRadius + 0.5), isEmpty);

      // The last marker: the SAME-sized fill (not enlarged) plus an extra
      // coloured halo ring beyond the plain fill + black outline pair.
      final last = markersNear(canvas, shots.last);
      final lastFill = last.firstWhere(
        (c) => c.paint.style == PaintingStyle.fill,
      );
      expect(
        lastFill.radius,
        closeTo(pelletRadius, 0.01),
        reason: 'the last marker is emphasised by a halo, not by size',
      );
      // The halo: a stroked ring wider than the marker, in the highlight
      // colour — an extra circle an ordinary marker does not have.
      final halo = last.firstWhere(
        (c) =>
            c.paint.style == PaintingStyle.stroke &&
            c.radius > pelletRadius + 0.5,
      );
      expect(halo.paint.color, isSameColorAs(TreffColors.light.lastShot));
      expect(last.length, greaterThan(earlier.length));
    });

    test('the dragged last shot keeps drag styling and gets no halo', () {
      final canvas = _RecordingCanvas();
      _painter(shots, draggingIndex: shots.length - 1).paint(canvas, size);

      final last = markersNear(canvas, shots.last);
      // Drag wins: the fill is the drag colour, not enlarged.
      final lastFill = last.firstWhere(
        (c) => c.paint.style == PaintingStyle.fill,
      );
      expect(
        lastFill.paint.color,
        isSameColorAs(TreffColors.light.draggedShot),
      );
      expect(lastFill.radius, closeTo(pelletRadius, 0.01));
      // No enlarged halo ring — same circle count as an ordinary marker.
      final earlier = markersNear(canvas, shots.first);
      expect(last.length, earlier.length);
    });
  });

  group('inner-ten ring (spec 0103)', () {
    List<_CircleCall> centreCircles(_RecordingCanvas canvas) {
      final centre = Offset(size.width / 2, size.height / 2);
      return canvas.circles
          .where((c) => (c.centre - centre).distance < 0.01)
          .toList();
    }

    test('a face with an inner ten gets its ring drawn', () {
      const geometry = TargetGeometry.airPistol10m();
      final canvas = _RecordingCanvas();
      const SeriesPainter(
        geometry: geometry,
        shots: <Shot>[],
        draggingIndex: null,
      ).paint(canvas, size);

      final scale = (size.shortestSide / 2) / geometry.maxScoringRadiusMm;
      final innerRadius = geometry.innerTenDiameterMm! / 2 * scale;
      final ring = centreCircles(canvas).where(
        (c) =>
            c.paint.style == PaintingStyle.stroke &&
            (c.radius - innerRadius).abs() < 0.01,
      );
      expect(ring, hasLength(1));
      // 5 mm sits deep inside the 59.5 mm black bull → drawn in white, like
      // the scoring rings on the black.
      expect(ring.single.paint.color, isSameColorAs(Colors.white70));
    });

    test('a face without an inner ten draws only bull + scoring rings', () {
      const geometry = TargetGeometry.airRifle10m();
      expect(geometry.hasInnerTen, isFalse);
      final canvas = _RecordingCanvas();
      const SeriesPainter(
        geometry: geometry,
        shots: <Shot>[],
        draggingIndex: null,
      ).paint(canvas, size);

      // The filled bull plus one stroked circle per scoring ring — nothing
      // more at the centre.
      final rings = geometry.highestRing - geometry.lowestRingValue + 1;
      expect(centreCircles(canvas), hasLength(rings + 1));
    });
  });

  group('ring labels (spec 0113)', () {
    _RecordingCanvas paintFace(TargetGeometry geometry, {Size at = size}) {
      final canvas = _RecordingCanvas();
      SeriesPainter(
        geometry: geometry,
        shots: const <Shot>[],
        draggingIndex: null,
      ).paint(canvas, at);
      return canvas;
    }

    test('air pistol prints 1–8 in all four directions', () {
      // Digits 1–8, horizontal and vertical (gtr-2026); 9/10 unnumbered.
      final canvas = paintFace(const TargetGeometry.airPistol10m());
      expect(canvas.paragraphs, hasLength(8 * 4));
    });

    test('the precision face prints 1–9 in all four directions', () {
      final canvas = paintFace(const TargetGeometry.pistol25mPrecision());
      expect(canvas.paragraphs, hasLength(9 * 4));
    });

    test('the duel face prints 5–9 vertically plus the sighting lines', () {
      // A shooting-screen-sized canvas: the 5 mm digits are readable here.
      final canvas = paintFace(
        const TargetGeometry.pistol25mRapid(),
        at: const Size(700, 700),
      );
      expect(canvas.paragraphs, hasLength(5 * 2));
      // The two white horizontal sighting lines replace the side digits
      // (125 × 5 mm each on the real sheet). The paper rect is also a
      // drawRect — so exactly paper + 2 lines.
      expect(canvas.rects, hasLength(3));
    });

    test('the luftduell face prints 5–9 on both axes, no stripes (0123)', () {
      // The physical sheet and the § 5.1.18.1.2 figure: ordinary digits on
      // both axes, no sighting lines. The 2 mm digits are readable here
      // because the small face maps to a large mm scale.
      final canvas = paintFace(const TargetGeometry.airDuel10m());
      expect(canvas.paragraphs, hasLength(5 * 4));
      expect(canvas.rects, hasLength(1)); // the paper only
    });

    test('the 25 m duel lines anchor at the outermost ring (0121)', () {
      const geometry = TargetGeometry.pistol25mRapid();
      final canvas = paintFace(geometry, at: const Size(700, 700));
      const centre = 700 / 2;
      final scale = (700 / 2) / geometry.maxScoringRadiusMm;
      final lines = canvas.rects.skip(1).toList(); // paper rect first
      final left = lines.reduce((a, b) => a.left < b.left ? a : b);
      // Outer end at the outermost ring's edge (500/2 mm out), 125 mm in.
      expect(left.left, closeTo(centre - 250 * scale, 0.01));
      expect(left.right, closeTo(centre - (250 - 125) * scale, 0.01));
    });

    test('the duel face shows its values at phone size (spec 0127)', () {
      // 5 mm digits on a 50 cm face are ~3,5 px at the default size — the
      // old sheet-true rule hid them all (the bug report). The 10 px floor
      // shows them; the band-fit rule still applies.
      final canvas = paintFace(const TargetGeometry.pistol25mRapid());
      expect(canvas.paragraphs, hasLength(5 * 2));
    });

    test('the label size floors at 10 px and fits the band (spec 0127)', () {
      // Sheet-true above the floor passes through …
      expect(ringLabelFontPx(sheetPx: 14, bandPx: 40), 14);
      // … below it, the floor wins …
      expect(ringLabelFontPx(sheetPx: 3.5, bandPx: 20), 10);
      // … and a digit that cannot fit its own band is skipped.
      expect(ringLabelFontPx(sheetPx: 2, bandPx: 6), isNull);
    });

    test('labels are skipped when they would be unreadably small', () {
      // A scorecard mini-target: 2 mm digits at this scale would be smudge.
      final canvas = paintFace(
        const TargetGeometry.airPistol10m(),
        at: const Size(120, 120),
      );
      expect(canvas.paragraphs, isEmpty);
    });
  });
}
