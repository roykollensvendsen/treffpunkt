// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/presentation/scoring_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/target_painter.dart';

/// Key for the tappable target area, used by widget and system tests.
const Key targetGestureKey = ValueKey<String>('targetGesture');

/// Interactive target: tap to place a shot, long-press it to drag, see the live
/// decimal score.
class TargetCanvas extends ConsumerWidget {
  /// Creates a target canvas for [geometry].
  const TargetCanvas({required this.geometry, super.key});

  /// The target to render and score against.
  final TargetGeometry geometry;

  static const ScoringService _scoring = ScoringService();

  /// How close (mm) a long-press must be to the marker to pick it up.
  static const double _pickUpRadiusMm = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placement = ref.watch(shotPlacementProvider);
    final shot = placement.shot;
    final score = shot == null ? null : _scoring.decimalScore(geometry, shot);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            score == null ? 'Tap the target' : score.toStringAsFixed(1),
            style: Theme.of(context).textTheme.displaySmall,
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.biggest.shortestSide;
              return Center(
                child: SizedBox(
                  width: side,
                  height: side,
                  child: GestureDetector(
                    key: targetGestureKey,
                    onTapUp: (details) =>
                        _place(ref, details.localPosition, side),
                    onLongPressStart: (details) =>
                        _tryPickUp(ref, details.localPosition, side),
                    onLongPressMoveUpdate: (details) =>
                        _drag(ref, details.localPosition, side),
                    onLongPressEnd: (_) => _drop(ref),
                    child: CustomPaint(
                      size: Size.square(side),
                      painter: TargetPainter(
                        geometry: geometry,
                        shot: shot,
                        isDragging: placement.isDragging,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  double _scale(double side) => (side / 2) / geometry.maxScoringRadiusMm;

  Shot _toShot(Offset localPx, double side) {
    final scale = _scale(side);
    return Shot(
      dxMm: (localPx.dx - side / 2) / scale,
      dyMm: (localPx.dy - side / 2) / scale,
    );
  }

  void _place(WidgetRef ref, Offset localPx, double side) =>
      ref.read(shotPlacementProvider.notifier).place(_toShot(localPx, side));

  void _tryPickUp(WidgetRef ref, Offset localPx, double side) {
    final shot = ref.read(shotPlacementProvider).shot;
    if (shot == null) return;
    final scale = _scale(side);
    final markerPx = Offset(
      side / 2 + shot.dxMm * scale,
      side / 2 + shot.dyMm * scale,
    );
    if ((localPx - markerPx).distance <= _pickUpRadiusMm * scale) {
      ref.read(shotPlacementProvider.notifier).pickUp(_toShot(localPx, side));
    }
  }

  void _drag(WidgetRef ref, Offset localPx, double side) {
    if (!ref.read(shotPlacementProvider).isDragging) return;
    ref.read(shotPlacementProvider.notifier).dragTo(_toShot(localPx, side));
  }

  void _drop(WidgetRef ref) => ref.read(shotPlacementProvider.notifier).drop();
}
