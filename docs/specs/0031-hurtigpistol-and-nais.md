<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0031 — Hurtigpistol fin/grov and NAIS

- **Status:** Accepted
- **Related:** spec 0004 (program/series model), spec 0005 (25 m pistol target &
  scoring), spec 0023 (per-series results), `docs/reference/program-catalogue.md`

## Context

The catalogue offers air pistol, standard pistol, finpistol, grovpistol and
fripistol. The NSF domain expert asked for two more national 25 m pistol
programs: **Hurtigpistol** (rapid fire) in **fin** and **grov**, and **NAIS** in
**fin** and **grov**. Both are shot on the **international duel target** — the
same larger-ringed face the existing *Duell* stages already use
(`TargetGeometry.pistol25mRapid()`, rings 5–10) — so no new geometry is needed;
this spec adds the four `ProgramDefinition`s and their stage structure.

The structures are taken from authoritative NSF material (not guessed): the NSF
*Skyteprogrammer – Pistol* (§8.26 Hurtigpistol, §8.29 NAIS) and the NSF
*Reglement for merkeskyting til NAIS-medaljen*. They are reflected 1:1 in
`docs/reference/program-catalogue.md`.

## Requirements

1. **Hurtigpistol fin & grov — 60 shots, twelve 5-shot series, timed.** Three
   stages of four 5-shot series each on the duel face: **10 s**, **8 s**, **6 s**
   per series (the optional sighting series is not recorded). `fin` is rimfire
   (.22, `caliberMm` 5.6); `grov` is centre-fire (.32–.38, `caliberMm` 9.65).
   Total 60, max 600.
2. **NAIS fin & grov — 30 shots, six 5-shot series.** Four stages on the duel
   face: **Presisjon 150 s** (2 series), **Duell** (2 series, 3 s exposures),
   **20 s** (1 series), **10 s** (1 series). `fin` is .22–.32 (`caliberMm` 5.6);
   `grov` is .38–.45 (`caliberMm` 9.65). Total 30, max 300. (The five sighting
   shots are not recorded.)
3. **Reuse the existing face and weapon classes.** Every stage uses
   `TargetGeometry.pistol25mRapid()` (the duel face). Programs reference only
   seeded weapon classes — `.22 LR` for fin, `Centre-fire 7.62–9.65 mm` for grov
   — so the weapon-catalogue coverage invariant holds; the precise grov calibre
   range is documented here and in the catalogue reference rather than as a new
   weapon class.
4. **Offered and resolvable.** All four are added to `ProgramCatalogue.all`
   (offered in the picker) and therefore resolvable by name (spec 0009), so a
   recorded session reloads. Integer + inner-ten scoring and the per-series
   (skive) breakdown (spec 0023) apply unchanged.

## Rationale

Both programs are shot entirely on the duel face the catalogue already models, so
the smallest correct change is four new `ProgramDefinition`s — no geometry, no
scoring change. Modelling the timed segments as **stages** (named by their time)
mirrors how Standardpistol is already represented and gives the shooter the
per-stage and per-series breakdown for free (spec 0023). Timings are carried on
`StageDefinition.secondsPerSeries` (already used by Standardpistol) so the
structure is faithful even though the app does not yet enforce a clock. Reusing
the seeded weapon classes (rather than inventing grov calibre sub-classes) keeps
the weapon model small and the coverage invariant intact; the authoritative
calibre ranges live in the spec and the catalogue reference.

## Verification

### Unit tests (`program_catalogue_test.dart`)

- *the catalogue seeds the real pistol programs* — `ProgramCatalogue.all` now has
  **9** programs, all pistol.
- *hurtigpistol fin/grov: 12 series of 5 on the duel face, timed* — both programs
  are 60 shots across three stages of `seriesCount` 4, `secondsPerSeries`
  `[10, 8, 6]`, every stage on the duel face (`lowestRingValue == 5`); fin
  `caliberMm` 5.6, grov 9.65.
- *NAIS fin/grov: 30 shots in six series on the duel face* — both are 30 shots
  across four stages with `seriesCount` `[2, 2, 1, 1]` and `secondsPerSeries`
  `[150, null, 20, 10]`, every stage on the duel face; fin `caliberMm` 5.6, grov
  9.65.
- *byName* resolves every seeded program by its own name (the four new ones
  included).

### Manual

- The four programs appear in the picker; shooting one to completion produces a
  scorecard with the right per-stage and per-series breakdown and a max of
  600 (hurtig) / 300 (NAIS).

## Sources

- NSF *Skyteprogrammer – Pistol*, §8.26 (Hurtigpistol fin/grov) and §8.29
  (NAIS).
- NSF *Reglement for merkeskyting til NAIS-medaljen* (vedtatt 1.10.95, endret
  2004): 25 m on duel target, 6 × 5 = 30 shots, fin/grov classes.
