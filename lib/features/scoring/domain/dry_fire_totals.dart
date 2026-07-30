// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_weapon.dart';

/// The cumulative trigger-pull totals of a dry-fire log (spec 0161, spec 0166).
///
/// A pure fold of a `List<DryFireEntry>` into the per-discipline sums (spec
/// 0161) and the per-weapon sums plus a *without-weapon* sum for entries
/// recorded before the weapon was tracked (spec 0166). Empty input yields
/// all-zero totals.
@immutable
class DryFireTotals {
  /// Sums [entries] into per-discipline and per-weapon totals.
  factory DryFireTotals.of(Iterable<DryFireEntry> entries) {
    final byDiscipline = <DryFireDiscipline, int>{
      for (final discipline in DryFireDiscipline.values) discipline: 0,
    };
    final byWeapon = <DryFireWeapon, int>{
      for (final weapon in DryFireWeapon.values) weapon: 0,
    };
    var withoutWeapon = 0;
    for (final entry in entries) {
      byDiscipline[entry.discipline] =
          byDiscipline[entry.discipline]! + entry.triggerPulls;
      final weapon = entry.weapon;
      if (weapon == null) {
        withoutWeapon += entry.triggerPulls;
      } else {
        byWeapon[weapon] = byWeapon[weapon]! + entry.triggerPulls;
      }
    }
    return DryFireTotals._(
      Map.unmodifiable(byDiscipline),
      Map.unmodifiable(byWeapon),
      withoutWeapon,
    );
  }

  const DryFireTotals._(this._byDiscipline, this._byWeapon, this.withoutWeapon);

  final Map<DryFireDiscipline, int> _byDiscipline;
  final Map<DryFireWeapon, int> _byWeapon;

  /// The total trigger pulls on entries with no recorded weapon (spec 0166).
  final int withoutWeapon;

  /// The total trigger pulls recorded for [discipline].
  int forDiscipline(DryFireDiscipline discipline) =>
      _byDiscipline[discipline] ?? 0;

  /// The total trigger pulls recorded with [weapon] (spec 0166).
  int forWeapon(DryFireWeapon weapon) => _byWeapon[weapon] ?? 0;

  /// The total trigger pulls across every discipline.
  ///
  /// Folded over all entries (every entry has a discipline), so a
  /// weapon-less entry is still counted — the per-weapon sums plus
  /// [withoutWeapon] reconcile to this.
  int get grandTotal =>
      _byDiscipline.values.fold(0, (sum, count) => sum + count);

  /// Whether nothing has been recorded yet.
  bool get isEmpty => grandTotal == 0;
}
