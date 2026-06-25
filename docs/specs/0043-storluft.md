<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0043 — Storluft (corona-era home air-pistol program)

- **Status:** Accepted
- **Related:** spec 0035/0036 (air-pistol programs), reference
  [program catalogue](../reference/program-catalogue.md)

## Context

The domain expert asked for **«Storluft»**, an air-pistol program used during the
pandemic when ranges were closed and matches could be shot at home. It is not a
standing ISSF/NSF program; it is documented on the **FSU 2020 ranking page**
([fsu.no/issf/index2020.htm](https://www.fsu.no/issf/index2020.htm)):

> «…minne om at **Storluft** kan skytes uapprobert, også hjemme, **40 skudd på
> 50 minutter på Sprintluft-skive. (Eller vanlig skive på 5,5 meter)**»

So Storluft is the "big" home counterpart to **Sprintluft** (40 shots / 50 min
vs 30 / 15 min), shot either on the larger **Sprintluft / luftduell face** at
10 m, or on the **standard air-pistol face at the reduced distance 5.5 m**.

## Requirements

1. **Two offered programs**, both air pistol, 40 shots in **4×10**, integer +
   inner-ten (X), max 400:
   - **Storluft (luftduell-skive)** — the larger sprint/duel face (rings 5–10),
     at 10 m.
   - **Storluft (5,5 m)** — the standard 10 m air-pistol face (rings 1–10), shot
     at the reduced home distance.
2. Both resolvable by name (so stored sessions load) and offered in the picker.

## Design

- **New target face** `TargetGeometry.airDuel10m()` — the NSF Sprintluft /
  luftduell face: rings 5–10, 10-ring ⌀ 23 mm, step +26.5 mm → ring 5 ⌀ 155.5 mm,
  inner-ten ⌀ 11.5 mm, air calibre 4.5 mm. (The 5.5 m variant reuses the existing
  `airPistol10m()` face.) Scoring is the standard integer + inner-ten the engine
  already applies to rings-5–10 faces (as for the 25 m duel face).
- **Two `ProgramDefinition`s** `storluftDuel` and `storluft55m`, each a single
  4×10 match stage, added to `ProgramCatalogue.all`.
- Distance (10 m vs 5.5 m) is shooter context only; scoring depends solely on the
  face, so the two distances are modelled as the two faces above.

## Rationale

Modelling the two skiver as two programs is faithful to the rule note (each has a
different ring layout and therefore a different scored experience) and reuses the
existing scoring engine and the standard 4×10 air-pistol structure (matching
Luftpistol 40). The new face mirrors the existing rings-5–10 duel-face pattern.

## Verification

- **Unit (`program_catalogue_test`):** both programs are 40 shots in 4×10,
  pistol, on the duel face (rings 5–10) and the standard face (rings 1–10)
  respectively, are in `all`, and resolve by name; catalogue size is 12.
- **Unit (`air_duel_scoring_test`):** the new face has rings 5–10 (outer ⌀
  155.5, 10-ring ⌀ 23); a centre shot is a ten + inner ten; the gauge edge rule
  holds on the 10-ring; beyond the 5-ring is a miss.
- **Gates:** format, `analyze --fatal-infos`, full test, reuse, `mkdocs
  --strict`.

## Known limitations / to confirm with the father

The 4×10 series split and the **luftduell-face geometry** follow the project's
documented reference; the source gives only "40 skudd … på Sprintluft-skive". The
face's **black-bull diameter is cosmetic** (drawing only, not scoring) and is set
to the whole face (155.5 mm), like the 25 m duel face — worth a sanity-check.
