// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the inner-zone placement (spec 0068/0077): the innertreff
// circle sits on each figure's centre of mass. Circle/oval/stripe use the box
// centre; every other figure uses the area centroid of its traced outline.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/domain/felt_figure.dart';
import 'package:treffpunkt/features/felt/presentation/felt_figure_painter.dart';

void main() {
  group('figureCentroid (spec 0077)', () {
    const size = Size(100, 100);

    test('circle, oval and stripe centre on the box', () {
      for (final type in <FeltFigureType>[
        FeltFigureType.circle,
        FeltFigureType.oval,
        FeltFigureType.stripe,
      ]) {
        expect(figureCentroid(type, size), const Offset(50, 50));
      }
    });

    test('every traced figure has its centroid inside the box', () {
      for (final type in <FeltFigureType>[
        FeltFigureType.triangle,
        FeltFigureType.rightTriangle,
        FeltFigureType.hexagon,
        FeltFigureType.egg,
        FeltFigureType.bowlingPin,
        FeltFigureType.reducedFigure,
        FeltFigureType.hare,
        FeltFigureType.wolfHead,
        FeltFigureType.ptarmigan,
      ]) {
        final c = figureCentroid(type, size);
        expect(c.dx, inInclusiveRange(0, 100), reason: '${type.name} dx');
        expect(c.dy, inInclusiveRange(0, 100), reason: '${type.name} dy');
      }
    });

    test('an apex-up triangle carries its mass below the middle', () {
      expect(figureCentroid(FeltFigureType.triangle, size).dy, greaterThan(50));
    });

    test('the hare centres on its lower body', () {
      expect(figureCentroid(FeltFigureType.hare, size).dy, greaterThan(50));
    });
  });

  test('every figure type builds a non-empty path (spec 0077)', () {
    for (final type in FeltFigureType.values) {
      expect(
        figurePath(type, const Size(100, 100)).getBounds().isEmpty,
        isFalse,
        reason: type.name,
      );
    }
  });

  test('a C-figure is a circle cut flat at the bottom (spec 0077)', () {
    // Wide as the diameter, a little shorter than it (the flat cut).
    final c = FeltFigure.circle(20);
    expect(c.widthCm, 20);
    expect(c.heightCm, lessThan(20));
    expect(c.heightCm, 20 * FeltFigure.circleHeightRatio);

    // The path's flat bottom is narrower than the full width at the widest.
    final path = figurePath(FeltFigureType.circle, const Size(100, 90));
    final bounds = path.getBounds();
    expect(bounds.width, closeTo(100, 1));
    // The bottom edge (chord) is inside the box width, not the full 100.
    expect(path.contains(const Offset(5, 89)), isFalse);
    expect(path.contains(const Offset(50, 89)), isTrue);
  });
}
