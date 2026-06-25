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

1. **One offered program** `Sprintluft`, air pistol, **30 shots in 3×10**,
   integer + inner-ten (X), on the larger Sprintluft / luftduell face (rings
   5–10), resolvable by name and offered in the picker.

## Design

- Reuse `TargetGeometry.airDuel10m()` (added in spec 0043 for Storluft).
- A single `ProgramDefinition` `sprintluft` with one 3×10 match stage, added to
  `ProgramCatalogue.all`. The 15-minute match time is overall, not per-series, so
  no `secondsPerSeries` is set; the 5 sighters are not modelled.

## Rationale

3×10 follows the 10 m air-pistol series convention the program resembles (the
source gives 30 shots / 15 min total, not a per-series breakdown). The face and
scoring already exist from Storluft, so this is a one-program addition.

## Verification

- **Unit (`program_catalogue_test`):** Sprintluft is 30 shots in 3×10, pistol, on
  the air-duel face (rings 5–10, same face as Storluft), in `all`, resolvable by
  name; catalogue size is 13.
- The air-duel face's scoring is covered by `air_duel_scoring_test` (spec 0043).
- **Gates:** format, `analyze --fatal-infos`, full test, reuse, `mkdocs
  --strict`.

## Known limitations / to confirm with the father

The 3×10 split follows the air-pistol convention; the source gives only "30 skudd
… 15 min". Sprintluft may also be shot on a standard air-pistol target as a
substitute — only the named (air-duel) face is seeded.
