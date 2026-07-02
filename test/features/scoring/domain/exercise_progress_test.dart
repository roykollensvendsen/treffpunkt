// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the per-exercise progress series (spec 0090).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/exercise_progress.dart';

void main() {
  test('orders dated samples chronologically, oldest first (spec 0090)', () {
    final series = progressSeries(<ProgressSample>[
      ProgressSample(
        capturedAt: DateTime.utc(2026, 7, 2),
        points: 560,
        inner: 14,
      ),
      ProgressSample(
        capturedAt: DateTime.utc(2026, 6, 20),
        points: 541,
        inner: 9,
      ),
      ProgressSample(
        capturedAt: DateTime.utc(2026, 6, 28),
        points: 553,
        inner: 12,
      ),
    ]);

    expect(series.map((e) => e.points), <int>[541, 553, 560]);
    expect(series.map((e) => e.inner), <int>[9, 12, 14]);
  });

  test('drops undated samples — their order is unknowable (spec 0090)', () {
    final series = progressSeries(<ProgressSample>[
      const ProgressSample(capturedAt: null, points: 500, inner: 5),
      ProgressSample(
        capturedAt: DateTime.utc(2026, 7),
        points: 560,
        inner: 14,
      ),
    ]);

    expect(series, hasLength(1));
    expect(series.single.points, 560);
  });

  test('an empty input gives an empty series (spec 0090)', () {
    expect(progressSeries(const <ProgressSample>[]), isEmpty);
  });
}
