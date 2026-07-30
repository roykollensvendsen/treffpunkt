<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0166 — Tørrtrening-statistikk per våpen

- **Status:** Draft
- **Related:** spec 0165 (the weapon on the entry), spec 0164 (the Tørrtrening
  volume section this evolves), spec 0161 (`DryFireTotals`)

## Summary

Now that a dry-fire bout records its weapon type (spec 0165), the **Tørrtrening**
section on Statistikk shows the trigger-pull volume **per weapon type** plus the
grand total — «Luftpistol N · Finpistol M · Grovpistol K», with a running total —
so a shooter can see how their practice splits across their pistols. The weekly
volume bars (spec 0164) stay as they are.

Requested by a shooter (Roy's father): «statistikk per våpen pluss total».

## Requirements

1. `DryFireTotals` folds a log into per-weapon-type totals and a
   *without-weapon* total (legacy entries), alongside the existing per-discipline
   totals and grand total.
2. The Tørrtrening section on Statistikk shows the per-weapon-type breakdown for
   the types that have data, and «Uten våpen J» only when legacy entries exist.
3. The grand total and the weekly volume bars are unchanged (spec 0164).
4. Every recorded trigger pull is counted exactly once: the per-weapon totals
   plus the without-weapon total reconcile to the grand total.

## Rationale

- **Per weapon is the new headline; drop the look-alike line.** Spec 0164 already
  shows a muted, dot-separated «Presisjon P · Duell D» line. Adding a second,
  identically-styled «Luftpistol … · Finpistol …» line beside it would give the
  reader two partitions of the same total with nothing distinguishing them — that
  is clutter, not statistics. So this replaces the discipline line with the
  per-weapon line as the section's single breakdown. The discipline split is not
  lost: it still shows on the Hjem card and on every «Mine økter» row.
- **Volume, still not score, still weekly-agnostic bars.** Weekly bars measure
  *how much* over time and stay per-week totals (spec 0164). A per-weapon *trend*
  (stacked bars) is a real future enhancement but a larger one; the request is
  «per våpen pluss total», which the all-time per-weapon line answers directly.
- **Reconciliation is the correctness contract.** `grandTotal` is folded from all
  entries (via the discipline map, which every entry has), so legacy
  weapon-less entries are never dropped from the total even though they fold into
  *without-weapon*, not into any weapon type. The invariant
  `Σ forWeapon + withoutWeapon == grandTotal` is asserted.
- **No new data.** It reads the same `dryFireLogProvider`; the weapon is already
  on the entry (spec 0165). Nothing is added to the store, the table or the sync.

## Design

### Domain (`dry_fire_totals.dart`)

- `DryFireTotals.of` additionally folds a per-`DryFireWeapon` map and a
  `withoutWeapon` sum. New accessors: `forWeapon(DryFireWeapon)` and
  `withoutWeapon`. `grandTotal` stays a fold over all entries (unchanged), so it
  keeps counting legacy entries. `forDiscipline` is unchanged.

### Presentation (`statistics_screen.dart`)

- `_DryFireVolumeSection` replaces the «Presisjon P · Duell D» line with a
  per-weapon line built from `forWeapon` for the types with a non-zero total,
  joined by « · », with «Uten våpen J» appended only when `withoutWeapon > 0`.
  When the only data is legacy, the line is just «Uten våpen J». The grand-total
  header, the weekly bars and the caption are untouched.

## Verification

### Unit tests

- `dry_fire_totals_test` (extend): a mixed log (Luftpistol + Finpistol +
  Grovpistol + a weapon-less entry) sums each `forWeapon` correctly, sums
  `withoutWeapon` over the legacy entries, and satisfies
  `forWeapon(luftpistol) + forWeapon(finpistol) + forWeapon(grovpistol) +
  withoutWeapon == grandTotal`; an empty log yields zero for every `forWeapon`,
  `withoutWeapon` and `grandTotal`; a single-type log leaves the other types and
  `withoutWeapon` at zero; `forDiscipline` is unaffected by the weapon.

### Widget tests

- `statistics_screen_test` (extend): with a weapon-tagged log the section renders
  the per-weapon line (types with data) and **no** «Uten våpen» suffix; with a
  legacy-only log it renders just «Uten våpen J» (and the grand total is still
  correct); with a mixed log it renders both; the weekly bars and the section key
  still render.

### System / visual

- Rendered on Statistikk, light and dark, signed off before merge.

## Open questions

- None. A per-weapon weekly *trend* (stacked bars) and a per-weapon range
  selector are sensible later enhancements, not part of «per våpen pluss total».
