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
    this.ringLabelMaxValue,
    this.ringLabelsBothAxes = true,
    this.ringLabelHeightMm = 5,
    this.sightingLineLengthMm,
    this.sightingLineWidthMm = 5,
  });

  /// The ISSF / NSF 10 m air-rifle target (see spec 0001).
  const TargetGeometry.airRifle10m()
    : name = '10 m Air Rifle',
      caliberMm = 4.5,
      ringOuterDiametersMm = _airRifle10mRingDiametersMm,
      blackBullDiameterMm = 30.5,
      innerTenDiameterMm = null,
      lowestRingValue = 1,
      ringLabelMaxValue = 8,
      ringLabelsBothAxes = true,
      ringLabelHeightMm = 2,
      sightingLineLengthMm = null,
      sightingLineWidthMm = 5;

  /// The ISSF 25 m pistol precision target (rings 1–10, inner ten 25 mm); see
  /// `docs/reference/program-catalogue.md`. Calibre defaults to .22 (5.6 mm).
  const TargetGeometry.pistol25mPrecision({double caliber = 5.6})
    : name = '25 m Pistol — Precision',
      caliberMm = caliber,
      ringOuterDiametersMm = _pistol25mPrecisionRingDiametersMm,
      blackBullDiameterMm = 200,
      innerTenDiameterMm = 25,
      lowestRingValue = 1,
      ringLabelMaxValue = 9,
      ringLabelsBothAxes = true,
      ringLabelHeightMm = 10,
      sightingLineLengthMm = null,
      sightingLineWidthMm = 5;

  /// The ISSF 10 m air-pistol target (rings 1–10, inner ten 5 mm); see the
  /// program catalogue.
  const TargetGeometry.airPistol10m()
    : name = '10 m Air Pistol',
      caliberMm = 4.5,
      ringOuterDiametersMm = _airPistol10mRingDiametersMm,
      blackBullDiameterMm = 59.5,
      innerTenDiameterMm = 5,
      lowestRingValue = 1,
      ringLabelMaxValue = 8,
      ringLabelsBothAxes = true,
      ringLabelHeightMm = 2,
      sightingLineLengthMm = null,
      sightingLineWidthMm = 5;

  /// The ISSF 25 m rapid-fire / silhouette target (rings 5–10 only, inner ten
  /// 50 mm) used for the duel stage; see the program catalogue. Calibre
  /// defaults to .22 (5.6 mm).
  const TargetGeometry.pistol25mRapid({double caliber = 5.6})
    : name = '25 m Pistol — Rapid',
      caliberMm = caliber,
      ringOuterDiametersMm = _pistol25mRapidRingDiametersMm,
      blackBullDiameterMm = 500,
      innerTenDiameterMm = 50,
      lowestRingValue = 5,
      ringLabelMaxValue = 9,
      ringLabelsBothAxes = false,
      ringLabelHeightMm = 5,
      sightingLineLengthMm = 125,
      sightingLineWidthMm = 5;

  /// The NSF 10 m air sprint / duel ("Sprintluft") face: rings 5–10 on a face
  /// larger than the standard air-pistol target (10-ring ⌀ 23 mm), inner ten
  /// 11.5 mm. The aiming black covers the 8-zone only (spec 0121, the
  /// § 5.1.18.1.2 figure — 8/9 sit white on black, 7 and out on white).
  /// Used by Storluft (spec 0043). Air calibre 4.5 mm.
  const TargetGeometry.airDuel10m()
    : name = '10 m Luftduell',
      caliberMm = 4.5,
      ringOuterDiametersMm = _airDuel10mRingDiametersMm,
      blackBullDiameterMm = 76.0,
      innerTenDiameterMm = 11.5,
      lowestRingValue = 5,
      // Nasjonalt regelverk 5.1.18.1.2's figure and the physical sheet
      // (spec 0123, domain-expert verified): values 5–9 on both axes,
      // digits ≤ 2 mm, no sighting lines — the rulebook TEXT's 42,5 mm
      // stripes do not exist on the real Sprintluft sheet.
      ringLabelMaxValue = 9,
      ringLabelsBothAxes = true,
      ringLabelHeightMm = 2,
      sightingLineLengthMm = null,
      sightingLineWidthMm = 5;

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

  /// Whether the face supports decimal scoring. Since spec 0114 the tenth
  /// subdivides the shot's own scoring band, which needs no assumption
  /// about ring spacing — every ring face qualifies. Kept as a named gate
  /// for readability at the call sites.
  bool get supportsDecimalScore => true;

  /// The highest ring whose value is printed on the face (spec 0113,
  /// gtr-2026), or null when the face carries no printed values (the
  /// luftduell face, unconfirmed). The rings above it are unnumbered on
  /// the official sheets.
  final int? ringLabelMaxValue;

  /// Whether the printed values run along both axes (horizontal and
  /// vertical, at right angles) or only vertically — the duel face prints
  /// them vertically and replaces the side values with sighting lines
  /// (spec 0113, gtr-2026).
  final bool ringLabelsBothAxes;

  /// The printed digit height in millimetres (gtr-2026).
  final double ringLabelHeightMm;

  /// The duel faces' white horizontal sighting lines: their length in mm,
  /// or null on faces without them (gtr-2026 / nasjonalt regelverk).
  final double? sightingLineLengthMm;

  /// The sighting lines' width in mm (5 on the 25 m duel face, 3 on the
  /// luftduell face).
  final double sightingLineWidthMm;

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

// The 10 m air sprint / duel face: rings 5–10, 10-ring ⌀ 23 mm, step +26.5 mm
// outward to ring 5 ⌀ 155.5 mm (NSF Sprintluft target).
const List<double> _airDuel10mRingDiametersMm = <double>[
  155.5, // ring 5 (outermost)
  129, // ring 6
  102.5, // ring 7
  76, // ring 8
  49.5, // ring 9
  23, // ring 10 (innermost)
];
