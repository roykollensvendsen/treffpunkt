// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Course data with many figure literals — const-style lints add only noise.
// ignore_for_file: prefer_const_constructors,
// ignore_for_file: prefer_const_literals_to_create_immutables
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:treffpunkt/features/felt/domain/felt_figure.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';

/// One hold (station) of a field course (spec 0068): its [number], the
/// [distance], the shooting [position], and the [figures] on it.
@immutable
class FeltHoldDef {
  /// Creates a hold definition.
  const FeltHoldDef({
    required this.number,
    required this.distance,
    required this.position,
    required this.colour,
    required this.figures,
    this.time,
  });

  /// 1-based hold number.
  final int number;

  /// Distance label, e.g. `15 m` or `25 / 15 m`.
  final String distance;

  /// Shooting position (stilling).
  final String position;

  /// Shooting-time label, e.g. `150 sek`, where it varies per hold (T96,
  /// spec 0160); `null` on the NorgesFelt holds, whose 10 s is a
  /// course-level fact.
  final String? time;

  /// The colour all the hold's figures are printed in (spec 0078).
  final FeltHoldColour colour;

  /// The figures on the hold, in order.
  final List<FeltFigure> figures;
}

/// A felt course (spec 0145): an [id] stored with saved rounds, a display
/// [name] that also encodes the competition program and record key, the
/// [holds], and the per-group course maximum. A course also carries its
/// rule variations (spec 0160): whether inner zones score, which groups
/// shoot it, its word for a station and any per-group position override.
@immutable
class FeltCourse {
  /// Creates a course.
  const FeltCourse({
    required this.id,
    required this.name,
    required this.holds,
    this.innerScores = false,
    this.offeredGroups = FeltShooterGroup.offered,
    this.stationWord = 'Hold',
    this.stationWordPlural = 'hold',
    this.note,
    this.positionOverrides = const <FeltShooterGroup, String>{},
  });

  /// Stable id serialised into saved rounds (spec 0145).
  final String id;

  /// Display name, e.g. `'NorgesFelt-løype 2026'`.
  final String name;

  /// The holds, in shooting order.
  final List<FeltHoldDef> holds;

  /// Whether inner-zone hits score a point on this course (T96, spec 0160)
  /// instead of only breaking ties (spec 0085).
  final bool innerScores;

  /// The groups this course is shot in — the program variants offered
  /// (specs 0147/0160).
  final List<FeltShooterGroup> offeredGroups;

  /// The course's word for one station: `Hold` on NorgesFelt, `Serie` on
  /// T96 (the rulebook's own word, spec 0160).
  final String stationWord;

  /// The plural of [stationWord], lowercase (`hold` / `serier`).
  final String stationWordPlural;

  /// A course-level rule note shown on the preview (spec 0160), or `null`.
  final String? note;

  /// Per-group position overrides (spec 0160), applied to every hold.
  final Map<FeltShooterGroup, String> positionOverrides;

  /// The shooting position of [hold] for [group]: the hold's own, unless
  /// the course overrides it for the group — T96's Magnum exception, «alle
  /// serier med to hender» (spec 0160).
  String positionFor(FeltHoldDef hold, FeltShooterGroup group) =>
      positionOverrides[group] ?? hold.position;

  /// The course maximum for [group], computed from the scoring rules
  /// (specs 0080/0085 — points = treff + distinct figures, inner is
  /// tiebreak only): per hold, shots + min(shots, figures). Always
  /// computed (spec 0148): the once-cited «official» 47 for Gruppe 2 was
  /// falsified by the domain expert's perfect 70-point round; Gruppe 1's
  /// official 80 equals the formula. Where [innerScores] (spec 0160)
  /// every shot can also be an inner hit, adding shots again.
  int maxPoints(FeltShooterGroup group) => holds.fold<int>(
    0,
    (sum, hold) =>
        sum +
        group.shotsPerHold +
        math.min<int>(group.shotsPerHold, hold.figures.length) +
        (innerScores ? group.shotsPerHold : 0),
  );

  /// The competition-program name for [group] (spec 0140's encoding: the
  /// group — and now the course — is the program).
  String programName(FeltShooterGroup group) => '$name (${group.label})';

