// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// The score of a single placed shot.
class ShotScore {
  /// Creates a shot score of [ring] points, flagged as an inner ten if
  /// [isInnerTen].
  const ShotScore({required this.ring, required this.isInnerTen});

  /// The whole-ring score (0 for a miss).
  final int ring;

  /// Whether the shot also counts as an inner ten ("X").
  final bool isInnerTen;
}

/// The score of a whole series: each shot, the running total and the maximum.
class SeriesScore {
  /// Creates a series score.
  const SeriesScore({
    required this.shots,
    required this.total,
    required this.innerTens,
    required this.maxTotal,
  });

  /// The score of each placed shot, in firing order.
  final List<ShotScore> shots;

  /// The sum of the placed shots' ring scores.
  final int total;

  /// How many of the placed shots are inner tens.
  final int innerTens;

  /// The highest total the full series could reach (capacity × highest ring).
  final int maxTotal;
}
