// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// The rolled-up score of one stage (its sealed series summed).
class StageScore {
  /// Creates a stage score.
  const StageScore({
    required this.total,
    required this.innerTens,
    required this.maxTotal,
  });

  /// Sum of the stage's ring scores so far.
  final int total;

  /// How many inner tens were shot in the stage.
  final int innerTens;

  /// The highest total the stage could reach (its shots × the highest ring).
  final int maxTotal;
}

/// The score of a whole session: each stage plus the grand totals.
class SessionScore {
  /// Creates a session score.
  const SessionScore({
    required this.stages,
    required this.total,
    required this.innerTens,
    required this.maxTotal,
  });

  /// The score of each stage, in order.
  final List<StageScore> stages;

  /// Sum of every stage's ring scores.
  final int total;

  /// Total inner tens across the session.
  final int innerTens;

  /// The highest total the whole session could reach.
  final int maxTotal;
}
