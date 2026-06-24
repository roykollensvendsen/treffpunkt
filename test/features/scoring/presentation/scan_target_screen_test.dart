// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the camera scan screen (spec 0039): a fake image source
// drives the capture → calibrate → place flow without a real camera; taps on
// the photo overlay are scored live through the default handle calibration,
// placement is capped at the series' remaining capacity, and confirming returns
// the placed shots so the caller can commit them.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/data/image_source_service.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/presentation/scan_target_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

import '../fake_image_source_service.dart';

/// A 1×1 transparent PNG, so `Image.memory` has valid bytes to decode.
final Uint8List _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNk'
  '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

/// Captures the `List<Shot>?` the scan screen pops, for assertions.
class _Host {
  List<Shot>? popped;
  bool didPop = false;
}

// Air rifle has no inner ten, so the centre's live score is exactly "10".
const TargetGeometry _geometry = TargetGeometry.airRifle10m();

/// Pumps a button that pushes the scan screen (for [maxShots]) and opens it.
Future<_Host> _open(
  WidgetTester tester, {
  required FakeImageSourceService source,
  int maxShots = 10,
}) async {
  final host = _Host();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [imageSourceServiceProvider.overrideWithValue(source)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final shots = await Navigator.of(context).push<List<Shot>>(
                    MaterialPageRoute<List<Shot>>(
                      builder: (_) => ScanTargetScreen(
                        geometry: _geometry,
                        maxShots: maxShots,
                      ),
                    ),
                  );
                  host
                    ..popped = shots
                    ..didPop = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return host;
}

/// Drives the capture (camera) and calibrate steps so a test reaches placement.
Future<void> _reachPlacement(WidgetTester tester) async {
  await tester.tap(find.byKey(scanCameraButtonKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(scanCalibrateConfirmKey));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the capture step shows camera and gallery buttons', (
    tester,
  ) async {
    await _open(tester, source: FakeImageSourceService());

    expect(find.byKey(scanCameraButtonKey), findsOneWidget);
    expect(find.byKey(scanGalleryButtonKey), findsOneWidget);
  });

  testWidgets('picking a photo moves to calibration with the handles', (
    tester,
  ) async {
    final source = FakeImageSourceService(
      result: ImagePicked(PickedImage(bytes: _pngBytes)),
    );
    await _open(tester, source: source);

    await tester.tap(find.byKey(scanCameraButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(scanCentreHandleKey), findsOneWidget);
    expect(find.byKey(scanScaleHandleKey), findsOneWidget);
    expect(find.byKey(scanCalibrateConfirmKey), findsOneWidget);
  });

  testWidgets('tapping the centre scores a ten, a far tap scores zero', (
    tester,
  ) async {
    final source = FakeImageSourceService(
      result: ImagePicked(PickedImage(bytes: _pngBytes)),
    );
    await _open(tester, source: source);
    await _reachPlacement(tester);

    String liveScore() =>
        tester.widget<Text>(find.byKey(scanLiveScoreKey)).data!;

    // The default centre handle sits at the overlay's middle.
    await tester.tapAt(tester.getCenter(find.byKey(scanOverlayKey)));
    await tester.pump();
    expect(liveScore(), '10');

    // A tap near the corner is far outside the rings — a miss.
    await tester.tapAt(
      tester.getTopLeft(find.byKey(scanOverlayKey)) + const Offset(4, 4),
    );
    await tester.pump();
    expect(liveScore(), '0');
  });

  testWidgets('placement is capped at the remaining capacity', (tester) async {
    final source = FakeImageSourceService(
      result: ImagePicked(PickedImage(bytes: _pngBytes)),
    );
    await _open(tester, source: source, maxShots: 1);
    await _reachPlacement(tester);

    final centre = tester.getCenter(find.byKey(scanOverlayKey));
    await tester.tapAt(centre);
    await tester.pump();
    await tester.tapAt(centre + const Offset(10, 10)); // rejected: full
    await tester.pump();

    expect(find.text('1 av 1 plassert'), findsOneWidget);
  });

  testWidgets('confirming returns the placed shots to the caller', (
    tester,
  ) async {
    final source = FakeImageSourceService(
      result: ImagePicked(PickedImage(bytes: _pngBytes)),
    );
    final host = await _open(tester, source: source, maxShots: 3);
    await _reachPlacement(tester);

    await tester.tapAt(tester.getCenter(find.byKey(scanOverlayKey)));
    await tester.pump();
    await tester.tap(find.byKey(scanConfirmKey));
    await tester.pumpAndSettle();

    expect(host.didPop, isTrue);
    expect(host.popped, hasLength(1));
    // The centre tap is at (0,0) mm.
    expect(host.popped!.single.distanceMm, closeTo(0, 0.5));
  });
}
