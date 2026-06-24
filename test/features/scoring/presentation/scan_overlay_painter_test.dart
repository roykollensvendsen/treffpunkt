// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the scan overlay's geometry (spec 0039): ring radii and shot
// markers are placed through the calibration, so the overlay lines up with the
// photographed target.
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_calibration.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/presentation/scan_overlay_painter.dart';

void main() {
  const geometry = TargetGeometry.airRifle10m();
  const calibration = TargetCalibration(
    centre: PixelPoint(100, 100),
    pixelsPerMm: 2,
  );

  test('the centre offset is the calibration centre', () {
    const painter = ScanOverlayPainter(
      geometry: geometry,
      calibration: calibration,
      shots: <Shot>[],
    );
    expect(painter.centreOffset, const Offset(100, 100));
  });

  test('a ring radius is its outer radius scaled to pixels', () {
    const painter = ScanOverlayPainter(
      geometry: geometry,
      calibration: calibration,
      shots: <Shot>[],
    );
    // Ring 1 outer diameter is 45.5 mm → 22.75 mm radius → 45.5 px at 2 px/mm.
    expect(painter.ringRadiusPx(1), closeTo(45.5, 1e-9));
  });

  test('markers sit where each shot maps to in pixels', () {
    const painter = ScanOverlayPainter(
      geometry: geometry,
      calibration: calibration,
      shots: <Shot>[Shot(dxMm: 10, dyMm: 0), Shot(dxMm: 0, dyMm: -5)],
    );
    expect(painter.markerCentres, <Offset>[
      const Offset(120, 100), // 10 mm right of centre at 2 px/mm
      const Offset(100, 90), // 5 mm up
    ]);
  });
}