  /// The personal-record / statistics key for [group] (spec 0143 pattern).
  String recordKey(FeltShooterGroup group) => '$name · ${group.label}';
}

/// The NorgesFelt 2026 course (spec 0068), reconstructed from norgesfelt.no:
/// 8 holds, 10 s shooting time. Inner zones follow the measured art (spec
/// 0104): every figure has one except hold 5's big triangle. Max points
/// (treff + figur, spec 0085): computed 80/70 (spec 0148); the official 80
/// for gruppe 1 — 48 treff + 32 figur — confirms inner hits score nothing.
final List<FeltHoldDef> norgesfelt2026 = <FeltHoldDef>[
  FeltHoldDef(
    number: 1,
    distance: '15 m',
    position: 'Stående 1 hånd',
    colour: FeltHoldColour.black,
    figures: <FeltFigure>[
      FeltFigure(FeltFigureType.hare, widthCm: 31, heightCm: 41, name: 'Hare'),
      FeltFigure(
        FeltFigureType.oval,
        widthCm: 33,
        heightCm: 22,
        name: 'Stor oval',
      ),
    ],
  ),
  FeltHoldDef(
    number: 2,
    distance: '25 / 15 m',
    position: 'Stående fri',
    colour: FeltHoldColour.green,
    figures: <FeltFigure>[
      FeltFigure(
        FeltFigureType.stripe,
        widthCm: 12,
        heightCm: 37,
        name: 'Stor stripe',
      ),
      FeltFigure(
        FeltFigureType.stripe,
        widthCm: 12,
        heightCm: 37,
        name: 'Stor stripe',
      ),
      FeltFigure(
        FeltFigureType.hexagon,
        widthCm: 31,
        heightCm: 22,
        name: 'Sekskant',
      ),
      FeltFigure(
        FeltFigureType.bowlingPin,
        widthCm: 38,
        heightCm: 13,
        name: 'Kjegle',
      ),
      FeltFigure(
        FeltFigureType.bowlingPin,
        widthCm: 38,
        heightCm: 13,
        name: 'Kjegle',
      ),
      FeltFigure(
        FeltFigureType.bowlingPin,
        widthCm: 38,
        heightCm: 13,
        name: 'Kjegle',
      ),
    ],
  ),
  FeltHoldDef(
    number: 3,
    distance: '25 / 15 m',
    position: 'Stående 2 hender',
    colour: FeltHoldColour.red,
    figures: <FeltFigure>[
      FeltFigure(
        FeltFigureType.triangle,
        widthCm: 21,
        heightCm: 19,
        name: 'Trekant',
      ),
      FeltFigure.circle(13),
      FeltFigure.circle(20),
      FeltFigure.circle(25),
      FeltFigure(
        FeltFigureType.egg,
        widthCm: 18,
        heightCm: 7,
        name: 'Egg liten',
      ),
    ],
  ),
  FeltHoldDef(
    number: 4,
    distance: '25 m',
    position: 'FG Stående 1 hånd – andre fri',
    colour: FeltHoldColour.black,
    figures: <FeltFigure>[
      FeltFigure(
        FeltFigureType.oval,
        widthCm: 19,
        heightCm: 14,
        name: 'Liten oval',
      ),
      FeltFigure(
        FeltFigureType.wolfHead,
        widthCm: 40,
        heightCm: 35,
        name: 'Ulvehode',
      ),
      FeltFigure(
        FeltFigureType.ptarmigan,
        widthCm: 25,
        heightCm: 25,
        name: 'Rype',
      ),
    ],
  ),
  FeltHoldDef(
    number: 5,
    distance: '25 m',
    position: 'Stående 2 hender',
    colour: FeltHoldColour.green,
    figures: <FeltFigure>[
      FeltFigure(
        FeltFigureType.rightTriangle,
        widthCm: 50,
        heightCm: 50,
        name: 'Trekant stor',
      ),
      FeltFigure(
        FeltFigureType.oval,
        widthCm: 19,
        heightCm: 14,
        name: 'Oval liten',
      ),
    ],
  ),
  FeltHoldDef(
    number: 6,
    distance: '25 / 15 m',
    position: 'Stående fri',
    colour: FeltHoldColour.red,
    figures: <FeltFigure>[
      FeltFigure(
        FeltFigureType.hexagon,
        widthCm: 31,
        heightCm: 22,
        name: 'Sekskant',
      ),
      FeltFigure(
        FeltFigureType.triangle,
        widthCm: 21,
        heightCm: 19,
        name: 'Trekant',
      ),
      FeltFigure.circle(13),
      FeltFigure.circle(25),
      FeltFigure(
        FeltFigureType.egg,
        widthCm: 20,
        heightCm: 10,
        name: 'Egg stor',
      ),
    ],
  ),
  FeltHoldDef(
    number: 7,
    distance: '25 m',
    position: 'Sittende 2 hender',
    colour: FeltHoldColour.black,
    figures: <FeltFigure>[
      FeltFigure(
        FeltFigureType.oval,
        widthCm: 19,
        heightCm: 14,
        name: 'Liten oval',
      ),
      FeltFigure.circle(13),
      FeltFigure(
        FeltFigureType.reducedFigure,
        widthCm: 41,
        heightCm: 27,
        name: '1/6',
      ),
    ],
  ),
  FeltHoldDef(
    number: 8,
    distance: '25 / 15 m',
    position: 'Stående fri',
    colour: FeltHoldColour.green,
    figures: <FeltFigure>[
      FeltFigure(
        FeltFigureType.hexagon,
        widthCm: 31,
        heightCm: 22,
        name: 'Sekskant',
      ),
      FeltFigure(
        FeltFigureType.stripe,
        widthCm: 12,
        heightCm: 37,
        name: 'Stor stripe',
      ),
      FeltFigure(
        FeltFigureType.hexagon,
        widthCm: 31,
        heightCm: 22,
        name: 'Sekskant',
      ),
      FeltFigure(
        FeltFigureType.stripe,
        widthCm: 8,
        heightCm: 25,
        name: 'Liten stripe',
      ),
      FeltFigure(
        FeltFigureType.stripe,
        widthCm: 8,
        heightCm: 25,
        name: 'Liten stripe',
      ),
      FeltFigure(
        FeltFigureType.stripe,
        widthCm: 8,
        heightCm: 25,
        name: 'Liten stripe',
      ),
    ],
  ),
];

