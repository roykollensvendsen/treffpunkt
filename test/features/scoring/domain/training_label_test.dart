// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the training-label builder (spec 0041): box-space calibration
// and holes are converted to the uploaded image's pixels, the geometry is
// self-describing, and each hole carries its source/edited flags.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_calibration.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/domain/training_label.dart';
import 'package:treffpunkt/features/scoring/domain/training_sample.dart';

TrainingSample _sample({
  required double boxSide,
  required TargetCalibration calibration,
  List<TrainingHole> holes = const <TrainingHole>[],
}) => TrainingSample(
  id: 'sample-1',
  imageBytes: Uint8List(0),
  geometry: const TargetGeometry.airRifle10m(),
  calibration: calibration,
  boxSide: boxSide,
  holes: holes,
  capturedAt: DateTime.utc(2026, 6, 24, 12),
  appVersion: 'build abc123',
);

void main() {
  test('label carries the schema version and self-describing geometry', () {
    final label = buildLabel(
      _sample(
        boxSide: 240,
        calibration: const TargetCalibration(
          centre: PixelPoint(120, 120),
          pixelsPerMm: 2.667,
        ),
      ),
      imageWidth: 240,
      imageHeight: 240,
    );

    expect(label['schemaVersion'], trainingLabelSchemaVersion);
    expect(label['sampleId'], 'sample-1');
    expect(label['appVersion'], 'build abc123');
    expect(label['capturedAt'], '2026-06-24T12:00:00.000Z');

    final geometry = label['geometry'] as Map<String, dynamic>;
    expect(geometry['name'], '10 m Air Rifle');
    expect(geometry['caliberMm'], 4.5);
    expect(geometry['ringOuterDiametersMm'], hasLength(10));
    expect(geometry['blackBullDiameterMm'], 30.5);
    expect(geometry['innerTenDiameterMm'], isNull);
    expect(geometry['lowestRingValue'], 1);
  });

  test('when the image fills the box, image pixels equal box pixels', () {
    final label = buildLabel(
      _sample(
        boxSide: 240,
        calibration: const TargetCalibration(
          centre: PixelPoint(120, 120),
          pixelsPerMm: 2.667,
        ),
        holes: const <TrainingHole>[
          TrainingHole(
            shot: Shot(dxMm: 0, dyMm: 0),
            source: TrainingHoleSource.auto,
          ),
          TrainingHole(
            shot: Shot(dxMm: 10, dyMm: 0),
            source: TrainingHoleSource.manual,
            edited: true,
          ),
        ],
      ),
      imageWidth: 240,
      imageHeight: 240,
    );

    final calibration = label['calibration'] as Map<String, dynamic>;
    final centre = calibration['centrePx'] as Map<String, double>;
    expect(centre['x'], closeTo(120, 1e-9));
    expect(centre['y'], closeTo(120, 1e-9));
    expect(calibration['pixelsPerMm'], closeTo(2.667, 1e-9));

    final holes = label['holes'] as List<Map<String, dynamic>>;
    expect(holes, hasLength(2));
    expect(holes[0]['xPx'], closeTo(120, 1e-9)); // centre hole
    expect(holes[0]['yPx'], closeTo(120, 1e-9));
    expect(holes[0]['source'], 'auto');
    expect(holes[0]['edited'], false);
    // 10 mm right of centre at 2.667 px/mm ≈ 26.67 px.
    expect(holes[1]['xPx'], closeTo(120 + 26.67, 0.1));
    expect(holes[1]['dxMm'], 10);
    expect(holes[1]['source'], 'manual');
    expect(holes[1]['edited'], true);
  });

  test('a letterboxed image converts box pixels to image pixels', () {
    // Image 120×60 in a 240 box → scale 2, offsetX 0, offsetY 60.
    final label = buildLabel(
      _sample(
        boxSide: 240,
        calibration: const TargetCalibration(
          centre: PixelPoint(120, 120),
          pixelsPerMm: 4,
        ),
      ),
      imageWidth: 120,
      imageHeight: 60,
    );

    final calibration = label['calibration'] as Map<String, dynamic>;
    final centre = calibration['centrePx'] as Map<String, double>;
    // toField((120,120)) = ((120-0)/2, (120-60)/2) = (60, 30).
    expect(centre['x'], closeTo(60, 1e-9));
    expect(centre['y'], closeTo(30, 1e-9));
    // Box px/mm 4 over scale 2 → 2 image px/mm.
    expect(calibration['pixelsPerMm'], closeTo(2, 1e-9));
    final image = label['image'] as Map<String, dynamic>;
    expect(image['widthPx'], 120);
    expect(image['heightPx'], 60);
  });
}
