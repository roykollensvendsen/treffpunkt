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

    test('hold 9 is six ringed hexagons', () {
      final hold9 = askerPlusArt[8];
      expect(hold9.figures, hasLength(6));
      for (final f in hold9.figures) {
        expect(f.shape, FeltArtShape.polygon);
        expect(f.ring, isNotNull);
      }
      // Alternating green and red (spec 0145).
      expect(hold9.figures[0].fill, const Color(0xFF00683F));
      expect(hold9.figures[1].fill, const Color(0xFFED1C24));
    });

    test('hold 10 scores as five figures: three stolper, oval, owl', () {
      final hold10 = askerPlusArt[9];
      expect(hold10.figures, hasLength(11));
      // The nine stolpe squares group into three score figures anchored at
      // 0/3/6, middles as inner zones (spec 0086 pattern).
      for (var i = 0; i < 9; i++) {
        expect(hold10.figures[i].scoreIndex, (i ~/ 3) * 3, reason: 'square $i');
        expect(hold10.figures[i].innerZone, i % 3 == 1, reason: 'square $i');
      }
      // The oval and the owl each carry an inner ring.
      expect(hold10.figures[9].ring, isNotNull);
      expect(hold10.figures[10].ring, isNotNull);
      expect(hold10.innerByScoringFigure, hasLength(5));
    });
  });
}
