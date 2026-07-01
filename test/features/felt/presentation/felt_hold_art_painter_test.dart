// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the composed-hold painter (spec 0079).
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art_data.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art_painter.dart';

void main() {
  test('paints every hold without throwing (spec 0079)', () {
    for (final art in norgesfelt2026Art) {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      FeltHoldArtPainter(art).paint(canvas, const Size(300, 300));
      recorder.endRecording();
    }
  });

  test('repaints only when the hold changes (spec 0079)', () {
    final a = FeltHoldArtPainter(norgesfelt2026Art[0]);
    expect(a.shouldRepaint(FeltHoldArtPainter(norgesfelt2026Art[0])), isFalse);
    expect(a.shouldRepaint(FeltHoldArtPainter(norgesfelt2026Art[1])), isTrue);
  });

  test('a truncated circle is cut flat above a full circle (spec 0079)', () {
    const full = FeltArtFigure(
      shape: FeltArtShape.circle,
      cx: 50,
      cy: 50,
      r: 40,
      fill: Color(0xFF101010),
    );
    const cut = FeltArtFigure(
      shape: FeltArtShape.tcircle,
      cx: 50,
      cy: 50,
      r: 40,
      bottomY: 78,
      fill: Color(0xFF101010),
    );
    final fullBottom = feltArtFigurePath(full).getBounds().bottom;
    final cutBottom = feltArtFigurePath(cut).getBounds().bottom;
    expect(cutBottom, lessThan(fullBottom));
    expect(cutBottom, closeTo(78, 1));
  });
}
