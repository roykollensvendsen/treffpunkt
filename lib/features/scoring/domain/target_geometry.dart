// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Geometry of a shooting target for one discipline.
//
// All measurements are in millimetres with the target centre at the origin.

/// The ring layout, aiming black and ammunition of a shooting target.
class TargetGeometry {
  /// Creates a target geometry.
  const TargetGeometry({
    required this.name,
    required this.caliberMm,
    required this.ringOuterDiametersMm,
    required this.blackBullDiameterMm,
    this.innerTenDiameterMm,
  });

  /// The ISSF / NSF 10 m air-rifle target (see spec 0001).
  const TargetGeometry.airRifle10m()
    : name = '10 m Air Rifle',
      caliberMm = 4.5,
      ringOuterDiametersMm = _airRifle10mRingDiametersMm,
      blackBullDiameterMm = 30.5,
      innerTenDiameterMm = null;

  /// Human-readable discipline name, e.g. `'10 m Air Rifle'`.
  final String name;

  /// Ammunition caliber in millimetres (e.g. 4.5 for air rifle).
  final double caliberMm;

  /// Outer diameter (mm) of each ring, ordered from ring 1 (outermost) to the
  /// highest ring (innermost). Index `i` holds ring `i + 1`.
  final List<double> ringOuterDiametersMm;

  /// Diameter (mm) of the central aiming black ("blink").
  final double blackBullDiameterMm;

  /// Diameter (mm) of the inner-ten ("X") ring used as a leaderboard tie-break,
  /// or `null` when the discipline does not record an inner ten. The 10 m air
  /// rifle target here does not (its tie-break is the decimal score); pistol
  /// targets do (spec 0005).
  final double? innerTenDiameterMm;

  /// Radius of the pellet/bullet in millimetres.
  double get pelletRadiusMm => caliberMm / 2;

  /// Whether this target records an inner ten ("X").
  bool get hasInnerTen => innerTenDiameterMm != null;

  /// Centre-distance (mm) within which a shot's centre counts as an inner ten,
  /// or `null` when [hasInnerTen] is false. Uses the same gauge "next ring
  /// outward" rule as [scoringRadiusMm].
  double? get innerTenScoringRadiusMm {
    final diameter = innerTenDiameterMm;
    return diameter == null ? null : diameter / 2 + pelletRadiusMm;
  }

  /// The innermost (highest-value) ring number, e.g. 10 for air rifle.
  int get highestRing => ringOuterDiametersMm.length;

  /// Whether the rings are evenly spaced (a constant diameter step), which the
  /// decimal scoring model assumes (spec 0001). True for 10 m air rifle.
  bool get hasUniformRings {
    if (ringOuterDiametersMm.length < 2) return true;
    final step = ringOuterDiametersMm[0] - ringOuterDiametersMm[1];
    for (var i = 1; i < ringOuterDiametersMm.length - 1; i++) {
      final gap = ringOuterDiametersMm[i] - ringOuterDiametersMm[i + 1];
      if ((gap - step).abs() > 1e-9) return false;
    }
    return true;
  }

  /// Outer diameter (mm) of [ring], where ring 1 is the outermost.
  double outerDiameterMm(int ring) {
    assert(
      ring >= 1 && ring <= highestRing,
      'ring must be between 1 and $highestRing',
    );
    return ringOuterDiametersMm[ring - 1];
  }

  /// Centre-distance (mm) within which a shot's centre scores at least [ring].
  ///
  /// Applies the gauge "next ring outward" rule: outer radius + pellet radius.
  double scoringRadiusMm(int ring) =>
      outerDiameterMm(ring) / 2 + pelletRadiusMm;

  /// Largest centre-distance (mm) that still scores; beyond this is a miss.
  double get maxScoringRadiusMm => scoringRadiusMm(1);
}

const List<double> _airRifle10mRingDiametersMm = <double>[
  45.5, // ring 1 (outermost)
  40.5, // ring 2
  35.5, // ring 3
  30.5, // ring 4
  25.5, // ring 5
  20.5, // ring 6
  15.5, // ring 7
  10.5, // ring 8
  5.5, // ring 9
  0.5, // ring 10 (innermost)
];
