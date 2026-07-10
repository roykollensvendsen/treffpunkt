// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/scoring/domain/program_category.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

/// The seeded catalogue of official shooting programs.
///
/// See `docs/reference/program-catalogue.md` for the sources. Geometry is from
/// the ISSF Technical Rules (high confidence); a few NSF-specific timings are
/// still to confirm with the father (noted in the reference).
abstract final class ProgramCatalogue {
  /// 10 m air rifle: a single 10-shot series (decimal scoring).
  ///
  /// Kept as the spec-0001 reference program and the decimal-scoring source —
  /// it backs `TargetGeometry.airRifle10m()` and is the canonical test fixture
  /// — but it is deliberately *not* in [all], so it is not offered in the
  /// program picker: the NSF domain expert does not want air rifle in the
  /// program list.
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

  /// 10 m air pistol: 60 shots in six 10-shot series (the ISSF match).
  ///
  /// Named in Norwegian to match the rest of the catalogue; the old English
  /// name "10 m Air Pistol" still resolves via [byName] (see [_renamedFrom]) so
  /// sessions and competitions recorded under it still load.
  static const ProgramDefinition airPistol10m = ProgramDefinition(
    name: '10 m Luftpistol 60 skudd',
    discipline: Discipline.pistol,
    weaponClasses: <String>['Air 4.5 mm'],
    supportsDecimalEntry: true,
    stages: <StageDefinition>[
      StageDefinition(
        name: 'Match',
        geometry: TargetGeometry.airPistol10m(),
        shotsPerSeries: 10,
        seriesCount: 6,
      ),
    ],
  );

  /// 10 m air pistol, 40 shots: four 10-shot series (NSF women / veterans /
  /// juniors), on the same face as the 60-shot [airPistol10m].
  static const ProgramDefinition airPistol10m40 = ProgramDefinition(
    name: '10 m Luftpistol 40 skudd',
    discipline: Discipline.pistol,
    weaponClasses: <String>['Air 4.5 mm'],
    supportsDecimalEntry: true,
    stages: <StageDefinition>[
      StageDefinition(
        name: 'Match',
        geometry: TargetGeometry.airPistol10m(),
        shotsPerSeries: 10,
        seriesCount: 4,
      ),
    ],
  );

  /// Sprintluft: the NSF recruit air-pistol program — 30 shots on the larger
  /// Sprintluft / luftduell face (rings 5–10), 15 min for the match (plus 5
  /// sighters, not modelled). A competition paper target takes at most 5 shots,
  /// so the 30 shots are fired across 6 targets — six 5-shot series (confirmed
  /// by the NSF domain expert, spec 0044). Resembles 10 m air pistol but
  /// shorter and easier (NSF *Nasjonalt regelverk*). The "sprint" counterpart
  /// to [storluftDuel].
  static const ProgramDefinition sprintluft = ProgramDefinition(
    name: 'Sprintluft',
    discipline: Discipline.pistol,
    weaponClasses: <String>['Air 4.5 mm'],
    supportsDecimalEntry: true,
    stages: <StageDefinition>[
      StageDefinition(
        name: 'Match',
        geometry: TargetGeometry.airDuel10m(),
        shotsPerSeries: 5,
        seriesCount: 6,
      ),
    ],
  );

  /// Storluft (luftduell-skive): the corona-era home air-pistol program — 40
  /// shots in four 10-shot series on the larger Sprintluft / luftduell face
  /// (rings 5–10) at 10 m. The "big" counterpart to Sprintluft (40 shots /
  /// 50 min vs 30 / 15 min); documented on the FSU 2020 ranking page as a
  /// program that could be shot unapproved, also at home (spec 0043).
  static const ProgramDefinition storluftDuel = ProgramDefinition(
    name: 'Storluft (luftduell-skive)',
    discipline: Discipline.pistol,
    weaponClasses: <String>['Air 4.5 mm'],
    supportsDecimalEntry: true,
    stages: <StageDefinition>[
      StageDefinition(
        name: 'Match',
        geometry: TargetGeometry.airDuel10m(),
        shotsPerSeries: 10,
        seriesCount: 4,
      ),
    ],
  );

