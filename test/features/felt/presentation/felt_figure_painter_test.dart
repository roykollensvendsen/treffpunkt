// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the inner-zone placement (spec 0068): the innertreff circle
// sits on each figure's centre of mass, not the bounding-box centre.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/domain/felt_figure.dart';
import 'package:treffpunkt/features/felt/presentation/felt_figure_painter.dart';

void main() {
  group('figureCentroid (spec 0068)', () {
    const size = Size(100, 100);

    test('symmetric shapes centre on the box', () {
      for (final type in <FeltFigureType>[
        FeltFigureType.circle,
        FeltFigureType.oval,
        FeltFigureType.egg,
        FeltFigureType.hexagon,
        FeltFigureType.stripe,
        FeltFigureType.bowlingPin,
        FeltFigureType.reducedFigure,
      ]) {
        expect(figureCentroid(type, size), const Offset(50, 50));
      }
    });

    test('a triangle apex-up sits two-thirds down', () {
      final c = figureCentroid(FeltFigureType.triangle, size);
      expect(c.dx, 50);
      expect(c.dy, closeTo(66.7, 0.1));
    });

    test('the animals centre on their body, below and within the box', () {
      // Each traced silhouette's area centroid lands on the body/head — off the
      // bounding-box centre — matching where the real targets ring the zone.
      final hare = figureCentroid(FeltFigureType.hare, size);
      expect(hare.dy, greaterThan(55)); // lower body
      expect(hare.dx, closeTo(50, 6));

      final wolf = figureCentroid(FeltFigureType.wolfHead, size);
      expect(wolf.dy, greaterThan(50));
      expect(wolf.dx, lessThan(50)); // mass skews left of the box centre

      final rype = figureCentroid(FeltFigureType.ptarmigan, size);
      expect(rype.dx, greaterThan(55)); // body sits right of centre
      expect(rype.dy, greaterThan(50));
    });
  });
}
