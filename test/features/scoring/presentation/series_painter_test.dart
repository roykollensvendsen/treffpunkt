// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the series painter: the last-shot highlight rule and a
// render proof that the most recently placed marker is drawn emphasised, with
// the dragged shot keeping its drag styling instead.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// A [Canvas] that records `drawCircle` calls so a test can assert how each
/// marker was drawn without producing a real picture.
class _RecordingCanvas implements Canvas {
  final List<_CircleCall> circles = <_CircleCall>[];

  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      circles.add(_CircleCall(c, radius, paint));

  @override
  void noSuchMethod(Invocation invocation) {}
}

void main() {
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
      expect(halo.paint.color, isSameColorAs(Colors.deepOrange));
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
      expect(lastFill.paint.color, isSameColorAs(Colors.lightBlueAccent));
      expect(lastFill.radius, closeTo(pelletRadius, 0.01));
      // No enlarged halo ring — same circle count as an ordinary marker.
      final earlier = markersNear(canvas, shots.first);
      expect(last.length, earlier.length);
    });
  });
}