  /// Storluft (5,5 m): the same 40-shot program shot on the standard 10 m
  /// air-pistol face (rings 1–10) at the reduced home distance of 5.5 m — the
  /// alternative target from the same rule note (spec 0043).
  static const ProgramDefinition storluft55m = ProgramDefinition(
    name: 'Storluft (5,5 m)',
    discipline: Discipline.pistol,
    weaponClasses: <String>['Air 4.5 mm'],
    supportsDecimalEntry: true,
    stages: <StageDefinition>[
      StageDefinition(
        name: 'Match',
        geometry: TargetGeometry.airPistol10m(),
        shotsPerSeries: 10,
        seriesCount: 4,
      ),
    ],
  );

  /// 25 m standard pistol: 12 series of 5 on the precision face across three
  /// timed stages (150 s / 20 s / 10 s).
  static const ProgramDefinition standardPistol25m = ProgramDefinition(
    name: '25 m Standard Pistol',
    discipline: Discipline.pistol,
    weaponClasses: <String>['.22 LR'],
    supportsDecimalEntry: true,
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
    supportsDecimalEntry: true,
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
    supportsDecimalEntry: true,
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

  /// 25 m hurtigpistol fin (.22): 60 shots in twelve 5-shot series on the duel
  /// face, across three timed stages (10 s / 8 s / 6 s). NSF national rapid-fire
  /// program (NSF Skyteprogrammer – Pistol §8.26).
  static const ProgramDefinition hurtigpistolFin25m = ProgramDefinition(
    name: '25 m Hurtigpistol fin',
    discipline: Discipline.pistol,
    weaponClasses: <String>['.22 LR'],
    supportsDecimalEntry: true,
    stages: <StageDefinition>[
      StageDefinition(
        name: '10 s',
        geometry: TargetGeometry.pistol25mRapid(),
        shotsPerSeries: 5,
        seriesCount: 4,
        secondsPerSeries: 10,
      ),
      StageDefinition(
        name: '8 s',
        geometry: TargetGeometry.pistol25mRapid(),
        shotsPerSeries: 5,
        seriesCount: 4,
        secondsPerSeries: 8,
      ),
      StageDefinition(
        name: '6 s',
        geometry: TargetGeometry.pistol25mRapid(),
        shotsPerSeries: 5,
        seriesCount: 4,
        secondsPerSeries: 6,
      ),
    ],
  );

  /// 25 m hurtigpistol grov (centre-fire .32–.38): same structure as
  /// [hurtigpistolFin25m] with a coarser calibre (NSF Skyteprogrammer §8.26).
  static const ProgramDefinition hurtigpistolGrov25m = ProgramDefinition(
    name: '25 m Hurtigpistol grov',
    discipline: Discipline.pistol,
    weaponClasses: <String>['Centre-fire 7.62–9.65 mm'],
    supportsDecimalEntry: true,
    stages: <StageDefinition>[
      StageDefinition(
        name: '10 s',
        geometry: TargetGeometry.pistol25mRapid(caliber: 9.65),
        shotsPerSeries: 5,
        seriesCount: 4,
        secondsPerSeries: 10,
      ),
      StageDefinition(
        name: '8 s',
        geometry: TargetGeometry.pistol25mRapid(caliber: 9.65),
        shotsPerSeries: 5,
        seriesCount: 4,
        secondsPerSeries: 8,
      ),
      StageDefinition(
        name: '6 s',
        geometry: TargetGeometry.pistol25mRapid(caliber: 9.65),
        shotsPerSeries: 5,
        seriesCount: 4,
        secondsPerSeries: 6,
      ),
    ],
  );

  /// Silhuettpistol 25 m (.22): 60 shots in twelve 5-shot series on the rapid /
  /// silhouette face, across three timed stages (8 s / 6 s / 4 s). Each series
  /// is fired one shot at each of **five** identical silhouette targets,
  /// recorded in firing order — so the stage carries `targetsPerSeries: 5`
  /// (spec 0067). The shots still score against the single rapid face (5–10).
  static const ProgramDefinition silhuettpistol25m = ProgramDefinition(
    name: '25 m Silhuettpistol',
    discipline: Discipline.pistol,
    weaponClasses: <String>['.22 LR'],
    supportsDecimalEntry: true,
    stages: <StageDefinition>[
      StageDefinition(
        name: '8 s',
        geometry: TargetGeometry.pistol25mRapid(),
        shotsPerSeries: 5,
        seriesCount: 4,
        secondsPerSeries: 8,
        targetsPerSeries: 5,
      ),
      StageDefinition(
        name: '6 s',
        geometry: TargetGeometry.pistol25mRapid(),
        shotsPerSeries: 5,
        seriesCount: 4,
        secondsPerSeries: 6,
        targetsPerSeries: 5,
      ),
      StageDefinition(
        name: '4 s',
        geometry: TargetGeometry.pistol25mRapid(),
        shotsPerSeries: 5,
        seriesCount: 4,
        secondsPerSeries: 4,
        targetsPerSeries: 5,
      ),
    ],
  );

  /// NAIS 25 m fin (.22–.32): 30 shots in six 5-shot series on the duel face —
  /// two 150 s precision series, two duel series, one 20 s and one 10 s series.
  /// NSF "Reglement for merkeskyting til NAIS-medaljen" / Skyteprogrammer §8.29.
  static const ProgramDefinition naisFin25m = ProgramDefinition(
    name: '25 m NAIS fin',
    discipline: Discipline.pistol,
    weaponClasses: <String>['.22 LR'],
    supportsDecimalEntry: true,
    stages: <StageDefinition>[
      StageDefinition(
        name: 'Presisjon 150 s',
        geometry: TargetGeometry.pistol25mRapid(),
        shotsPerSeries: 5,
        seriesCount: 2,
        secondsPerSeries: 150,
      ),
      StageDefinition(
        name: 'Duell',
        geometry: TargetGeometry.pistol25mRapid(),
        shotsPerSeries: 5,
        seriesCount: 2,
      ),
      StageDefinition(
        name: '20 s',
        geometry: TargetGeometry.pistol25mRapid(),
        shotsPerSeries: 5,
        seriesCount: 1,
        secondsPerSeries: 20,
      ),
      StageDefinition(
        name: '10 s',
        geometry: TargetGeometry.pistol25mRapid(),
        shotsPerSeries: 5,
        seriesCount: 1,
        secondsPerSeries: 10,
      ),
    ],
  );

  /// NAIS 25 m grov (centre-fire .38–.45): same structure as [naisFin25m] with
  /// a coarser calibre (NSF NAIS-medaljen reglement / Skyteprogrammer §8.29).
  static const ProgramDefinition naisGrov25m = ProgramDefinition(
    name: '25 m NAIS grov',
    discipline: Discipline.pistol,
    weaponClasses: <String>['Centre-fire 7.62–9.65 mm'],
    supportsDecimalEntry: true,
    stages: <StageDefinition>[
      StageDefinition(
        name: 'Presisjon 150 s',
        geometry: TargetGeometry.pistol25mRapid(caliber: 9.65),
        shotsPerSeries: 5,
        seriesCount: 2,
        secondsPerSeries: 150,
      ),
      StageDefinition(
        name: 'Duell',
        geometry: TargetGeometry.pistol25mRapid(caliber: 9.65),
        shotsPerSeries: 5,
        seriesCount: 2,
      ),
      StageDefinition(
        name: '20 s',
        geometry: TargetGeometry.pistol25mRapid(caliber: 9.65),
        shotsPerSeries: 5,
        seriesCount: 1,
        secondsPerSeries: 20,
      ),
      StageDefinition(
        name: '10 s',
        geometry: TargetGeometry.pistol25mRapid(caliber: 9.65),
        shotsPerSeries: 5,
        seriesCount: 1,
        secondsPerSeries: 10,
      ),
    ],
  );

  /// 50 m free pistol (fripistol): six 10-shot series on the precision face.
  static const ProgramDefinition freePistol50m = ProgramDefinition(
    name: '50 m Fripistol',
    discipline: Discipline.pistol,
    weaponClasses: <String>['.22 LR'],
    supportsDecimalEntry: true,
    stages: <StageDefinition>[
      StageDefinition(
        name: 'Match',
        geometry: TargetGeometry.pistol25mPrecision(),
        shotsPerSeries: 10,
        seriesCount: 6,
      ),
    ],
  );

  /// The NSF Luft category (spec 0084): the air-pistol programs, in display
  /// order.
  static const List<ProgramDefinition> nsfLuft = <ProgramDefinition>[
    airPistol10m,
    airPistol10m40,
    sprintluft,
    storluftDuel,
    storluft55m,
  ];

  /// The NSF Fin/Grov category (spec 0084): the fin- and grovpistol cartridge
  /// programs at 25 m and 50 m, in display order.
  static const List<ProgramDefinition> nsfFinGrov = <ProgramDefinition>[
    standardPistol25m,
    finpistol25m,
    grovpistol25m,
    hurtigpistolFin25m,
    hurtigpistolGrov25m,
    silhuettpistol25m,
    naisFin25m,
    naisGrov25m,
    freePistol50m,
  ];

  /// All seeded programs **offered to the shooter**, in display order — the
  /// categories concatenated (spec 0084), so every offered program belongs to
  /// exactly one category.
  ///
  /// Air rifle ([airRifle10m]) is intentionally absent: it is retained as the
  /// spec-0001 / decimal-scoring reference and test fixture but is not offered
  /// in the program list at the NSF domain expert's request. It is still
  /// resolvable by [byName] so a session recorded before the change still
  /// loads (see [_resolvable]).
  static const List<ProgramDefinition> all = <ProgramDefinition>[
    ...nsfLuft,
    ...nsfFinGrov,
  ];

  /// The ring programs offered under [category], in display order.
  ///
  /// Empty for [ProgramCategory.mil] (no military programs are seeded yet)
  /// and [ProgramCategory.felt] (its content is the felt feature's courses,
  /// not `ProgramDefinition`s — see spec 0068).
  static List<ProgramDefinition> inCategory(ProgramCategory category) =>
      switch (category) {
        ProgramCategory.nsfLuft => nsfLuft,
        ProgramCategory.nsfFinGrov => nsfFinGrov,
        ProgramCategory.mil ||
        ProgramCategory.felt => const <ProgramDefinition>[],
      };

  /// Every program a stored session may name: the offered [all] plus the
  /// retained-but-not-offered reference programs (air rifle). Used only by
  /// [byName]; the picker reads [all].
  static const List<ProgramDefinition> _resolvable = <ProgramDefinition>[
    ...all,
    airRifle10m,
  ];

  /// Old program names mapped to their current one, so data stored under a name
  /// that has since been renamed still resolves (spec 0036).
  static const Map<String, String> _renamedFrom = <String, String>{
    '10 m Air Pistol': '10 m Luftpistol 60 skudd',
  };

  /// The program whose unique [name] matches, or `null` when none does.
  ///
  /// Used to resolve a stored session back to its definition (spec 0009): a
  /// recording keeps the program name, not the geometry, so the canonical
  /// stage geometries are always rebuilt from here. Resolves the offered
  /// programs ([all]) and the retained reference programs (air rifle), so a
  /// session recorded before air rifle was dropped from the list still loads.
  ///
  /// A name that has since been renamed (e.g. the old "10 m Air Pistol")
  /// resolves through [_renamedFrom], so older stored sessions and competitions
  /// still load after a rename (spec 0036).
  static ProgramDefinition? byName(String name) {
    final canonical = _renamedFrom[name] ?? name;
    for (final definition in _resolvable) {
      if (definition.name == canonical) return definition;
    }
    return null;
  }
}
