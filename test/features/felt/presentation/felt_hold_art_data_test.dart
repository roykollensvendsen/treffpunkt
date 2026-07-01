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
}
