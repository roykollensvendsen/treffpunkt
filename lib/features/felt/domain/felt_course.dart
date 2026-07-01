// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Course data with many figure literals — const-style lints add only noise.
// ignore_for_file: prefer_const_constructors,
// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:meta/meta.dart';
import 'package:treffpunkt/features/felt/domain/felt_figure.dart';

/// One hold (station) of a field course (spec 0068): its [number], the
/// [distance], the shooting [position], and the [figures] on it.
@immutable
class FeltHoldDef {
  /// Creates a hold definition.
  const FeltHoldDef({
    required this.number,
    required this.distance,
    required this.position,
    required this.figures,
  });

  /// 1-based hold number.
  final int number;

  /// Distance label, e.g. `15 m` or `25 / 15 m`.
  final String distance;

  /// Shooting position (stilling).
  final String position;

  /// The figures on the hold, in order.
  final List<FeltFigure> figures;
}

/// The NorgesFelt 2026 course (spec 0068), reconstructed from norgesfelt.no:
/// 8 holds, inner zone on every figure, 10 s shooting time, max 80/47 points.
final List<FeltHoldDef> norgesfelt2026 = <FeltHoldDef>[
  FeltHoldDef(
    number: 1,
    distance: '15 m',
    position: 'Stående 1 hånd',
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
