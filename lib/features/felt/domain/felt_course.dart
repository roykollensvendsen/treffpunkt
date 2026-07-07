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
  });

  /// 1-based hold number.
  final int number;

  /// Distance label, e.g. `15 m` or `25 / 15 m`.
  final String distance;

  /// Shooting position (stilling).
  final String position;

  /// The colour all the hold's figures are printed in (spec 0078).
  final FeltHoldColour colour;

  /// The figures on the hold, in order.
  final List<FeltFigure> figures;
}

/// A felt course (spec 0145): an [id] stored with saved rounds, a display
/// [name] that also encodes the competition program and record key, the
/// [holds], and the per-group course maximum.
@immutable
class FeltCourse {
  /// Creates a course. [officialMax] carries the official per-group maxima
  /// when they exist; groups without one get the computed maximum.
  const FeltCourse({
    required this.id,
    required this.name,
    required this.holds,
    this.officialMax,
  });

  /// Stable id serialised into saved rounds (spec 0145).
  final String id;

  /// Display name, e.g. `'NorgesFelt-løype 2026'`.
  final String name;

  /// The holds, in shooting order.
  final List<FeltHoldDef> holds;

  /// Official per-group maxima (norgesfelt.no), when published.
  final Map<FeltShooterGroup, int>? officialMax;

  /// The course maximum for [group]: the official number when one is
  /// published, otherwise computed from the scoring rules (specs 0080/0085 —
  /// points = treff + distinct figures, inner is tiebreak only): per hold,
  /// shots + min(shots, figures).
  int maxPoints(FeltShooterGroup group) =>
      officialMax?[group] ??
      holds.fold(
        0,
        (sum, hold) =>
            sum +
            group.shotsPerHold +
            math.min(group.shotsPerHold, hold.figures.length),
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
/// (treff + figur, spec 0085): the official 80/47 (the official 80 for
/// gruppe 1 — 48 treff + 32 figur — confirms inner hits score nothing).
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
      for (var i = 0; i < 6; i++)
        FeltFigure(
          FeltFigureType.hexagon,
          // Lying first, then alternating standing (spec 0145).
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
    colour: FeltHoldColour.black,
    figures: <FeltFigure>[
      FeltFigure(
        FeltFigureType.stripe,
        widthCm: 12,
        heightCm: 37,
        name: 'Stolpe',
      ),
      FeltFigure(
        FeltFigureType.stripe,
        widthCm: 12,
        heightCm: 37,
        name: 'Stolpe',
      ),
      FeltFigure(
        FeltFigureType.stripe,
        widthCm: 12,
        heightCm: 37,
        name: 'Stolpe',
      ),
      FeltFigure(
        FeltFigureType.oval,
        widthCm: 33,
        heightCm: 22,
        name: 'Stor oval',
      ),
      FeltFigure(FeltFigureType.owl, widthCm: 23, heightCm: 50, name: 'Ugle'),
    ],
  ),
];

/// The official NorgesFelt 2026 course (spec 0068) with its official maxima.
final FeltCourse norgesfelt2026Course = FeltCourse(
  id: 'norgesfelt-2026',
  name: 'NorgesFelt-løype 2026',
  holds: norgesfelt2026,
  officialMax: <FeltShooterGroup, int>{
    FeltShooterGroup.one: 80,
    FeltShooterGroup.two: 47,
    FeltShooterGroup.three: 47,
  },
);

/// NorgesFelt Asker+ (spec 0145): the 2026 course plus holds 9–10. No
/// official maximum exists, so it is computed (103/90 for gruppe 1/2).
final FeltCourse askerPlusCourse = FeltCourse(
  id: 'norgesfelt-asker-plus',
  name: 'NorgesFelt Asker+',
  holds: <FeltHoldDef>[...norgesfelt2026, ..._askerPlusExtraHolds],
);

/// The courses the app offers, in display order (spec 0145).
final List<FeltCourse> feltCourses = <FeltCourse>[
  norgesfelt2026Course,
  askerPlusCourse,
];

/// The course with [id]; an unknown or missing id resolves to NorgesFelt
/// 2026, so every pre-0145 stored round keeps its course (spec 0145).
FeltCourse feltCourseById(String? id) => feltCourses.firstWhere(
  (course) => course.id == id,
  orElse: () => norgesfelt2026Course,
);
