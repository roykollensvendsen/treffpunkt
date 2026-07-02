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
///
/// A shape that is one part of a multi-shape figure — the tre-kvadrater
/// stripes on holds 2 and 8 (spec 0086) — scores as its `scoreIndex` figure,
/// and the stripe's middle square (`innerZone`) is an innertreff.
FeltShot feltHitTest(FeltHoldArt art, Offset p) {
  for (var i = art.figures.length - 1; i >= 0; i--) {
    final figure = art.figures[i];
    if (feltArtFigurePath(figure).contains(p)) {
      final ring = figure.ring;
      final inner =
          figure.innerZone ||
          (ring != null && (p - Offset(ring.cx, ring.cy)).distance <= ring.r);
      return FeltShot(figureIndex: figure.scoreIndex ?? i, inner: inner);
    }
  }

  // A shot on the white divider between a grouped figure's squares (spec
  // 0087): the dividers lie inside the group's bounding box, which is the
  // stripe's true outline, so a boxed point that no shape claimed is a hit
  // on the stripe — never an innertreff (only the middle square is).
  final groupBounds = <int, Rect>{};
  for (var i = 0; i < art.figures.length; i++) {
    final figure = art.figures[i];
    final anchor = figure.scoreIndex;
    if (anchor == null) continue;
    final bounds = feltArtFigurePath(figure).getBounds();
    final grown = groupBounds[anchor];
    groupBounds[anchor] = grown == null
        ? bounds
        : grown.expandToInclude(bounds);
  }
  for (final group in groupBounds.entries) {
    if (group.value.contains(p)) return FeltShot(figureIndex: group.key);
  }
  return const FeltShot();
}
