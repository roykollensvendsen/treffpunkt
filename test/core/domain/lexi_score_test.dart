// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/domain/lexi_score.dart';

void main() {
  group('compareLexiScore', () {
    test('more points wins regardless of inner hits', () {
      expect(
        compareLexiScore((points: 95, inner: 0), (points: 94, inner: 9)),
        greaterThan(0),
      );
      expect(
        compareLexiScore((points: 94, inner: 9), (points: 95, inner: 0)),
        lessThan(0),
      );
    });

    test('equal points fall back to inner hits', () {
      expect(
        compareLexiScore((points: 94, inner: 5), (points: 94, inner: 4)),
        greaterThan(0),
      );
      expect(
        compareLexiScore((points: 94, inner: 4), (points: 94, inner: 5)),
        lessThan(0),
      );
    });

    test('equal points and inner hits compare equal', () {
      expect(
        compareLexiScore((points: 94, inner: 5), (points: 94, inner: 5)),
        0,
      );
    });
  });

  group('isBetterLexi', () {
    test('strictly greater on points is better', () {
      expect(
        isBetterLexi((points: 95, inner: 0), (points: 94, inner: 9)),
        isTrue,
      );
    });

    test('equal points but more inner hits is better', () {
      expect(
        isBetterLexi((points: 94, inner: 6), (points: 94, inner: 5)),
        isTrue,
      );
    });

    test('an equal score is not better', () {
      expect(
        isBetterLexi((points: 94, inner: 5), (points: 94, inner: 5)),
        isFalse,
      );
    });

    test('a lesser score is not better', () {
      expect(
        isBetterLexi((points: 94, inner: 9), (points: 95, inner: 0)),
        isFalse,
      );
    });
  });
}
