// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the generated composed-hold data (spec 0079): the 8 holds
// carry the expected plates, separators, figures and inner rings.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art_data.dart';

void main() {
  FeltHoldArt art(int number) =>
      norgesfelt2026Art.firstWhere((a) => a.number == number);

  test('has 8 holds numbered 1..8 on white paper (spec 0079)', () {
    expect(norgesfelt2026Art.length, 8);
    expect(
      norgesfelt2026Art.map((a) => a.number).toList(),
      <int>[1, 2, 3, 4, 5, 6, 7, 8],
    );
    for (final a in norgesfelt2026Art) {
      expect(a.paper, const Color(0xFFFFFFFF));
      expect(a.size.width > 0 && a.size.height > 0, isTrue);
    }
  });

  test('hold 1 is a black plate with two figures (spec 0079)', () {
    expect(art(1).plates.length, 1);
    expect(art(1).plates.first.color, const Color(0xFF101010));
    expect(art(1).figures.length, 2);
  });

  test('målgruppe holds carry a black separator (spec 0079)', () {
    for (final n in <int>[2, 3, 6, 8]) {
      expect(art(n).separators, isNotEmpty, reason: 'hold $n');
    }
    for (final n in <int>[1, 4, 5, 7]) {
      expect(art(n).separators, isEmpty, reason: 'hold $n');
    }
  });

  test('holds 3 and 6 draw C-figures as truncated circles (spec 0079)', () {
    for (final n in <int>[3, 6]) {
      expect(
        art(n).figures.any((f) => f.shape == FeltArtShape.tcircle),
        isTrue,
        reason: 'hold $n',
      );
    }
  });

  test('hold 2 knocks three white pins out of its plate (spec 0079)', () {
    final whites = art(2).figures.where(
      (f) => f.fill == const Color(0xFFFFFFFF),
    );
    expect(whites.length, 3);
  });

  test('every inner-treff ring has a positive radius (spec 0079)', () {
    for (final a in norgesfelt2026Art) {
      for (final f in a.figures) {
        final ring = f.ring;
        if (ring != null) {
          expect(ring.r, greaterThan(0), reason: 'hold ${a.number}');
        }
      }
    }
  });

  group('T96 (spec 0160)', () {
    test('16 sheets numbered 1..16, five ringed circles each', () {
      expect(t96Art.length, 16);
      expect(
        t96Art.map((a) => a.number).toList(),
        List<int>.generate(16, (i) => i + 1),
      );
      for (final a in t96Art) {
        expect(a.paper, const Color(0xFFFFFFFF));
        expect(a.plates, isEmpty);
        expect(a.separators, isEmpty);
        expect(a.figures, hasLength(5));
        for (final f in a.figures) {
          expect(f.shape, FeltArtShape.circle);
          expect(f.fill, const Color(0xFF101010));
          expect(f.r, greaterThan(0));
          final ring = f.ring;
          expect(ring, isNotNull);
          expect(ring!.r, greaterThan(0));
          // The ring is concentric with its circle.
          expect(ring.cx, f.cx);
          expect(ring.cy, f.cy);
        }
        // Every serie shows the same sheet — one shared figure list.
        expect(a.figures, same(t96Art.first.figures));
      }
    });

    test('the five circles sit as the die-five with true geometry', () {
      final figures = t96Art.first.figures;
      // Reading order: top-left, top-right, middle, bottom-left,
      // bottom-right — centre spacing 240 mm at ⌀ 110 mm (scale 150/360).
      final centres = figures.map((f) => Offset(f.cx, f.cy)).toList();
      expect(centres, const <Offset>[
        Offset(25, 25),
        Offset(125, 25),
        Offset(75, 75),
        Offset(25, 125),
        Offset(125, 125),
      ]);
      final r = figures.first.r;
      // ⌀110 mm on the 240 mm spacing: r/spacing = 55/240.
      expect(r / 100, closeTo(55 / 240, 0.01));
      // Inner ⌀45 mm: ring r / circle r = 22.5/55.
      expect(figures.first.ring!.r / r, closeTo(22.5 / 55, 0.01));
    });
  });

  group('NorgesFelt Asker+ (spec 0145)', () {
    test('has 10 holds numbered 1..10, sharing 1..8 with 2026', () {
      expect(askerPlusArt.length, 10);
      expect(
        askerPlusArt.map((a) => a.number).toList(),
        List<int>.generate(10, (i) => i + 1),
      );
      for (var i = 0; i < 8; i++) {
        expect(askerPlusArt[i], same(norgesfelt2026Art[i]));
      }
    });

    test('hold 9 is five ringed hexagons of equal area, in two rows '
        '(spec 0149)', () {
      final hold9 = askerPlusArt[8];
      expect(hold9.figures, hasLength(5));
      for (final f in hold9.figures) {
        expect(f.shape, FeltArtShape.polygon);
        expect(f.ring, isNotNull);
      }
      // The lying figures are the standing hexagon rotated, so every
      // figure has the same area (domain-expert feedback)…
      double areaOf(FeltArtFigure f) {
        final pts = f.points;
        var area = 0.0;
        for (var i = 0; i < pts.length; i++) {
          final a = pts[i];
          final b = pts[(i + 1) % pts.length];
          area += a.dx * b.dy - b.dx * a.dy;
        }
        return area.abs() / 2;
      }

      final a0 = areaOf(hold9.figures[0]);
      for (final f in hold9.figures) {
        expect((areaOf(f) - a0).abs() / a0, lessThan(0.02), reason: 'figur');
      }
      // …and the two-row layout keeps the hold picture's proportions
      // close to the other holds' (no wide strip — shots stay placeable).
      expect(hold9.size.width / hold9.size.height, lessThan(2.5));
      // Alternating green-lying and red-standing, G-R-G-R-G (spec 0149).
      expect(hold9.figures[0].fill, const Color(0xFF00683F));
      expect(hold9.figures[1].fill, const Color(0xFFED1C24));
      expect(hold9.figures[4].fill, const Color(0xFF00683F));
    });

    test('hold 10 scores as six figures: hexagon, owl, three stolper, '
        'hexagon (spec 0149)', () {
      final hold10 = askerPlusArt[9];
      // A green hexagon, the owl, nine stolpe squares, a green hexagon.
      expect(hold10.figures, hasLength(12));
      // The leading hexagon and the owl each carry an inner ring…
      expect(hold10.figures[0].ring, isNotNull);
      expect(hold10.figures[0].fill, const Color(0xFF00683F));
      expect(hold10.figures[1].ring, isNotNull);
      // …then the nine stolpe squares group into three score figures
      // anchored at 2/5/8, the middle of each (a lying stolpe) as the
      // inner zone (spec 0086 pattern, rotated 90° — spec 0149).
      for (var i = 0; i < 9; i++) {
        expect(
          hold10.figures[2 + i].scoreIndex,
          2 + (i ~/ 3) * 3,
          reason: 'square $i',
        );
        expect(
          hold10.figures[2 + i].innerZone,
          i % 3 == 1,
          reason: 'square $i',
        );
      }
      // …and a trailing green hexagon with a ring.
      expect(hold10.figures[11].ring, isNotNull);
      expect(hold10.figures[11].fill, const Color(0xFF00683F));
      expect(hold10.innerByScoringFigure, hasLength(6));
    });
  });
}
