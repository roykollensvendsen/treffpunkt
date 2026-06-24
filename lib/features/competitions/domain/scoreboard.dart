// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/competitions/domain/competition_result.dart';

/// Ranks a competition's [results] into a scoreboard (spec 0013): one row per
/// shooter — their **best** result — ordered best first.
///
/// A shooter who shot the program several times appears once, with their
/// highest [CompetitionResult.total] (ties broken by more inner tens, then the
/// earlier submission). The returned list is sorted best first, so the caller
/// can rank by index. Pure — no I/O — so it is unit-testable and reused by every
/// backend.
///
/// A result with no [CompetitionResult.userId] (not yet read back) is its own
/// group keyed by its id, so it is never merged with another shooter.
List<CompetitionResult> rankBestPerShooter(List<CompetitionResult> results) {
  final best = <String, CompetitionResult>{};
  for (final result in results) {
    final key = result.userId ?? 'id:${result.id}';
    final current = best[key];
    if (current == null || _isBetter(result, current)) {
      best[key] = result;
    }
  }
  return best.values.toList()..sort(_byScore);
}

/// Whether [a] is a better result than [b]: higher total, then more inner tens,
/// then the earlier submission (so a tie keeps the first one set).
bool _isBetter(CompetitionResult a, CompetitionResult b) => _byScore(a, b) < 0;

/// Best-first comparator: total desc, then inner tens desc, then captured-at
/// ascending (an earlier submission ranks ahead of an equal later one).
int _byScore(CompetitionResult a, CompetitionResult b) {
  final byTotal = b.total.compareTo(a.total);
  if (byTotal != 0) return byTotal;
  final byInnerTens = b.innerTens.compareTo(a.innerTens);
  if (byInnerTens != 0) return byInnerTens;
  final aAt = a.capturedAt;
  final bAt = b.capturedAt;
  if (aAt == null && bAt == null) return 0;
  if (aAt == null) return 1;
  if (bAt == null) return -1;
  return aAt.compareTo(bAt);
}
