// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// One comparable score: points first, inner hits as the tiebreak — the
/// `poeng + innertreff` order Norwegian shooters rank by (spec 0085).
typedef LexiScore = ({int points, int inner});

/// Compares [a] and [b] lexicographically on (points, inner): positive when
/// [a] is the greater score, negative when the lesser, zero when equal.
int compareLexiScore(LexiScore a, LexiScore b) {
  final byPoints = a.points.compareTo(b.points);
  if (byPoints != 0) return byPoints;
  return a.inner.compareTo(b.inner);
}

/// Whether [a] beats [b]: strictly greater lexicographically on
/// (points, inner). An equal score is not better.
bool isBetterLexi(LexiScore a, LexiScore b) => compareLexiScore(a, b) > 0;
