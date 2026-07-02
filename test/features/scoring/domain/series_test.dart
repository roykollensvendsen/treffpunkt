// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the Series value type (spec 0004).
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/series.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

void main() {
  const geometry = TargetGeometry.airRifle10m();
  const shot = Shot(dxMm: 0, dyMm: 0);
  Series emptySeries() => Series(geometry: geometry, capacity: 3);

  test('a fresh series is empty and not complete', () {
    final series = emptySeries();
    expect(series.placedCount, 0);
    expect(series.remaining, 3);
    expect(series.isComplete, isFalse);
  });

  test('placeShot appends without mutating the original', () {
    final before = emptySeries();
    final after = before.placeShot(shot);
    expect(before.placedCount, 0);
    expect(after.placedCount, 1);
    expect(after.remaining, 2);
  });

  test('a series is complete once capacity shots are placed', () {
    final series = emptySeries()
        .placeShot(shot)
        .placeShot(shot)
        .placeShot(shot);
    expect(series.isComplete, isTrue);
    expect(series.remaining, 0);
  });

  test('placing beyond capacity throws a StateError', () {
    final full = emptySeries().placeShot(shot).placeShot(shot).placeShot(shot);
    expect(() => full.placeShot(shot), throwsStateError);
  });

  test('moveShot replaces the shot at an index, leaving others untouched', () {
    final series = emptySeries()
        .placeShot(const Shot(dxMm: 1, dyMm: 1))
        .placeShot(const Shot(dxMm: 2, dyMm: 2));
    final moved = series.moveShot(0, const Shot(dxMm: 9, dyMm: 9));
    expect(moved.shots[0].dxMm, 9);
    expect(moved.shots[1].dxMm, 2);
  });

  test('moveShot with an invalid index throws a RangeError', () {
    final series = emptySeries().placeShot(shot);
    expect(() => series.moveShot(3, shot), throwsRangeError);
  });

  test('the shots list is unmodifiable and defensively copied', () {
    final source = <Shot>[shot];
    final series = Series(geometry: geometry, capacity: 3, shots: source);
    expect(() => series.shots.add(shot), throwsUnsupportedError);
    source.add(shot); // mutating the source list...
    expect(series.placedCount, 1); // ...does not change the series
  });

  test('removeLastShot undoes the newest shot, down to empty (0098)', () {
    var series = Series(
      geometry: const TargetGeometry.airPistol10m(),
      capacity: 3,
    );
    series = series
        .placeShot(const Shot(dxMm: 0, dyMm: 0))
        .placeShot(const Shot(dxMm: 5, dyMm: 5));
    expect(series.shots, hasLength(2));

    series = series.removeLastShot();
    expect(series.shots, hasLength(1));
    expect(series.shots.single, const Shot(dxMm: 0, dyMm: 0));

    series = series.removeLastShot();
    expect(series.shots, isEmpty);
    expect(series.removeLastShot, throwsStateError);
  });
}
