// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/presentation/series_painter.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

/// Key for the big, interactive silhouette target (the focused face), used by
/// tests (spec 0067).
const Key silhouetteActiveTargetKey = ValueKey<String>(
  'silhouetteActiveTarget',
);

/// Key for the silhouette thumbnail at [index] in the strip (spec 0067).
Key silhouetteTargetKey(int index) =>
    ValueKey<String>('silhouetteTarget-$index');

/// The recording target for a silhouette-bank series (spec 0067).
///
/// A series is fired one shot at each of the stage's `targetsPerSeries`
/// identical faces, in firing order. The **focused** silhouette is shown big
/// and zoomable — tap to place its shot (or long-press a placed shot to drag),
/// exactly like a normal target. The other silhouettes are a small, scrollable
/// **thumbnail strip**; the next one to shoot is highlighted, and tapping any
/// thumbnail focuses it (to review or fix it). The shots stay one ordered list
/// on one geometry, so scoring and persistence are unchanged.
class SilhouetteSeriesTarget extends ConsumerStatefulWidget {
  /// Creates the silhouette bank target.
  const SilhouetteSeriesTarget({super.key});

  @override
  ConsumerState<SilhouetteSeriesTarget> createState() =>
      _SilhouetteSeriesTargetState();
}

class _SilhouetteSeriesTargetState
    extends ConsumerState<SilhouetteSeriesTarget> {
  static const double _minScale = 1;
  static const double _maxScale = 6;

  final TransformationController _transform = TransformationController();

  /// The silhouette the user has tapped to focus, or `null` to follow the next
  /// one to shoot.
  int? _focused;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recording = ref.watch(sessionProvider);
    final current = recording.current;
    final stage = recording.session.currentStage;
    if (current == null || stage == null) return const SizedBox.shrink();

    final geometry = current.geometry;
    final shots = current.shots;
    final targets = stage.targetsPerSeries;
    final perTarget = stage.shotsPerTarget;
    // The silhouette the next shot lands on, or -1 when the series is full.
    final active = current.isComplete ? -1 : shots.length ~/ perTarget;
    final focused = (_focused ?? (active >= 0 ? active : targets - 1)).clamp(
      0,
      targets - 1,
    );
    final focusedShots = _shotsForTarget(shots, focused, perTarget);
    final baseIndex = focused * perTarget;
    final isActiveFocus = focused == active;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1,
          child: _BigTarget(
            geometry: geometry,
            shots: focusedShots,
            baseIndex: baseIndex,
            draggingIndex: recording.draggingIndex,
            canPlace: isActiveFocus,
            transform: _transform,
            minScale: _minScale,
            maxScale: _maxScale,
          ),
        ),
        const SizedBox(height: 8),
        _ThumbnailStrip(
          geometry: geometry,
          shots: shots,
          targets: targets,
          perTarget: perTarget,
          focused: focused,
          active: active,
          onSelect: (i) => setState(() => _focused = i),
        ),
      ],
    );
  }

  static List<Shot> _shotsForTarget(List<Shot> shots, int i, int perTarget) {
    final start = i * perTarget;
    if (start >= shots.length) return const <Shot>[];
    final end = start + perTarget;
    return shots.sublist(start, end < shots.length ? end : shots.length);
  }
}

/// The big, zoomable target for the focused silhouette (spec 0067) — the same
/// look and gestures as the normal series target.
class _BigTarget extends ConsumerStatefulWidget {
  const _BigTarget({
    required this.geometry,
    required this.shots,
    required this.baseIndex,
    required this.draggingIndex,
    required this.canPlace,
    required this.transform,
    required this.minScale,
    required this.maxScale,
  });

  final TargetGeometry geometry;
  final List<Shot> shots;
  final int baseIndex;
  final int? draggingIndex;
  final bool canPlace;
  final TransformationController transform;
  final double minScale;
  final double maxScale;

  @override
  ConsumerState<_BigTarget> createState() => _BigTargetState();
}

class _BigTargetState extends ConsumerState<_BigTarget> {
  double _scale(double side) => (side / 2) / widget.geometry.maxScoringRadiusMm;

  Shot _toShot(Offset px, double side) {
    final scale = _scale(side);
    return Shot(
      dxMm: (px.dx - side / 2) / scale,
      dyMm: (px.dy - side / 2) / scale,
    );
  }

