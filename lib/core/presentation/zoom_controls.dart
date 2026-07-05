// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Key for the zoom-in button, used by tests.
const Key zoomInKey = ValueKey<String>('zoomIn');

/// Key for the zoom-reset button, used by tests.
const Key zoomResetKey = ValueKey<String>('zoomReset');

/// Key for the zoom-out button, used by tests.
const Key zoomOutKey = ValueKey<String>('zoomOut');

/// Whether the on-target zoom buttons are shown (spec 0141): desktop only.
/// Touch screens pinch — and on a phone the button stack covered the face.
bool get zoomControlsVisible => switch (defaultTargetPlatform) {
  TargetPlatform.android || TargetPlatform.iOS => false,
  _ => true,
};

/// The ＋ / − / reset zoom buttons overlaid on a zoomable target — shared by
/// the ring target and the felt hold pictures (spec 0125) so the two cannot
/// drift apart. Hidden on touch platforms (spec 0141).
class ZoomControls extends StatelessWidget {
  /// Creates the control stack.
  const ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    super.key,
  });

  /// Zooms one step in.
  final VoidCallback onZoomIn;

  /// Zooms one step out.
  final VoidCallback onZoomOut;

  /// Resets to the unzoomed view.
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    if (!zoomControlsVisible) return const SizedBox.shrink();
    return Card(
      elevation: 2,
      shape: const StadiumBorder(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: zoomInKey,
            icon: const Icon(Icons.add),
            tooltip: 'Zoom inn',
            onPressed: onZoomIn,
          ),
          IconButton(
            key: zoomResetKey,
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Nullstill zoom',
            onPressed: onReset,
          ),
          IconButton(
            key: zoomOutKey,
            icon: const Icon(Icons.remove),
            tooltip: 'Zoom ut',
            onPressed: onZoomOut,
          ),
        ],
      ),
    );
  }
}
