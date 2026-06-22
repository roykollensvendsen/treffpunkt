// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the series recording notifier (spec 0006): placing, moving and
// sealing, driven through a ProviderContainer.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/program.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/presentation/series_providers.dart';

void main() {
  const scoring = ScoringService();
  const centre = Shot(dxMm: 0, dyMm: 0);
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        currentProgramProvider.overrideWithValue(Program.airRifle10m),
      ],
    );
  });
  tearDown(() => container.dispose());

  SeriesRecording read() => container.read(seriesProvider);
  SeriesNotifier notifier() => container.read(seriesProvider.notifier);

  test('placing a shot grows the series', () {
    expect(read().series.placedCount, 0);
    notifier().placeShot(centre);
    expect(read().series.placedCount, 1);
  });

  test('moving a placed shot rescoring it lower', () {
    notifier().placeShot(centre); // centre -> ring 10
    expect(scoring.scoreSeries(read().series).total, 10);

    notifier()
      ..pickUp(0)
      ..dragTo(const Shot(dxMm: 22, dyMm: 0)); // far out -> ring 2

    final score = scoring.scoreSeries(read().series);
    expect(score.shots.single.ring, 2);
    expect(score.total, 2);
    expect(read().isDragging, isTrue);
  });

  test('sealing a complete series blocks further placing and picking up', () {
    for (var i = 0; i < 10; i++) {
      notifier().placeShot(centre);
    }
    expect(read().series.isComplete, isTrue);

    notifier().seal();
    expect(read().sealed, isTrue);

    notifier().placeShot(centre); // ignored while sealed
    expect(read().series.placedCount, 10);

    notifier().pickUp(0); // ignored while sealed
    expect(read().isDragging, isFalse);
  });

  test('a complete but unsealed series cannot take more shots', () {
    for (var i = 0; i < 10; i++) {
      notifier().placeShot(centre);
    }
    notifier().placeShot(centre); // ignored: series is full
    expect(read().series.placedCount, 10);
  });
}
