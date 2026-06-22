// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/presentation/series_painter.dart';
import 'package:treffpunkt/features/scoring/presentation/series_providers.dart';

/// Key for the tappable target area, used by widget and system tests.
const Key seriesTargetKey = ValueKey<String>('seriesTarget');

/// Interactive target for a series: tap to place the next shot, long-press a
/// placed shot to pick it up and drag it.
class SeriesTarget extends ConsumerWidget {
  /// Creates the series target.
  const SeriesTarget({super.key});

  /// How close (mm) a long-press must be to a marker to pick it up.
  static const double _pickUpRadiusMm = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recording = ref.watch(seriesProvider);
    final geometry = recording.series.geometry;
    final shots = recording.series.shots;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: GestureDetector(
              key: seriesTargetKey,
              onTapUp: (details) =>
                  _place(ref, geometry, details.localPosition, side),
              onLongPressStart: (details) =>
                  _tryPickUp(ref, geometry, shots, details.localPosition, side),
              onLongPressMoveUpdate: (details) =>
                  _drag(ref, geometry, details.localPosition, side),
              onLongPressEnd: (_) => ref.read(seriesProvider.notifier).drop(),
              child: CustomPaint(
                size: Size.square(side),
                painter: SeriesPainter(
                  geometry: geometry,
                  shots: shots,
                  draggingIndex: recording.draggingIndex,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _scale(TargetGeometry geometry, double side) =>
      (side / 2) / geometry.maxScoringRadiusMm;

  Shot _toShot(TargetGeometry geometry, Offset localPx, double side) {
    final scale = _scale(geometry, side);
    return Shot(
      dxMm: (localPx.dx - side / 2) / scale,
      dyMm: (localPx.dy - side / 2) / scale,
    );
  }

  void _place(WidgetRef ref, TargetGeometry geometry, Offset px, double side) =>
      ref.read(seriesProvider.notifier).placeShot(_toShot(geometry, px, side));

  void _tryPickUp(
    WidgetRef ref,
    TargetGeometry geometry,
    List<Shot> shots,
    Offset px,
    double side,
  ) {
    final scale = _scale(geometry, side);
    var nearest = -1;
    var nearestPx = double.infinity;
    for (var i = 0; i < shots.length; i++) {
      final markerPx = Offset(
        side / 2 + shots[i].dxMm * scale,
        side / 2 + shots[i].dyMm * scale,
      );
      final distance = (px - markerPx).distance;
      if (distance < nearestPx) {
        nearestPx = distance;
        nearest = i;
      }
    }
    if (nearest >= 0 && nearestPx <= _pickUpRadiusMm * scale) {
      // Only pick the shot up; it stays put until the first drag update, so a
      // long-press near (not on) a marker does not teleport it to the press.
      ref.read(seriesProvider.notifier).pickUp(nearest);
    }
  }

  void _drag(WidgetRef ref, TargetGeometry geometry, Offset px, double side) {
    if (!ref.read(seriesProvider).isDragging) return;
    ref.read(seriesProvider.notifier).dragTo(_toShot(geometry, px, side));
  }
}
