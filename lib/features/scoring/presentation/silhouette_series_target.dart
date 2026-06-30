// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/presentation/series_painter.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

/// Key for the silhouette mini-target at [index] (spec 0067), used by tests.
Key silhouetteTargetKey(int index) =>
    ValueKey<String>('silhouetteTarget-$index');

/// The recording target for a silhouette-bank series (spec 0067).
///
/// A series is fired one shot at each of the stage's `targetsPerSeries`
/// identical faces, in firing order. The
/// **active** (next) mini-target is highlighted — tap it to place its shot;
/// long-press a placed shot to drag it. The shots are still a single ordered
/// list on one geometry, so scoring and persistence are unchanged.
class SilhouetteSeriesTarget extends ConsumerWidget {
  /// Creates the silhouette bank target.
  const SilhouetteSeriesTarget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recording = ref.watch(sessionProvider);
    final current = recording.current;
    final stage = recording.session.currentStage;
    if (current == null || stage == null) return const SizedBox.shrink();

    final geometry = current.geometry;
    final shots = current.shots;
    final targets = stage.targetsPerSeries;
    final perTarget = stage.shotsPerTarget;
    // The target the next shot goes to, or -1 when the series is full.
    final activeTarget = current.isComplete ? -1 : shots.length ~/ perTarget;
    final notifier = ref.read(sessionProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        // Aim for a comfortably large, tappable target: fit as many columns as
        // hold at least [minTile] px, wrapping the rest onto more rows rather
        // than squeezing all targets onto one row (spec 0067).
        const minTile = 160.0;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        final columns = ((width + spacing) ~/ (minTile + spacing)).clamp(
          1,
          targets,
        );
        final tile = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          alignment: WrapAlignment.center,
          children: <Widget>[
            for (var i = 0; i < targets; i++)
              _MiniTarget(
                key: silhouetteTargetKey(i),
                geometry: geometry,
                shots: _shotsForTarget(shots, i, perTarget),
                active: i == activeTarget,
                size: tile,
                onPlace: i == activeTarget ? notifier.placeShot : null,
                onPickUp: () => notifier.pickUp(i * perTarget),
                onDrag: notifier.dragTo,
                onDrop: notifier.drop,
              ),
          ],
        );
      },
    );
  }

  static List<Shot> _shotsForTarget(List<Shot> shots, int i, int perTarget) {
    final start = i * perTarget;
    if (start >= shots.length) return const <Shot>[];
    return shots.sublist(start, math.min(start + perTarget, shots.length));
  }
}

class _MiniTarget extends StatelessWidget {
  const _MiniTarget({
    required this.geometry,
    required this.shots,
    required this.active,
    required this.size,
    required this.onPlace,
    required this.onPickUp,
    required this.onDrag,
    required this.onDrop,
    super.key,
  });

  final TargetGeometry geometry;
  final List<Shot> shots;
  final bool active;
  final double size;
  final void Function(Shot)? onPlace;
  final VoidCallback onPickUp;
  final void Function(Shot) onDrag;
  final VoidCallback onDrop;

  double get _scale => (size / 2) / geometry.maxScoringRadiusMm;

  Shot _toShot(Offset localPx) => Shot(
    dxMm: (localPx.dx - size / 2) / _scale,
    dyMm: (localPx.dy - size / 2) / _scale,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasShot = shots.isNotEmpty;
    final place = onPlace;
    return GestureDetector(
      onTapUp: place == null ? null : (d) => place(_toShot(d.localPosition)),
      onLongPressStart: hasShot ? (_) => onPickUp() : null,
      onLongPressMoveUpdate: hasShot
          ? (d) => onDrag(_toShot(d.localPosition))
          : null,
      onLongPressEnd: hasShot ? (_) => onDrop() : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: active ? 2.5 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: CustomPaint(
          size: Size.square(size),
          painter: SeriesPainter(
            geometry: geometry,
            shots: shots,
            draggingIndex: null,
            highlightLast: false,
          ),
        ),
      ),
    );
  }
}
