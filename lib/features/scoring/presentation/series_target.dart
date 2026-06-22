// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/presentation/series_painter.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

/// Key for the tappable target area, used by widget and system tests.
const Key seriesTargetKey = ValueKey<String>('seriesTarget');

/// Interactive target for the session's current series: tap to place a shot,
/// long-press a placed shot to pick it up and drag it, and zoom in for
/// precise placement.
///
/// Zoom works with the on-target ＋ / − buttons (mouse / any device), a pinch on
/// a touch screen, or a two-finger scroll on a trackpad. Pointer coordinates
/// reach the canvas already mapped back into its own space, so scoring is
/// unaffected by the zoom.
class SeriesTarget extends ConsumerStatefulWidget {
  /// Creates the series target.
  const SeriesTarget({super.key});

  @override
  ConsumerState<SeriesTarget> createState() => _SeriesTargetState();
}

class _SeriesTargetState extends ConsumerState<SeriesTarget> {
  /// How close (mm) a long-press must be to a marker to pick it up.
  static const double _pickUpRadiusMm = 6;
  static const double _minScale = 1;
  static const double _maxScale = 6;

  final TransformationController _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recording = ref.watch(sessionProvider);
    final current = recording.current;
    if (current == null) return const SizedBox.shrink();
    final geometry = current.geometry;
    final shots = current.shots;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              children: [
                InteractiveViewer(
                  transformationController: _transform,
                  minScale: _minScale,
                  maxScale: _maxScale,
                  trackpadScrollCausesScale: true,
                  child: GestureDetector(
                    key: seriesTargetKey,
                    onTapUp: (details) =>
                        _place(geometry, details.localPosition, side),
                    onLongPressStart: (details) => _tryPickUp(
                      geometry,
                      shots,
                      details.localPosition,
                      side,
                    ),
                    onLongPressMoveUpdate: (details) =>
                        _drag(geometry, details.localPosition, side),
                    onLongPressEnd: (_) =>
                        ref.read(sessionProvider.notifier).drop(),
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

  double get _currentScale => _transform.value.getMaxScaleOnAxis();

  /// Sets a centred zoom level, clamped to [_minScale]..[_maxScale].
  ///
  /// Scaling by `s` about the centre `c` gives `x' = s·x + c·(1 - s)`, built
  /// directly to avoid the deprecated `Matrix4.translate` / `scale`.
  void _zoomTo(double target, double side) {
    final clamped = target.clamp(_minScale, _maxScale);
    final translate = (side / 2) * (1 - clamped);
    _transform.value = Matrix4.identity()
      ..setEntry(0, 0, clamped)
      ..setEntry(1, 1, clamped)
      ..setEntry(0, 3, translate)
      ..setEntry(1, 3, translate);
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

  void _place(TargetGeometry geometry, Offset px, double side) =>
      ref.read(sessionProvider.notifier).placeShot(_toShot(geometry, px, side));

  void _tryPickUp(
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
      ref.read(sessionProvider.notifier).pickUp(nearest);
    }
  }

  void _drag(TargetGeometry geometry, Offset px, double side) {
    if (!ref.read(sessionProvider).isDragging) return;
    ref.read(sessionProvider.notifier).dragTo(_toShot(geometry, px, side));
  }
}

/// The ＋ / − / reset zoom buttons overlaid on the target.
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
        children: [
          IconButton(
            key: const ValueKey<String>('zoomIn'),
            icon: const Icon(Icons.add),
            tooltip: 'Zoom in',
            onPressed: onZoomIn,
          ),
          IconButton(
            key: const ValueKey<String>('zoomReset'),
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Reset zoom',
            onPressed: onReset,
          ),
          IconButton(
            key: const ValueKey<String>('zoomOut'),
            icon: const Icon(Icons.remove),
            tooltip: 'Zoom out',
            onPressed: onZoomOut,
          ),
        ],
      ),
    );
  }
}
