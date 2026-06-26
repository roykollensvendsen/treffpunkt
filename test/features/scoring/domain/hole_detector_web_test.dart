// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later
@TestOn('browser')
library;

// Web regression for spec 0040. The detector builds an integral image; it must
// use a web-compatible typed list. `Int64List` has no dart2js implementation
// and throws "Unsupported operation" in the browser, which silently broke
// *every* scan on the web build (the scanner swallows the error and returns
// null, so auto-detect degraded to manual placement everywhere). The VM test
// suite and `flutter build web` both pass regardless — only running the
// detector in a real browser catches it, so this runs `--platform chrome`.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/gray_field.dart';
import 'package:treffpunkt/features/scoring/domain/hole_detector.dart';
import 'package:treffpunkt/features/scoring/domain/target_calibration.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

void main() {
  test('detects a hole in the browser (no 64-bit typed list)', () {
    const geometry = TargetGeometry.airRifle10m();
    const size = 240;
    final pixels = Uint8List(size * size)..fillRange(0, size * size, 220);
    // One dark disc (radius 6) at the centre — enough to exercise the integral
    // image that the 64-bit typed list used to back.
    const centre = 120;
    const r = 6;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final dx = x - centre;
        final dy = y - centre;
        if (dx * dx + dy * dy <= r * r) pixels[y * size + x] = 30;
      }
    }
    final field = GrayField(width: size, height: size, intensities: pixels);

    final holes = const HoleDetector().detect(
      field,
      centre: const PixelPoint(120, 120),
      pixelsPerMm: 2.667,
      geometry: geometry,
      maxHoles: 5,
    );

    expect(holes, isNotEmpty); // Threw "Unsupported operation" before the fix.
  });
}
