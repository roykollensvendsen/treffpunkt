<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0035 — 10 m air pistol, 40 shots

- **Status:** Accepted
- **Related:** spec 0001 (10 m target & scoring), spec 0004 (program / series),
  spec 0031 (Hurtigpistol & NAIS — the same catalogue-addition pattern),
  `docs/reference/program-catalogue.md`

## Context

The catalogue offers 10 m air pistol only as the **60-shot** ISSF match
(`airPistol10m`, six 10-shot series). But NSF shoots air pistol as **40 shots**
for women, veterans and juniors (and in many club/class competitions), on the
same target. A shooter in those classes has no matching program. This adds the
40-shot program as a sibling of the 60-shot one — no new target, scoring or
weapon concept, just a second program over the existing 10 m air-pistol face.

## Requirements

1. **A 40-shot air-pistol program.** `10 m Luftpistol 40 skudd`: four 10-shot
   series (40 shots, max 400), on the existing `TargetGeometry.airPistol10m()`
   face, weapon class `Air 4.5 mm` — identical to the 60-shot program except the
   series count.
2. **Offered and resolvable.** It appears in the program picker (`all`) and
   resolves by its unique name (`byName`), so a saved session reloads.
3. **The 60-shot program is unchanged.**

## Design

Add `ProgramCatalogue.airPistol10m40` (one `Match` stage, `shotsPerSeries: 10`,
`seriesCount: 4`) and register it in `all`, right after `airPistol10m`
(`lib/features/scoring/domain/program_catalogue.dart`). Scoring, target and the
inner ten are exactly the 60-shot program's — only the total shots differ — so no
scoring or geometry change is needed (spec 0001 / 0004 already cover them).

## Rationale

This mirrors the spec-0031 additions: a national format expressed purely as a new
`ProgramDefinition` over existing geometry, so it is a tiny, well-tested change
with no new scoring surface. Reusing the same air-pistol face keeps the 40- and
60-shot results directly comparable per series.

## Verification

### Unit (`program_catalogue_test.dart`)
- the catalogue offers **10** programs (was 9), all pistol.
- `airPistol10m40`: four series of ten = 40 total shots, max 400, on the air
  pistol face, weapon class `Air 4.5 mm`; resolvable by name; distinct from the
  60-shot `airPistol10m`.

### Manual
Pick `10 m Luftpistol 40 skudd` in the picker and shoot a full session: four
series of ten, scorecard totals out of 400.

## Known limitations / next increment

Whole-ring vs decimal scoring follows the shared 10 m air-pistol behaviour (spec
0001); a class-specific decimal-only rule, if ever needed, is a later change.
