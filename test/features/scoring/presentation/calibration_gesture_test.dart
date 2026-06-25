// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the calibrate pan-pinch maths (spec 0046): a one-finger drag
// moves the ring overlay, a pinch resizes it about the focal point.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/target_calibration.dart';
import 'package:treffpunkt/features/scoring/presentation/scan_target_screen.dart';

void main() {
  const startCentre = PixelPoint(100, 100);
  const startFocal = PixelPoint(80, 90);
  const startPpm = 4.0;

  test('a one-finger drag (scale 1) moves the centre by the finger delta', () {
    final next = calibrationAfterGesture(
      startCentre: startCentre,
      startPixelsPerMm: startPpm,
      startFocal: startFocal,
      focal: const PixelPoint(80 + 12, 90 - 7), // dragged +12 / -7
      scale: 1,
    );
    expect(next.centre.x, closeTo(112, 1e-9));
    expect(next.centre.y, closeTo(93, 1e-9));
    expect(next.pixelsPerMm, closeTo(startPpm, 1e-9));
  });

  test('a pinch scales the scale and keeps the focal point fixed', () {
    final next = calibrationAfterGesture(
      startCentre: startCentre,
      startPixelsPerMm: startPpm,
      startFocal: startFocal,
      focal: startFocal, // fingers centred where they started
      scale: 2,
    );
    expect(next.pixelsPerMm, closeTo(8, 1e-9));
    // The focal point maps to itself, so the overlay grows around it.
    // centre = focal + 2*(startCentre - startFocal) = (80,90)+2*(20,10).
    expect(next.centre.x, closeTo(120, 1e-9));
    expect(next.centre.y, closeTo(110, 1e-9));
  });
}
