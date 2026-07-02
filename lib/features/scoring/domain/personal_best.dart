// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// One comparable exercise result (spec 0101): points first, inner hits as
/// the tiebreak — the `poeng + innertreff` order Norwegian shooters rank by
/// (spec 0085).
typedef ExerciseResult = ({int points, int inner});

/// Whether [result] is a **new** personal best against the [prior] results
/// of the same exercise (spec 0101): strictly better — lexicographically on
/// (points, inner) — than *every* prior result. Equalling the old best is
/// not a new best, and a first-ever result (empty [prior]) has beaten
/// nothing, so it is not one either.
bool isNewPersonalBest({
  required ExerciseResult result,
  required Iterable<ExerciseResult> prior,
}) {
  var any = false;
  for (final p in prior) {
    any = true;
    final beaten =
        result.points > p.points ||
        (result.points == p.points && result.inner > p.inner);
    if (!beaten) return false;
  }
  return any;
}

/// The lexicographically greatest of [results] — the shooter's *effective*
/// record when fed the manual baseline plus every recorded session of an
/// exercise (spec 0102) — or null when [results] is empty.
ExerciseResult? bestResult(Iterable<ExerciseResult> results) {
  ExerciseResult? best;
  for (final r in results) {
    final b = best;
    if (b == null ||
        r.points > b.points ||
        (r.points == b.points && r.inner > b.inner)) {
      best = r;
    }
  }
  return best;
}
