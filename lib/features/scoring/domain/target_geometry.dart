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
  });

  /// The ISSF / NSF 10 m air-rifle target (see spec 0001).
  const TargetGeometry.airRifle10m()
    : name = '10 m Air Rifle',
      caliberMm = 4.5,
      ringOuterDiametersMm = _airRifle10mRingDiametersMm,
      blackBullDiameterMm = 30.5;

  /// Human-readable discipline name, e.g. `'10 m Air Rifle'`.
  final String name;

  /// Ammunition caliber in millimetres (e.g. 4.5 for air rifle).
  final double caliberMm;

  /// Outer diameter (mm) of each ring, ordered from ring 1 (outermost) to the
  /// highest ring (innermost). Index `i` holds ring `i + 1`.
  final List<double> ringOuterDiametersMm;

  /// Diameter (mm) of the central aiming black ("blink").
  final double blackBullDiameterMm;

  /// Radius of the pellet/bullet in millimetres.
  double get pelletRadiusMm => caliberMm / 2;

  /// The innermost (highest-value) ring number, e.g. 10 for air rifle.
  int get highestRing => ringOuterDiametersMm.length;

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