  void _onTap(Offset px, double side) {
    if (!widget.canPlace) return;
    ref.read(sessionProvider.notifier).placeShot(_toShot(px, side));
  }

  @override
  Widget build(BuildContext context) {
    final hasShot = widget.shots.isNotEmpty;
    final dragging = widget.draggingIndex == widget.baseIndex && hasShot
        ? 0
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              children: <Widget>[
                InteractiveViewer(
                  transformationController: widget.transform,
                  minScale: widget.minScale,
                  maxScale: widget.maxScale,
                  trackpadScrollCausesScale: true,
                  child: GestureDetector(
                    key: silhouetteActiveTargetKey,
                    onTapUp: (d) => _onTap(d.localPosition, side),
                    onLongPressStart: hasShot
                        ? (_) => ref
                              .read(sessionProvider.notifier)
                              .pickUp(widget.baseIndex)
                        : null,
                    onLongPressMoveUpdate: hasShot
                        ? (d) => ref
                              .read(sessionProvider.notifier)
                              .dragTo(_toShot(d.localPosition, side))
                        : null,
                    onLongPressEnd: hasShot
                        ? (_) => ref.read(sessionProvider.notifier).drop()
                        : null,
                    child: CustomPaint(
                      size: Size.square(side),
                      painter: SeriesPainter(
                        geometry: widget.geometry,
                        shots: widget.shots,
                        draggingIndex: dragging,
                        highlightLast: false,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: _ZoomControls(
                    onZoomIn: () => _zoomTo(_currentScale * 1.6, side),
                    onZoomOut: () => _zoomTo(_currentScale / 1.6, side),
                    onReset: () => _zoomTo(1, side),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double get _currentScale => widget.transform.value.getMaxScaleOnAxis();

  void _zoomTo(double target, double side) {
    final clamped = target.clamp(widget.minScale, widget.maxScale);
    final translate = (side / 2) * (1 - clamped);
    widget.transform.value = Matrix4.identity()
      ..setEntry(0, 0, clamped)
      ..setEntry(1, 1, clamped)
      ..setEntry(0, 3, translate)
      ..setEntry(1, 3, translate);
  }
}

/// The horizontal strip of small silhouette thumbnails (spec 0067): the next
/// one to shoot is highlighted, the focused one outlined; tap one to focus it.
class _ThumbnailStrip extends StatelessWidget {
  const _ThumbnailStrip({
    required this.geometry,
    required this.shots,
    required this.targets,
    required this.perTarget,
    required this.focused,
    required this.active,
    required this.onSelect,
  });

  final TargetGeometry geometry;
  final List<Shot> shots;
  final int targets;
  final int perTarget;
  final int focused;
  final int active;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const size = 64.0;
    return SizedBox(
      height: size + 20,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: targets,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final start = i * perTarget;
          final end = start + perTarget;
          final theseShots = start >= shots.length
              ? const <Shot>[]
              : shots.sublist(start, end < shots.length ? end : shots.length);
          final isActive = i == active;
          final isFocused = i == focused;
          return GestureDetector(
            key: silhouetteTargetKey(i),
            onTap: () => onSelect(i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isActive
                          ? theme.colorScheme.primary
                          : isFocused
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.outlineVariant,
                      width: (isActive || isFocused) ? 2.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: CustomPaint(
                    size: const Size.square(size),
                    painter: SeriesPainter(
                      geometry: geometry,
                      shots: theseShots,
                      draggingIndex: null,
                      highlightLast: false,
                    ),
                  ),
                ),
                Text(
                  '${i + 1}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? theme.colorScheme.primary : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The ＋ / − / reset zoom buttons overlaid on the focused target.
class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: const StadiumBorder(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            key: const ValueKey<String>('silhouetteZoomIn'),
            icon: const Icon(Icons.add),
            tooltip: 'Zoom inn',
            onPressed: onZoomIn,
          ),
          IconButton(
            key: const ValueKey<String>('silhouetteZoomReset'),
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Nullstill zoom',
            onPressed: onReset,
          ),
          IconButton(
            key: const ValueKey<String>('silhouetteZoomOut'),
            icon: const Icon(Icons.remove),
            tooltip: 'Zoom ut',
            onPressed: onZoomOut,
          ),
        ],
      ),
    );
  }
}
