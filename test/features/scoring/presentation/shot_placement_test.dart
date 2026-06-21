// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the placed-shot + drag state (spec 0002).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/presentation/scoring_providers.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  ShotPlacement read() => container.read(shotPlacementProvider);
  ShotPlacementNotifier notifier() =>
      container.read(shotPlacementProvider.notifier);

  test('starts empty and not dragging', () {
    expect(read().shot, isNull);
    expect(read().isDragging, isFalse);
  });

  test('place sets the shot and is not dragging', () {
    notifier().place(const Shot(dxMm: 1, dyMm: 2));
    expect(read().shot, isNotNull);
    expect(read().isDragging, isFalse);
  });

  test('pickUp marks the shot as dragging', () {
    notifier()
      ..place(const Shot(dxMm: 1, dyMm: 2))
      ..pickUp(const Shot(dxMm: 1, dyMm: 2));
    expect(read().isDragging, isTrue);
  });

  test('dragTo moves the shot while keeping it picked up', () {
    notifier()
      ..pickUp(const Shot(dxMm: 0, dyMm: 0))
      ..dragTo(const Shot(dxMm: 5, dyMm: 0));
    expect(read().shot?.dxMm, 5);
    expect(read().isDragging, isTrue);
  });

  test('drop ends the drag and keeps the shot', () {
    notifier()
      ..pickUp(const Shot(dxMm: 5, dyMm: 0))
      ..drop();
    expect(read().isDragging, isFalse);
    expect(read().shot?.dxMm, 5);
  });
}
