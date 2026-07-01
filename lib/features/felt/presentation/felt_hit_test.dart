// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:ui';

import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art_painter.dart';

/// Resolves a point [p] (hold pixel space) to a [FeltShot] (spec 0080): the
/// topmost figure whose outline contains [p], with `inner` true when [p] is
/// within that figure's inner-zone ring. A point on no figure is a miss.
FeltShot feltHitTest(FeltHoldArt art, Offset p) {
  for (var i = art.figures.length - 1; i >= 0; i--) {
    final figure = art.figures[i];
    if (feltArtFigurePath(figure).contains(p)) {
      final ring = figure.ring;
      final inner =
          ring != null && (p - Offset(ring.cx, ring.cy)).distance <= ring.r;
      return FeltShot(figureIndex: i, inner: inner);
    }
  }
  return const FeltShot();
}
