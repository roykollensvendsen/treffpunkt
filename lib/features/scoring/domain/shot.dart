// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;

/// A single recorded shot, as an offset from the target centre in millimetres.
class Shot {
  /// Creates a shot at the given offset (mm) from the target centre.
  const Shot({required this.dxMm, required this.dyMm});

  /// Horizontal offset from the centre in millimetres.
  final double dxMm;

  /// Vertical offset from the centre in millimetres.
  final double dyMm;

  /// Straight-line distance from the target centre in millimetres.
  double get distanceMm => math.sqrt(dxMm * dxMm + dyMm * dyMm);
}
