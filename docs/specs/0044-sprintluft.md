<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0044 — Sprintluft (NSF recruit air-pistol program)

- **Status:** Accepted
- **Related:** spec 0043 (Storluft, the same air-duel face), reference
  [program catalogue](../reference/program-catalogue.md)

## Context

**Sprintluft** is an NSF recruit air-pistol program — shorter and easier than the
full 10 m air-pistol match, meant to reduce the gap between shooters. Per the NSF
*Nasjonalt regelverk for pistol*: it largely resembles 10 m air pistol but is
**30 shots in 15 minutes** (plus 5 sighters) on an **air-duel target** (with a
different point division than the standard face). It is the "sprint" counterpart
to Storluft (spec 0043), which uses the same face.

## Requirements

1. **One offered program** `Sprintluft`, air pistol, **30 shots as six paper
   targets of five shots each (6×5)**, integer + inner-ten (X), on the larger
   Sprintluft / luftduell face (rings 5–10), resolvable by name and offered in
   the picker.

## Design

- Reuse `TargetGeometry.airDuel10m()` (added in spec 0043 for Storluft).
- A single `ProgramDefinition` `sprintluft` with one **6×5** match stage
  (`shotsPerSeries: 5`, `seriesCount: 6`), added to `ProgramCatalogue.all`. In
  the model a series is one target face, so 6×5 is six paper targets of five
  shots. The 15-minute match time is overall, not per-series, so no
  `secondsPerSeries` is set; the 5 sighters are not modelled.

## Rationale

The father (NSF domain expert) confirmed the competition rule this spec had
flagged as open: **each paper competition target takes at most five shots**, so a
30-shot match is fired across **at least six targets** — 6×5, not the 3×10 that
was originally assumed from the 10 m air-pistol convention. Since the model's
"series" is exactly one target face, `shotsPerSeries: 5` / `seriesCount: 6`
records the session the way it is physically shot (six papers swapped in turn).
The face and scoring already exist from Storluft.

## Verification

- **Unit (`program_catalogue_test`):** Sprintluft is 30 shots in 6×5, pistol, on
  the air-duel face (rings 5–10, same face as Storluft), in `all`, resolvable by
  name.
- The air-duel face's scoring is covered by `air_duel_scoring_test` (spec 0043).
- **Gates:** format, `analyze --fatal-infos`, full test, reuse, `mkdocs
  --strict`.

## History

- The original seeding used 3×10, following the 10 m air-pistol series
  convention, and flagged the split as *to confirm with the father* (the source
  gave only "30 skudd … 15 min", not a per-target breakdown). He confirmed the
  real rule — max 5 shots per paper target, so ≥6 targets — and this spec was
  updated to 6×5 (2026-07). The other air-pistol programs are being reviewed
  separately for the same per-target rule.
- Sprintluft may also be shot on a standard air-pistol target as a substitute —
  only the named (air-duel) face is seeded.
