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

/// Interactive target: tap to place a shot and see its live decimal score.
class TargetCanvas extends ConsumerWidget {
  /// Creates a target canvas for [geometry].
  const TargetCanvas({required this.geometry, super.key});

  /// The target to render and score against.
  final TargetGeometry geometry;

  static const ScoringService _scoring = ScoringService();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shot = ref.watch(placedShotProvider);
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
                    onTapDown: (details) =>
                        _placeAt(ref, details.localPosition, side),
                    child: CustomPaint(
                      size: Size.square(side),
                      painter: TargetPainter(geometry: geometry, shot: shot),
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

  void _placeAt(WidgetRef ref, Offset localPx, double side) {
    final scale = (side / 2) / geometry.maxScoringRadiusMm;
    final dxMm = (localPx.dx - side / 2) / scale;
    final dyMm = (localPx.dy - side / 2) / scale;
    ref.read(placedShotProvider.notifier).shot = Shot(dxMm: dxMm, dyMm: dyMm);
  }
}
