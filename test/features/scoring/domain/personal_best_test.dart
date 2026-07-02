// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/personal_best.dart';

void main() {
  group('isNewPersonalBest (spec 0101)', () {
    test('more points than every prior result is a new best', () {
      expect(
        isNewPersonalBest(
          result: (points: 95, inner: 0),
          prior: [(points: 90, inner: 5), (points: 94, inner: 9)],
        ),
        isTrue,
      );
    });

    test('fewer points than the best prior is not a new best', () {
      expect(
        isNewPersonalBest(
          result: (points: 89, inner: 9),
          prior: [(points: 90, inner: 0)],
        ),
        isFalse,
      );
    });

    test('equal points with more inner hits is a new best (spec 0085)', () {
      expect(
        isNewPersonalBest(
          result: (points: 90, inner: 4),
          prior: [(points: 90, inner: 3)],
        ),
        isTrue,
      );
    });

    test('equalling the old best exactly is not a new best', () {
      expect(
        isNewPersonalBest(
          result: (points: 90, inner: 3),
          prior: [(points: 90, inner: 3)],
        ),
        isFalse,
      );
    });

    test('beating some priors but not all is not a new best', () {
      expect(
        isNewPersonalBest(
          result: (points: 92, inner: 1),
          prior: [(points: 85, inner: 0), (points: 93, inner: 0)],
        ),
        isFalse,
      );
    });

    test('a first-ever result is not a new best', () {
      expect(
        isNewPersonalBest(result: (points: 100, inner: 10), prior: []),
        isFalse,
      );
    });
  });
}
