// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;

/// A single recorded shot, as an offset from the target centre in millimetres.
class Shot {
  /// Creates a shot at the given offset (mm) from the target centre,
  /// optionally carrying a manually picked decimal [tenth] (spec 0107).
  const Shot({required this.dxMm, required this.dyMm, this.tenth})
    : assert(
        tenth == null || (tenth >= 0 && tenth <= 9),
        'tenth must be 0–9',
      );

  /// Horizontal offset from the centre in millimetres.
  final double dxMm;

  /// Vertical offset from the centre in millimetres.
  final double dyMm;

  /// The manually picked decimal tenth (0–9) *within the plotted ring* —
  /// the Megalink reading (spec 0107) — or null to derive the tenth from
  /// the position.
  final int? tenth;

  /// Straight-line distance from the target centre in millimetres.
  double get distanceMm => math.sqrt(dxMm * dxMm + dyMm * dyMm);
}