/// The two extra holds of NorgesFelt Asker+ (spec 0145), from the family's
/// signed-off sketch. Hold 9 alternates hold 8's hexagon lying/standing in
/// green/red; hold 10 is three stolper (the tre-kvadrater stripes), hold 1's
/// big oval lying and the owl. The composed art carries the per-figure
/// colours; the hold colour here is the dominant one.
final List<FeltHoldDef> _askerPlusExtraHolds = <FeltHoldDef>[
  FeltHoldDef(
    number: 9,
    distance: '25 m',
    position: 'Stående fri',
    colour: FeltHoldColour.green,
    figures: <FeltFigure>[
      for (var i = 0; i < 5; i++)
        FeltFigure(
          FeltFigureType.hexagon,
          // Five hexagons alternating green-lying / red-standing, starting
          // and ending on green-lying (G-R-G-R-G), matching the physical
          // sheet (domain-expert photo 2026-07-08). The same hexagon
          // rotated, so every figure has equal area; the art lays them in
          // two rows (3 + 2) to keep the hold picture's proportions.
          widthCm: i.isEven ? 31 : 22,
          heightCm: i.isEven ? 22 : 31,
          name: 'Sekskant',
        ),
    ],
  ),
  FeltHoldDef(
    number: 10,
    distance: '25 m',
    position: 'Stående fri',
    colour: FeltHoldColour.green,
    // Left→right on the sheet (domain-expert photo 2026-07-08): a lying
    // green hexagon, the owl, three lying green stolper (the standing
    // stolper rotated 90°), and a standing green hexagon.
    figures: <FeltFigure>[
      FeltFigure(
        FeltFigureType.hexagon,
        widthCm: 31,
        heightCm: 22,
        name: 'Sekskant',
      ),
      FeltFigure(FeltFigureType.owl, widthCm: 23, heightCm: 50, name: 'Ugle'),
      FeltFigure(
        FeltFigureType.stripe,
        widthCm: 37,
        heightCm: 12,
        name: 'Stolpe',
      ),
      FeltFigure(
        FeltFigureType.stripe,
        widthCm: 37,
        heightCm: 12,
        name: 'Stolpe',
      ),
      FeltFigure(
        FeltFigureType.stripe,
        widthCm: 37,
        heightCm: 12,
        name: 'Stolpe',
      ),
      FeltFigure(
        FeltFigureType.hexagon,
        widthCm: 22,
        heightCm: 31,
        name: 'Sekskant',
      ),
    ],
  ),
];

