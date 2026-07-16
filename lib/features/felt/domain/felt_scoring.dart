// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';

/// The shooter's group on a NorgesFelt course (spec 0080), which sets how many
/// shots are fired per hold.
enum FeltShooterGroup {
  /// Group 1 — six shots per hold.
  one('Gruppe 1', 6),

  /// Group 2 — five shots per hold.
  two('Gruppe 2', 5),

  /// Group 3 — five shots per hold. The class for heavier weapons: not
  /// shot on NorgesFelt (spec 0088), but offered on T96 (spec 0160), where
  /// Magnum shoots every series with two hands.
  three('Gruppe 3', 5);

  const FeltShooterGroup(this.label, this.shotsPerHold);

  /// The groups the NorgesFelt courses offer (spec 0088) — the default for
  /// a course; T96 offers Gruppe 3 as well (spec 0160).
  static const List<FeltShooterGroup> offered = <FeltShooterGroup>[one, two];

  /// The Norwegian label.
  final String label;

  /// Shots fired per hold for this group.
  final int shotsPerHold;
}

/// One recorded shot on a hold (spec 0080): the [figureIndex] it hit (null is a
/// miss) and whether it landed in that figure's [inner] zone.
@immutable
class FeltShot {
  /// Creates a shot. A miss leaves [figureIndex] null.
  const FeltShot({this.figureIndex, this.inner = false});

  /// Index of the figure hit, or null for a miss (bom).
  final int? figureIndex;

  /// Whether the shot landed in the figure's inner zone.
  final bool inner;

  /// Whether the shot hit a figure at all.
  bool get isHit => figureIndex != null;
}

/// The felt score of one hold's [shots] (specs 0080/0085): one point per
/// hit and one per distinct figure hit. On NorgesFelt inner-zone hits give
/// **no** points — they are counted as the tiebreaker (spec 0085); on a
/// course where [innerScores] (T96, spec 0160) each inner hit is one more
/// point (reglement-felt-t96-2026 § 8.26.5).
@immutable
class FeltHoldTally {
  /// Creates a hold tally over its recorded shots.
  const FeltHoldTally(this.shots, {this.innerScores = false});

  /// The shots placed on this hold, in order.
  final List<FeltShot> shots;

  /// Whether inner-zone hits score a point (T96, spec 0160).
  final bool innerScores;

  /// Hits — shots that landed on a figure.
  int get treff => shots.where((s) => s.isHit).length;

  /// Distinct figures hit on the hold.
  int get figures =>
      shots.where((s) => s.isHit).map((s) => s.figureIndex).toSet().length;

  /// Inner-zone hits — the tiebreaker (spec 0085), and a point each where
  /// [innerScores] (spec 0160).
  int get inner => shots.where((s) => s.inner).length;

  /// Points: [treff] + [figures], plus [inner] only where [innerScores].
  int get points => treff + figures + (innerScores ? inner : 0);
}

/// A whole felt session (spec 0080): the shooter's [group] and the per-hold
/// tallies, with the session total.
@immutable
class FeltSessionTally {
  /// Creates a session tally.
  const FeltSessionTally({required this.group, required this.holds});

  /// The shooter's group.
  final FeltShooterGroup group;

  /// The per-hold tallies, in course order.
  final List<FeltHoldTally> holds;

  /// The session total across all holds.
  int get points => holds.fold(0, (sum, h) => sum + h.points);

  /// Inner-zone hits across all holds — the tiebreaker when two shooters
  /// have equal [points]: the most inner hits wins (spec 0085).
  int get inner => holds.fold(0, (sum, h) => sum + h.inner);
}
