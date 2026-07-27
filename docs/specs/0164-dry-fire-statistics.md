<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0164 — Tørrtrening-statistikk (volum over tid)

- **Status:** Draft
- **Related:** spec 0161 (the dry-fire log), spec 0162 (its sync), spec 0090
  (the Statistikk progress chart this sits beside)

## Summary

The Statistikk screen charts how a shooter's *scores* trend over time. Dry-fire
has no score — what matters is **volume**, how much you practise — so this adds a
compact **Tørrtrening** section there showing trigger-pull volume per week over
the recent weeks, plus the all-time totals per discipline. It is the last
planned increment of the dry-fire feature (log → sync → history → statistics).

## Requirements

1. When there is dry-fire data, the Statistikk screen shows a Tørrtrening
   section with the trigger-pull volume for each of the last N weeks (a small
   bar per week) and the all-time totals per discipline.
2. With dry-fire data but no scored sessions, the section still shows (the
   screen is not the scores-only empty state).
3. With no dry-fire data, the section is absent and the screen is unchanged.

## Rationale

- **Volume, not score.** A dry-fire bout has no points, so it cannot join the
  score progression chart (spec 0090). Weekly trigger-pull volume is the honest
  measure of practice and the one a shooter would want to watch trend.
- **Beside the chart, not instead of it.** The section sits below the existing
  progress chart, shown only when there is dry-fire data — so screens with only
  scored sessions are untouched, and the scored chart keeps its space.
- **A pure weekly fold.** `dryFireWeeklyVolume` folds the entries into fixed,
  evenly-spaced week buckets (empty weeks kept as zero) so the bars are
  unit-testable and read as a real time series, not just the weeks that happened
  to have entries. The reference `now` is injected, keeping it deterministic.
- **No new data.** It reads the same `dryFireLogProvider` the card and «Mine
  økter» use; the `dry_fire_entries` columns (spec 0162) already carry
  everything, so nothing is added to the store, the table, or the sync.

## Design

### Domain (`dry_fire_weekly_volume.dart`)

- `DryFireWeek` — a week bucket: `weekStart` (Monday, date-only), `presisjon`,
  `duell`, and `total`.
- `dryFireWeekStart(date)` — the Monday of `date`'s week (date-only), so bucket
  keys compare exactly regardless of time-of-day.
- `dryFireWeeklyVolume(entries, {now, weeks = 8})` — the last `weeks` buckets
  ending at `now`'s week, oldest first; entries outside the window are omitted;
  empty weeks are zero buckets.

### Presentation (`statistics_screen.dart`)

- The screen reads `dryFireLogProvider`. The scores-only empty state now shows
  only when there are neither scored exercises nor dry-fire entries.
- A `_DryFireVolumeSection` below the progress chart (when there is dry-fire
  data): a header with the all-time total, a per-discipline line
  («Presisjon N · Duell M»), and a compact row of weekly bars (heights ∝ each
  week's total) captioned as the last N weeks.

## Verification

### Unit tests

- `dry_fire_weekly_volume_test`: always returns exactly `weeks` buckets oldest
  first ending at `now`'s week; sums the current week per discipline; buckets a
  previous week separately; omits entries older than the window.

### Widget tests

- `statistics_screen_test`: with dry-fire entries, the Tørrtrening section
  renders with the all-time total; with dry-fire but no scored sessions, the
  section shows instead of the empty state; with no dry-fire, the section is
  absent.

### System / visual

- Rendered on Statistikk beneath the chart, light and dark, signed off before
  merge.

## Open questions

- None. Per-week (not per-day/month) and an 8-week window are sensible defaults;
  a range selector can come later if wanted.
