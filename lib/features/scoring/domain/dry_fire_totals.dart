// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';

/// The cumulative trigger-pull totals of a dry-fire log (spec 0161).
///
/// A pure fold of a `List<DryFireEntry>` into the per-discipline sums the
/// Tørrtrening card shows. Empty input yields all-zero totals.
@immutable
class DryFireTotals {
  /// Sums [entries] into per-discipline totals.
  factory DryFireTotals.of(Iterable<DryFireEntry> entries) {
    final byDiscipline = <DryFireDiscipline, int>{
      for (final discipline in DryFireDiscipline.values) discipline: 0,
    };
    for (final entry in entries) {
      byDiscipline[entry.discipline] =
          byDiscipline[entry.discipline]! + entry.triggerPulls;
    }
    return DryFireTotals._(Map.unmodifiable(byDiscipline));
  }

  const DryFireTotals._(this._byDiscipline);

  final Map<DryFireDiscipline, int> _byDiscipline;

  /// The total trigger pulls recorded for [discipline].
  int forDiscipline(DryFireDiscipline discipline) =>
      _byDiscipline[discipline] ?? 0;

  /// The total trigger pulls across every discipline.
  int get grandTotal =>
      _byDiscipline.values.fold(0, (sum, count) => sum + count);

  /// Whether nothing has been recorded yet.
  bool get isEmpty => grandTotal == 0;
}
