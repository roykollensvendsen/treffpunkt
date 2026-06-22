// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

/// The seeded catalogue of official shooting programs.
///
/// See `docs/reference/program-catalogue.md` for the sources. Geometry is from
/// the ISSF Technical Rules (high confidence); a few NSF-specific timings are
/// still to confirm with the father (noted in the reference).
abstract final class ProgramCatalogue {
  /// 10 m air rifle: a single 10-shot series (decimal scoring).
  static const ProgramDefinition airRifle10m = ProgramDefinition(
    name: '10 m Air Rifle',
    discipline: Discipline.rifle,
    weaponClasses: <String>['Air 4.5 mm'],
    stages: <StageDefinition>[
      StageDefinition(
        name: 'Series',
        geometry: TargetGeometry.airRifle10m(),
        shotsPerSeries: 10,
        seriesCount: 1,
      ),
    ],
  );

  /// 10 m air pistol: 60 shots in six 10-shot series.
  static const ProgramDefinition airPistol10m = ProgramDefinition(
    name: '10 m Air Pistol',
    discipline: Discipline.pistol,
    weaponClasses: <String>['Air 4.5 mm'],
    stages: <StageDefinition>[
      StageDefinition(
        name: 'Match',
        geometry: TargetGeometry.airPistol10m(),
        shotsPerSeries: 10,
        seriesCount: 6,
      ),
    ],
  );

  /// 25 m standard pistol: 12 series of 5 on the precision face across three
  /// timed stages (150 s / 20 s / 10 s).
  static const ProgramDefinition standardPistol25m = ProgramDefinition(
    name: '25 m Standard Pistol',
    discipline: Discipline.pistol,
    weaponClasses: <String>['.22 LR'],
    stages: <StageDefinition>[
      StageDefinition(
        name: '150 s',
        geometry: TargetGeometry.pistol25mPrecision(),
        shotsPerSeries: 5,
        seriesCount: 4,
        secondsPerSeries: 150,
      ),
      StageDefinition(
        name: '20 s',
        geometry: TargetGeometry.pistol25mPrecision(),
        shotsPerSeries: 5,
        seriesCount: 4,
        secondsPerSeries: 20,
      ),
      StageDefinition(
        name: '10 s',
        geometry: TargetGeometry.pistol25mPrecision(),
        shotsPerSeries: 5,
        seriesCount: 4,
        secondsPerSeries: 10,
      ),
    ],
  );

  /// 25 m finpistol (.22): precision then duel, on two different faces.
  static const ProgramDefinition finpistol25m = ProgramDefinition(
    name: '25 m Finpistol',
    discipline: Discipline.pistol,
    weaponClasses: <String>['.22 LR'],
    stages: <StageDefinition>[
      StageDefinition(
        name: 'Presisjon',
        geometry: TargetGeometry.pistol25mPrecision(),
        shotsPerSeries: 5,
        seriesCount: 6,
      ),
      StageDefinition(
        name: 'Duell',
        geometry: TargetGeometry.pistol25mRapid(),
        shotsPerSeries: 5,
        seriesCount: 6,
      ),
    ],
  );

  /// 25 m grovpistol (centre-fire): same structure as finpistol.
  static const ProgramDefinition grovpistol25m = ProgramDefinition(
    name: '25 m Grovpistol',
    discipline: Discipline.pistol,
    weaponClasses: <String>['Centre-fire 7.62–9.65 mm'],
    stages: <StageDefinition>[
      StageDefinition(
        name: 'Presisjon',
        geometry: TargetGeometry.pistol25mPrecision(caliber: 9.65),
        shotsPerSeries: 5,
        seriesCount: 6,
      ),
      StageDefinition(
        name: 'Duell',
        geometry: TargetGeometry.pistol25mRapid(caliber: 9.65),
        shotsPerSeries: 5,
        seriesCount: 6,
      ),
    ],
  );

  /// 50 m rifle prone: 60 shots in six 10-shot series on the 50 m rifle face,
  /// scored integer + inner ten (see spec 0017). The exact NSF course of fire
  /// (60 prone vs 3×20 / 3×40 three-position) and whether NSF scores it to a
  /// decimal are confirm-with-the-father flags in the spec, not seeded here.
  static const ProgramDefinition rifle50mProne = ProgramDefinition(
    name: '50 m Rifle Prone',
    discipline: Discipline.rifle,
    weaponClasses: <String>['.22 LR'],
    stages: <StageDefinition>[
      StageDefinition(
        name: 'Prone',
        geometry: TargetGeometry.smallbore50m(),
        shotsPerSeries: 10,
        seriesCount: 6,
      ),
    ],
  );

  /// 300 m rifle: 60 shots in six 10-shot series on the 300 m rifle face,
  /// scored integer + inner ten (see spec 0018). Calibre is centre-fire (gauge
  /// edge defaulting to 8 mm — flagged in the spec). The exact NSF course of
  /// fire (60 prone vs 3×20 / 3×40) and decimal-vs-integer scoring are
  /// confirm-with-the-father flags in the spec, not seeded here.
  static const ProgramDefinition rifle300m = ProgramDefinition(
    name: '300 m Rifle',
    discipline: Discipline.rifle,
    weaponClasses: <String>['Centre-fire ≤ 8 mm'],
    stages: <StageDefinition>[
      StageDefinition(
        name: 'Match',
        geometry: TargetGeometry.rifle300m(),
        shotsPerSeries: 10,
        seriesCount: 6,
      ),
    ],
  );

  /// 50 m free pistol (fripistol): six 10-shot series on the precision face.
  static const ProgramDefinition freePistol50m = ProgramDefinition(
    name: '50 m Fripistol',
    discipline: Discipline.pistol,
    weaponClasses: <String>['.22 LR'],
    stages: <StageDefinition>[
      StageDefinition(
        name: 'Match',
        geometry: TargetGeometry.pistol25mPrecision(),
        shotsPerSeries: 10,
        seriesCount: 6,
      ),
    ],
  );

  /// All seeded programs, in display order.
  static const List<ProgramDefinition> all = <ProgramDefinition>[
    airRifle10m,
    airPistol10m,
    standardPistol25m,
    finpistol25m,
    grovpistol25m,
    freePistol50m,
    rifle50mProne,
    rifle300m,
  ];

  /// The program whose unique [name] matches, or `null` when none does.
  ///
  /// Used to resolve a stored session back to its definition (spec 0009): a
  /// recording keeps the program name, not the geometry, so the canonical
  /// stage geometries are always rebuilt from here.
  static ProgramDefinition? byName(String name) {
    for (final definition in all) {
      if (definition.name == name) return definition;
    }
    return null;
  }
}
