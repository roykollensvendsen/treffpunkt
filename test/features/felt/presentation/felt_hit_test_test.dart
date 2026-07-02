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

  test('a grouped stripe scores as one figure, middle square inner (0086)', () {
    // A three-square stripe: parts 1–3 all score as figure 1, and the middle
    // square (part 2) is the inner zone — no ring involved.
    const stripe = FeltHoldArt(
      number: 98,
      size: Size(100, 40),
      paper: Color(0xFFFFFFFF),
      plates: <FeltArtPlate>[],
      figures: <FeltArtFigure>[
        FeltArtFigure(
          shape: FeltArtShape.circle,
          cx: 90,
          cy: 30,
          r: 5,
          fill: Color(0xFF101010),
        ),
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
            Offset(27, 5),
            Offset(47, 5),
            Offset(47, 25),
            Offset(27, 25),
          ],
          fill: Color(0xFF101010),
          scoreIndex: 1,
          innerZone: true,
        ),
        FeltArtFigure(
          shape: FeltArtShape.polygon,
          points: <Offset>[
            Offset(49, 5),
            Offset(69, 5),
            Offset(69, 25),
            Offset(49, 25),
          ],
          fill: Color(0xFF101010),
          scoreIndex: 1,
        ),
      ],
      separators: <FeltArtSeparator>[],
    );

    // Outer squares: hits on the stripe (figure 1), not inner.
    final left = feltHitTest(stripe, const Offset(15, 15));
    expect(left.figureIndex, 1);
    expect(left.inner, isFalse);
    final right = feltHitTest(stripe, const Offset(59, 15));
    expect(right.figureIndex, 1);
    expect(right.inner, isFalse);

    // The middle square: same figure, and an innertreff (spec 0085 tiebreak).
    final middle = feltHitTest(stripe, const Offset(37, 15));
    expect(middle.figureIndex, 1);
    expect(middle.inner, isTrue);

    // Two squares of the same stripe count one distinct figure.
    expect(
      <int?>{left.figureIndex, middle.figureIndex, right.figureIndex}.length,
      1,
    );
  });

  test('a hit on a stripe divider line counts as a hit, not inner (0087)', () {
    FeltHoldArt art(int n) =>
        norgesfelt2026Art.firstWhere((a) => a.number == n);

    // Hold 2's top stripe: squares at x 3–39 / 40–75 / 76–111, y 3–38. The
    // 1-px white dividers (x ≈ 39.5 and 75.5) are part of the figure.
    for (final x in <double>[39.5, 75.5]) {
      final shot = feltHitTest(art(2), Offset(x, 20));
      expect(shot.figureIndex, 4, reason: 'divider at x=$x');
      expect(shot.inner, isFalse, reason: 'divider at x=$x');
    }

    // Hold 8's Stor stripe is a column (y 3–53 / 55–104 / 106–155): the
    // horizontal divider at y ≈ 54 hits the stripe.
    final vertical = feltHitTest(art(8), const Offset(128, 54));
    expect(vertical.figureIndex, 2);
    expect(vertical.inner, isFalse);

    // Just outside the stripe outline is still a miss.
    expect(feltHitTest(art(2), const Offset(2, 20)).isHit, isFalse);
    expect(feltHitTest(art(2), const Offset(112, 20)).isHit, isFalse);
  });

  test('hold 2 and hold 8 stripes group with a middle inner square (0086)', () {
    FeltHoldArt art(int n) =>
        norgesfelt2026Art.firstWhere((a) => a.number == n);

    // A hit dead-centre of each square, computed from the polygon itself.
    Offset centreOf(FeltArtFigure f) {
      var x = 0.0;
      var y = 0.0;
      for (final p in f.points) {
        x += p.dx;
        y += p.dy;
      }
      return Offset(x / f.points.length, y / f.points.length);
    }

    // Hold 2: squares 4–6 and 7–9 are the two stripes (anchors 4 and 7,
    // middles 5 and 8). Hold 8: 2–4, 5–7, 8–10, 11–13 (anchors 2, 5, 8, 11,
    // middles 3, 6, 9, 12).
    final expected = <int, Map<int, int>>{
      2: <int, int>{4: 4, 5: 4, 6: 4, 7: 7, 8: 7, 9: 7},
      8: <int, int>{
        2: 2,
        3: 2,
        4: 2,
        5: 5,
        6: 5,
        7: 5,
        8: 8,
        9: 8,
        10: 8,
        11: 11,
        12: 11,
        13: 11,
      },
    };
    final inners = <int, Set<int>>{
      2: <int>{5, 8},
      8: <int>{3, 6, 9, 12},
    };

    for (final holdNumber in expected.keys) {
      final hold = art(holdNumber);
      for (final entry in expected[holdNumber]!.entries) {
        final shot = feltHitTest(hold, centreOf(hold.figures[entry.key]));
        expect(
          shot.figureIndex,
          entry.value,
          reason: 'hold $holdNumber square ${entry.key}',
        );
        expect(
          shot.inner,
          inners[holdNumber]!.contains(entry.key),
          reason: 'hold $holdNumber square ${entry.key}',
        );
      }
      // Grouped, the hold offers exactly the course's six figures.
      final scoreTargets = <int>{
        for (var i = 0; i < hold.figures.length; i++)
          hold.figures[i].scoreIndex ?? i,
      };
      expect(scoreTargets.length, 6, reason: 'hold $holdNumber');
    }
  });
}
