// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// The score of a single placed shot.
class ShotScore {
  /// Creates a shot score of [ring] points, flagged as an inner ten if
  /// [isInnerTen], with the effective [decimal] value on a face that
  /// supports decimals (spec 0107).
  const ShotScore({
    required this.ring,
    required this.isInnerTen,
    this.decimal,
  });

  /// The whole-ring score (0 for a miss).
  final int ring;

  /// Whether the shot also counts as an inner ten ("X").
  final bool isInnerTen;

  /// The effective decimal value (e.g. 9.4) on a face that supports
  /// decimals (spec 0107), or null on other faces.
  final double? decimal;
}

/// The score of a whole series: each shot, the running total and the maximum.
class SeriesScore {
  /// Creates a series score.
  const SeriesScore({
    required this.shots,
    required this.total,
    required this.innerTens,
    required this.maxTotal,
    this.decimalTotal,
  });

  /// The score of each placed shot, in firing order.
  final List<ShotScore> shots;

  /// The sum of the placed shots' ring scores.
  final int total;

  /// How many of the placed shots are inner tens.
  final int innerTens;

  /// The highest total the full series could reach (capacity × highest ring).
  final int maxTotal;

  /// The sum of the shots' decimal values (spec 0107), or null when the
  /// face does not support decimals.
  final double? decimalTotal;
}
