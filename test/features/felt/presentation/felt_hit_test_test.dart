// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for resolving a placed point to a figure/inner hit (spec 0080).
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hit_test.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art_data.dart';

// A hold with two square figures; figure 1 has an inner-zone ring at its
// centre.
const _art = FeltHoldArt(
  number: 99,
  size: Size(100, 100),
  paper: Color(0xFFFFFFFF),
  plates: <FeltArtPlate>[],
  figures: <FeltArtFigure>[
    FeltArtFigure(
      shape: FeltArtShape.polygon,
      points: <Offset>[
        Offset(5, 5),
        Offset(25, 5),
        Offset(25, 25),
        Offset(5, 25),
      ],
      fill: Color(0xFF101010),
    ),
    FeltArtFigure(
      shape: FeltArtShape.polygon,
      points: <Offset>[
        Offset(50, 50),
        Offset(90, 50),
        Offset(90, 90),
        Offset(50, 90),
      ],
      fill: Color(0xFF101010),
      ring: FeltArtRing(
        cx: 70,
        cy: 70,
        r: 8,
        strokeWidth: 1.5,
        color: Color(0xFFFFFFFF),
      ),
    ),
  ],
  separators: <FeltArtSeparator>[],
);

void main() {
  test('a point on a figure returns that figure, off it is a miss (0080)', () {
    expect(feltHitTest(_art, const Offset(15, 15)).figureIndex, 0);
    expect(feltHitTest(_art, const Offset(70, 70)).figureIndex, 1);
    final miss = feltHitTest(_art, const Offset(40, 40));
    expect(miss.figureIndex, isNull);
    expect(miss.isHit, isFalse);
  });

  test('inner is true only within the ring (spec 0080)', () {
    expect(feltHitTest(_art, const Offset(70, 70)).inner, isTrue);
    // Inside figure 1 but well outside its 8-px ring.
    expect(feltHitTest(_art, const Offset(55, 88)).inner, isFalse);
    // Figure 0 has no ring, so a hit there is never inner.
    expect(feltHitTest(_art, const Offset(15, 15)).inner, isFalse);
  });

  test('a white knockout resolves to that figure (spec 0080)', () {
    // Hold 1: the hare is a white knockout with a ring — its centre hits it.
    final hold1 = norgesfelt2026Art.firstWhere((a) => a.number == 1);
    final hare = hold1.figures.firstWhere((f) => f.ring != null);
    final shot = feltHitTest(hold1, Offset(hare.ring!.cx, hare.ring!.cy));
    expect(shot.isHit, isTrue);
    expect(shot.inner, isTrue);
  });
}
