// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the heuristic bullet-hole detector (spec 0040), driven by
// synthetic grayscale fields: dark holes on white and light holes on black are
// both found, thin lines and bull-edge fragments are rejected, lighting
// gradients don't fool it, and the maxHoles cap / dedup hold.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/gray_field.dart';
import 'package:treffpunkt/features/scoring/domain/hole_detector.dart';
import 'package:treffpunkt/features/scoring/domain/target_calibration.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

/// A mutable painter for building synthetic [GrayField]s.
class _Canvas {
  _Canvas(this.width, this.height, int background)
    : pixels = Uint8List(width * height)
        ..fillRange(0, width * height, background);

  final int width;
  final int height;
  final Uint8List pixels;

  void disc(double cx, double cy, double r, int value) {
    final r2 = r * r;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final dx = x - cx;
        final dy = y - cy;
        if (dx * dx + dy * dy <= r2) pixels[y * width + x] = value;
      }
    }
  }

  void rect(int x0, int y0, int x1, int y1, int value) {
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        pixels[y * width + x] = value;
      }
    }
  }

  GrayField build() =>
      GrayField(width: width, height: height, intensities: pixels);
}

bool _near(PixelPoint p, double x, double y, [double tol = 2.5]) =>
    (p.x - x).abs() <= tol && (p.y - y).abs() <= tol;

void main() {
  const geometry = TargetGeometry.airRifle10m();
  const detector = HoleDetector();
  // At 2.667 px/mm: holeR ≈ 6 px, roiR ≈ 73 px, bull-edge ≈ 40.7 px.
  const ppm = 2.667;
  const centre = PixelPoint(120, 120);
  const holeR = 6.0;

  List<PixelPoint> run(GrayField field, {int maxHoles = 10}) => detector.detect(
    field,
    centre: centre,
    pixelsPerMm: ppm,
    geometry: geometry,
    maxHoles: maxHoles,
  );

  test('finds three dark holes on white paper', () {
    final canvas = _Canvas(240, 240, 220)
      ..disc(120, 120, holeR, 30)
      ..disc(150, 120, holeR, 30)
      ..disc(120, 90, holeR, 30);

    final found = run(canvas.build());

    expect(found, hasLength(3));
    expect(found.any((p) => _near(p, 120, 120)), isTrue);
    expect(found.any((p) => _near(p, 150, 120)), isTrue);
    expect(found.any((p) => _near(p, 120, 90)), isTrue);
  });

  test('finds a light hole inside the black bull (two-sided contrast)', () {
    // A large black region (like the bull) with a light (torn-paper) hole at
    // its centre, off the bull-edge band. The region is far larger than the
    // detector's background window, so its interior reads as background and
    // only the light hole stands out.
    final canvas = _Canvas(240, 240, 220)
      ..rect(70, 5, 170, 105, 20)
      ..disc(120, 55, holeR, 235);

    final found = run(canvas.build());

    expect(found.any((p) => _near(p, 120, 55)), isTrue);
  });

  test('rejects a thin printed line', () {
    final canvas = _Canvas(240, 240, 220)..rect(70, 119, 170, 120, 30);

    expect(run(canvas.build()), isEmpty);
  });

  test('rejects a blob on the bull-edge band, keeps one off it', () {
    final canvas = _Canvas(240, 240, 220)
      ..disc(161, 120, holeR, 30) // r ≈ 41 px, on the bull edge → rejected
      ..disc(178, 120, holeR, 30); // r ≈ 58 px, clear of it → kept

    final found = run(canvas.build());

    expect(found, hasLength(1));
    expect(found.single, predicate<PixelPoint>((p) => _near(p, 178, 120)));
  });

  test('finds holes despite a lighting gradient', () {
    final canvas = _Canvas(240, 240, 200);
    // A smooth left-to-right ramp the local-mean subtraction should absorb.
    for (var y = 0; y < 240; y++) {
      for (var x = 0; x < 240; x++) {
        canvas.pixels[y * 240 + x] = (120 + x * 0.4).round().clamp(0, 255);
      }
    }
    canvas
      ..disc(120, 120, holeR, 20)
      ..disc(150, 120, holeR, 20);

    final found = run(canvas.build());

    expect(found, hasLength(2));
  });

  test('finds nothing in low-contrast noise', () {
    final canvas = _Canvas(240, 240, 200);
    final random = math.Random(7);
    for (var i = 0; i < canvas.pixels.length; i++) {
      canvas.pixels[i] = 200 + random.nextInt(11) - 5; // ±5, under threshold
    }

    expect(run(canvas.build()), isEmpty);
  });

  test('ignores a hole outside the scoring region', () {
    final canvas = _Canvas(240, 240, 220)..disc(120, 205, holeR, 30); // r ≈ 85

    expect(run(canvas.build()), isEmpty);
  });

  test('respects the maxHoles cap', () {
    final canvas = _Canvas(240, 240, 220)
      ..disc(120, 120, holeR, 30)
      ..disc(150, 120, holeR, 30)
      ..disc(90, 120, holeR, 30)
      ..disc(120, 90, holeR, 30)
      ..disc(120, 150, holeR, 30);

    expect(run(canvas.build(), maxHoles: 3), hasLength(3));
  });

  test('merges two overlapping holes into one', () {
    final canvas = _Canvas(240, 240, 220)
      ..disc(120, 120, holeR, 30)
      ..disc(124, 120, holeR, 30); // 4 px apart, within the dedup radius

    expect(run(canvas.build()), hasLength(1));
  });
}
