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
    this.lowestRingValue = 1,
  });

  /// The ISSF / NSF 10 m air-rifle target (see spec 0001).
  const TargetGeometry.airRifle10m()
    : name = '10 m Air Rifle',
      caliberMm = 4.5,
      ringOuterDiametersMm = _airRifle10mRingDiametersMm,
      blackBullDiameterMm = 30.5,
      innerTenDiameterMm = null,
      lowestRingValue = 1;

  /// The ISSF 50 m rifle target (rings 1–10, inner ten 5 mm); see spec 0017 and
  /// `docs/reference/program-catalogue.md`. Calibre is .22 LR (5.6 mm). The
  /// rings step a uniform 16 mm in diameter, from the 10-ring (10.4 mm) out to
  /// ring 1 (154.4 mm).
  const TargetGeometry.smallbore50m()
    : name = '50 m Rifle',
      caliberMm = 5.6,
      ringOuterDiametersMm = _smallbore50mRingDiametersMm,
      blackBullDiameterMm = 112.4,
      innerTenDiameterMm = 5,
      lowestRingValue = 1;

  /// The ISSF 25 m pistol precision target (rings 1–10, inner ten 25 mm); see
  /// `docs/reference/program-catalogue.md`. Calibre defaults to .22 (5.6 mm).
  const TargetGeometry.pistol25mPrecision({double caliber = 5.6})
    : name = '25 m Pistol — Precision',
      caliberMm = caliber,
      ringOuterDiametersMm = _pistol25mPrecisionRingDiametersMm,
      blackBullDiameterMm = 200,
      innerTenDiameterMm = 25,
      lowestRingValue = 1;

  /// The ISSF 10 m air-pistol target (rings 1–10, inner ten 5 mm); see the
  /// program catalogue.
  const TargetGeometry.airPistol10m()
    : name = '10 m Air Pistol',
      caliberMm = 4.5,
      ringOuterDiametersMm = _airPistol10mRingDiametersMm,
      blackBullDiameterMm = 59.5,
      innerTenDiameterMm = 5,
      lowestRingValue = 1;

  /// The ISSF 25 m rapid-fire / silhouette target (rings 5–10 only, inner ten
  /// 50 mm) used for the duel stage; see the program catalogue. Calibre
  /// defaults to .22 (5.6 mm).
  const TargetGeometry.pistol25mRapid({double caliber = 5.6})
    : name = '25 m Pistol — Rapid',
      caliberMm = caliber,
      ringOuterDiametersMm = _pistol25mRapidRingDiametersMm,
      blackBullDiameterMm = 500,
      innerTenDiameterMm = 50,
      lowestRingValue = 5;

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

  /// Value of the outermost ring: 1 for a full 1–10 face, 5 for a reduced
  /// 5–10 rapid-fire face. Ring values run [lowestRingValue]..[highestRing].
  final int lowestRingValue;

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
  int get highestRing => lowestRingValue + ringOuterDiametersMm.length - 1;

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

  /// Outer diameter (mm) of [ring], where [lowestRingValue] is the outermost.
  double outerDiameterMm(int ring) {
    assert(
      ring >= lowestRingValue && ring <= highestRing,
      'ring must be between $lowestRingValue and $highestRing',
    );
    return ringOuterDiametersMm[ring - lowestRingValue];
  }

  /// Centre-distance (mm) within which a shot's centre scores at least [ring].
  ///
  /// Applies the gauge "next ring outward" rule: outer radius + pellet radius.
  double scoringRadiusMm(int ring) =>
      outerDiameterMm(ring) / 2 + pelletRadiusMm;

  /// Largest centre-distance (mm) that still scores; beyond this is a miss.
  double get maxScoringRadiusMm => scoringRadiusMm(lowestRingValue);
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

const List<double> _smallbore50mRingDiametersMm = <double>[
  154.4, // ring 1 (outermost)
  138.4, // ring 2
  122.4, // ring 3
  106.4, // ring 4
  90.4, // ring 5
  74.4, // ring 6
  58.4, // ring 7
  42.4, // ring 8
  26.4, // ring 9
  10.4, // ring 10 (innermost)
];

const List<double> _pistol25mPrecisionRingDiametersMm = <double>[
  500, // ring 1 (outermost)
  450, // ring 2
  400, // ring 3
  350, // ring 4
  300, // ring 5
  250, // ring 6
  200, // ring 7
  150, // ring 8
  100, // ring 9
  50, // ring 10 (innermost)
];

const List<double> _airPistol10mRingDiametersMm = <double>[
  155.5, // ring 1 (outermost)
  139.5, // ring 2
  123.5, // ring 3
  107.5, // ring 4
  91.5, // ring 5
  75.5, // ring 6
  59.5, // ring 7
  43.5, // ring 8
  27.5, // ring 9
  11.5, // ring 10 (innermost)
];

// Rings 5–10 only (no 1–4); ring 5 is the outermost.
const List<double> _pistol25mRapidRingDiametersMm = <double>[
  500, // ring 5 (outermost)
  420, // ring 6
  340, // ring 7
  260, // ring 8
  180, // ring 9
  100, // ring 10 (innermost)
];