/// The official NorgesFelt 2026 course (spec 0068): computed maxima 80/70
/// for gruppe 1/2 (spec 0148).
final FeltCourse norgesfelt2026Course = FeltCourse(
  id: 'norgesfelt-2026',
  name: 'NorgesFelt-løype 2026',
  holds: norgesfelt2026,
);

/// NorgesFelt Asker+ (spec 0145): the 2026 course plus holds 9–10,
/// computed maxima 103/90 for gruppe 1/2.
final FeltCourse askerPlusCourse = FeltCourse(
  id: 'norgesfelt-asker-plus',
  name: 'NorgesFelt Asker+',
  holds: <FeltHoldDef>[...norgesfelt2026, ..._askerPlusExtraHolds],
);

/// One T96 series (spec 0160): the same 5-delt sheet every time — five
/// full circles ⌀ 110 mm with a ⌀ 45 mm inner zone (reglement-felt-t96-2026
/// § 8.26.4) — at the series' distance, time and position.
FeltHoldDef _t96Series({
  required int number,
  required String distance,
  required String time,
  required String position,
}) => FeltHoldDef(
  number: number,
  distance: distance,
  time: time,
  position: position,
  colour: FeltHoldColour.black,
  figures: <FeltFigure>[
    for (var i = 0; i < 5; i++)
      // A full circle — deliberately not FeltFigure.circle, whose C-figure
      // is cut flat across the bottom (spec 0077).
      FeltFigure(
        FeltFigureType.circle,
        widthCm: 11,
        heightCm: 11,
        innerCm: 4.5,
        name: 'Sirkel',
      ),
  ],
);

/// The 16 T96 series (spec 0160), verbatim from reglement-felt-t96-2026
/// § 8.26.3: 11 m and 15 m each shoot 150/150/20/20/10/10 sek alternating
/// stående fri / stående 1 hånd; 25 m shoots 150/150/20/20 sek, all fri.
final List<FeltHoldDef> t96Series = <FeltHoldDef>[
  for (var i = 0; i < 16; i++)
    _t96Series(
      number: i + 1,
      distance: i < 6
          ? '11 m'
          : i < 12
          ? '15 m'
          : '25 m',
      time:
          '${const <int>[150, 150, 20, 20, 10, 10][i < 12 ? i % 6 : i - 12]}'
          ' sek',
      position: i >= 12 || i.isEven ? 'Stående fri' : 'Stående 1 hånd',
    ),
];

/// T96 — «Kråkefelt» (spec 0160): 16 series on the 5-delt T96 sheet, shot
/// in all three groups (Gruppe 1/2/3 — 6/5/5 shots), inner zones scoring a
/// point (§ 8.26.5), computed maxima 272/240/240. Magnum (Gruppe 3) shoots
/// every series with two hands (§ 8.26.3's exception).
final FeltCourse t96Course = FeltCourse(
  id: 't96',
  name: 'T96',
  holds: t96Series,
  innerScores: true,
  offeredGroups: FeltShooterGroup.values,
  stationWord: 'Serie',
  stationWordPlural: 'serier',
  note: 'Magnum (Gruppe 3) skyter alle serier med to hender.',
  positionOverrides: <FeltShooterGroup, String>{
    FeltShooterGroup.three: 'Stående 2 hender',
  },
);

/// The courses the app offers, in display order (specs 0145/0160).
final List<FeltCourse> feltCourses = <FeltCourse>[
  norgesfelt2026Course,
  askerPlusCourse,
  t96Course,
];

/// The course with [id]; an unknown or missing id resolves to NorgesFelt
/// 2026, so every pre-0145 stored round keeps its course (spec 0145).
FeltCourse feltCourseById(String? id) => feltCourses.firstWhere(
  (course) => course.id == id,
  orElse: () => norgesfelt2026Course,
);
