# Spec 0005 — 25 m pistol target and scoring

- **Status:** Accepted
- **Discipline:** ISSF / NSF 25 m pistol — precision (presisjon) and rapid /
  duel (duell) faces
- **Related:** Spec 0001 (10 m air-rifle target & scoring), spec 0004 (program,
  series & scoring), ADR-0004 (spec-driven + TDD), ADR-0012 (session domain
  model), `docs/reference/program-catalogue.md`

## Context

The 25 m pistol programs (finpistol, grovpistol, standardpistol, hurtigpistol
and the duel stage of sport pistol) are shot on two concentric-ring faces: a
**precision** face with rings 1–10, and a **rapid / duel** face that shows only
rings 5–10 on a larger silhouette. Their geometry already lives in code —
`TargetGeometry.pistol25mPrecision({caliber})` and
`TargetGeometry.pistol25mRapid({caliber})` — seeded for the program catalogue
(spec 0004 / ADR-0012) and rendered by the series screen (spec 0006).

What was missing is the formal spec: the *Rationale* and *Verification* that
spec 0001 set as the standard for every scored face. This document writes that
spec and locks the existing numbers behind a vector table, exactly as spec 0001
does for the 10 m air-rifle face, so the geometry can never silently drift. It
adds no new behaviour and changes no code.

## Requirements

1. The two 25 m pistol faces match the ISSF / NSF geometry:
   - **precision** — rings 1–10, 10-ring ⌀ 50 mm, a 50 mm diameter step out to
     ring 1 (⌀ 500 mm), inner ten ("X") ⌀ 25 mm, black ⌀ 200 mm;
   - **rapid / duel** — rings 5–10 only, 10-ring ⌀ 100 mm, an 80 mm diameter
     step out to ring 5 (⌀ 500 mm), inner ten ⌀ 50 mm, black ⌀ 500 mm (the whole
     face is black).
2. Scoring is **integer + inner ten** (no decimal): each shot scores a whole
   ring 1–10 (precision) or 5–10 (rapid), and is additionally flagged as an
   inner ten ("X") when it falls inside the inner-ten ring. The inner-ten count
   is a tie-break, not a higher score.
3. A shot outside the lowest scored ring is a **miss** (0): for precision,
   beyond the 1-ring; for rapid, beyond the 5-ring (there are no rings 1–4).
4. Scoring applies the **gauge** (inward-edge) rule with the calibre's edge:
   ⌀ 5.6 mm for .22 LR (rimfire) and ⌀ 9.65 mm for centre-fire. A wider bullet
   reaches one ring further out at the same centre distance.
5. The logic is pure Dart with no Flutter dependency, reusing the generalised
   `TargetGeometry` + `ScoringService` from spec 0004, so it is unit-testable in
   isolation.

## Domain facts (ISSF, reprinted by NSF)

Diameters in millimetres, centre at the origin. Both faces are scored on the
same generalised `TargetGeometry`: ring outer diameters from the outermost ring
inward, an inner-ten diameter, and the calibre.

### Precision face (rings 1–10)

| Ring | 10 | 9   | 8   | 7   | 6   | 5   | 4   | 3   | 2   | 1   |
| ---- | -- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ⌀ mm | 50 | 100 | 150 | 200 | 250 | 300 | 350 | 400 | 450 | 500 |

- Each integer ring is 50 mm larger in diameter than the next (25 mm in radius).
- Inner ten ("X"): ⌀ **25 mm**.
- Aiming black ("blink"): ⌀ **200 mm** (the 7-ring outer). *(Confirm with the
  father — see below.)*
- Also used for the 50 m pistol face (same ring table); see the program
  catalogue.

### Rapid / duel face (rings 5–10)

| Ring | 10  | 9   | 8   | 7   | 6   | 5   |
| ---- | --- | --- | --- | --- | --- | --- |
| ⌀ mm | 100 | 180 | 260 | 340 | 420 | 500 |

- Rings 5–10 only; the 10-ring is ⌀ 100 mm and each ring steps 80 mm in
  diameter out to ring 5 (⌀ 500 mm). There is no ring below 5 — anything outside
  the 5-ring is a miss.
- Inner ten ("X"): ⌀ **50 mm**.
- Aiming black: ⌀ **500 mm** — the whole scored face is black. *(Confirm with
  the father.)*

### Calibre / gauge

| Calibre              | Edge ⌀  | Bullet radius |
| -------------------- | ------- | ------------- |
| .22 LR (rimfire)     | 5.6 mm  | 2.8 mm        |
| centre-fire (≤ 9.65) | 9.65 mm | 4.825 mm      |

`pistol25mPrecision` and `pistol25mRapid` default to the .22 edge (5.6 mm);
grovpistol and other centre-fire programs pass `caliber: 9.65`.

## Design

We model each face in millimetres with the centre at the origin, exactly as
spec 0001 does. A shot is the offset `(dx, dy)` in mm; its distance from centre
is `d = sqrt(dx² + dy²)`.

### Integer scoring — the gauge "next ring outward" rule

A shot scores ring *N* if the bullet's edge touches ring *N*. Equivalently, its
**centre** lies within
`scoringRadius(N) = ringOuterRadius(N) + bulletRadius`, where the bullet radius
is the calibre edge / 2. The score is the highest *N* whose
`scoringRadius(N) ≥ d`; below the lowest ring it is a miss (0). This is the same
rule and the same `ScoringService.integerScore` used by the 10 m air-rifle face
(spec 0001) and generalised in spec 0004 to a configurable `lowestRingValue`
(1 for precision, 5 for rapid).

For .22 (bullet radius 2.8 mm) the precision centre-distance thresholds are:

| Ring        | 10   | 9    | 8    | 7     | 6     | 5     | 4     | 3     | 2     | 1     | miss |
| ----------- | ---- | ---- | ---- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ---- |
| `d ≤` (mm)  | 27.8 | 52.8 | 77.8 | 102.8 | 127.8 | 152.8 | 177.8 | 202.8 | 227.8 | 252.8 | >252.8 |

and the rapid thresholds (.22):

| Ring        | 10   | 9    | 8     | 7     | 6     | 5     | miss   |
| ----------- | ---- | ---- | ----- | ----- | ----- | ----- | ------ |
| `d ≤` (mm)  | 52.8 | 92.8 | 132.8 | 172.8 | 212.8 | 252.8 | >252.8 |

### Inner ten ("X")

The inner ten is a separate flag, not a higher ring. A shot is an inner ten when
its centre lies within
`innerTenScoringRadius = innerTenRadius + bulletRadius`, applying the same gauge
rule. For .22 that is `12.5 + 2.8 = 15.3 mm` (precision) and
`25 + 2.8 = 27.8 mm` (rapid). The count of inner tens is a leaderboard tie-break
(`ScoringService.scoreSeries` already sums it); the ring score is unchanged.

### No decimal scoring

Unlike 10 m air rifle, the 25 m pistol faces are **not** scored to a decimal.
`ScoringService.decimalScore` asserts a full, evenly spaced 1..N face
(`hasUniformRings && lowestRingValue == 1`) and is never called for these faces:
the rapid face starts at ring 5, and even the precision face is scored integer +
inner ten in these programs. Both faces *do* have uniform ring spacing, so the
assert would not trip on the precision face, but the programs that use it record
integer + X, matching the catalogue.

### Why reuse the existing types rather than a bespoke pistol model

The generalised `TargetGeometry` (spec 0004) already carries everything these
faces need: a list of ring outer diameters from the outermost inward, a
`lowestRingValue`, an optional `innerTenDiameterMm`, and a calibre that feeds the
shared gauge rule. Adding the pistol faces as named constructors keeps one
scoring code path for every concentric-ring discipline, so a single set of
`ScoringService` tests guards them all. The alternative — a separate pistol
scorer — would duplicate the gauge and miss logic and risk the two drifting.

## Verification

The exact tests below prove the requirements. New geometry-locking vectors live
in `test/features/scoring/domain/pistol_target_geometry_test.dart`; existing
behavioural coverage lives in `pistol_precision_scoring_test.dart` and
`pistol_rapid_scoring_test.dart`.

### Unit tests — geometry (precision face)

`pistol_target_geometry_test.dart`, group *"25 m pistol — precision face"*:

- *geometry numbers match the ISSF precision face* — calibre 5.6 mm, bullet
  radius 2.8 mm, `lowestRingValue` 1, `highestRing` 10, ring outer ⌀ 10 = 50,
  9 = 100, 1 = 500, black ⌀ 200, inner-ten ⌀ 25, inner-ten scoring radius
  15.3 mm.

### Unit tests — scoring vectors (precision, .22; shot at distance `d`)

`pistol_target_geometry_test.dart`, *integer score across every ring*:

| `d` (mm) | ring | | `d` (mm) | ring |
| -------- | ---- |-| -------- | ---- |
| 0.00     | 10   | | 152.81   | 4    |
| 27.79    | 10   | | 177.81   | 3    |
| 27.81    | 9    | | 202.81   | 2    |
| 52.79    | 9    | | 227.81   | 1    |
| 52.81    | 8    | | 252.79   | 1    |
| 77.81    | 7    | | 252.81   | 0    |
| 102.81   | 6    | | 300.00   | 0    |
| 127.81   | 5    | |          |      |

Plus:
- *inner ten on either side of the 25 mm ring* — `d = 15.29 mm` is an inner ten,
  `d = 15.31 mm` is a plain ten (still ring 10, not an inner ten).
- *distance is radial, not per-axis, and sign-independent* — `(-18, 18)`
  (`d ≈ 25.46 mm`) scores 10; `(-40, 40)` (`d ≈ 56.57 mm`) scores 8.

### Unit tests — geometry & scoring vectors (rapid / duel face)

`pistol_target_geometry_test.dart`, group *"25 m pistol — rapid / duel face"*:

- *geometry numbers match the ISSF rapid face* — `lowestRingValue` 5,
  `highestRing` 10, ring outer ⌀ 10 = 100, 9 = 180, 5 = 500, black ⌀ 500,
  inner-ten ⌀ 50, inner-ten scoring radius 27.8 mm.
- *integer score across rings 5-10, miss below the 5-ring* (shot at `d`):

  | `d` (mm) | ring | | `d` (mm) | ring |
  | -------- | ---- |-| -------- | ---- |
  | 0.00     | 10   | | 172.81   | 6    |
  | 52.79    | 10   | | 212.81   | 5    |
  | 52.81    | 9    | | 252.79   | 5    |
  | 92.81    | 8    | | 252.81   | 0    |
  | 132.81   | 7    | |          |      |

- *inner ten on either side of the 50 mm ring* — `d = 27.79 mm` is an inner ten,
  `d = 27.81 mm` is a plain ten.

### Unit tests — gauge / calibre edge rule

`pistol_target_geometry_test.dart`, group *"gauge / calibre edge rule"*:

- *centre-fire 9.65 mm gauge scores wider than a .22* — a centre-fire face
  (`caliber: 9.65`, bullet radius 4.825 mm) scores `d = 29.8 mm` as a **ten**
  (ten radius 29.825 mm), while a .22 face scores the same shot as a **nine**;
  likewise the centre-fire inner-ten radius is 17.325 mm, so `d = 17.3 mm` is an
  inner ten for centre-fire but not for .22.

### Existing behavioural tests (kept)

`pistol_precision_scoring_test.dart` and `pistol_rapid_scoring_test.dart` already
exercise `integerScore` / `isInnerTen` across the rings and the inner-ten
boundary on each face; they remain green and complement the new vector table.

## Open questions / confirm with the father (NSF)

The ring geometry is sourced verbatim from the **ISSF Technical Rules §6.3.4**
(NSF reprints the same tables) — high confidence, cross-checked against the
program catalogue. The following NSF-specific details should still be confirmed
against the NSF *Skytterboka* / a live NSF rulebook, mirroring the
confirm-with-the-father flags in `docs/reference/program-catalogue.md`. None of
these affect ring scoring; do **not** change the geometry on a guess.

- [ ] **Black diameter, precision face** — asserted ⌀ 200 mm (7-ring outer).
      Confirm the exact NSF black for finpistol / standardpistol.
- [ ] **Black diameter, rapid face** — asserted "whole face black" (⌀ 500 mm).
      Confirm against the NSF silhouette / duel face.
- [ ] **Centre-fire calibre edge** — asserted ⌀ 9.65 mm for grovpistol. Confirm
      the exact gauge NSF uses for centre-fire (7.62–9.65 mm class).
- [ ] **Inner-ten / X usage** — confirm whether the inner ten is recorded (and
      counts as a tie-break) for every 25 m pistol program, or only some
      (catalogue currently flags X for all).
- [ ] **50 m pistol reuse** — confirm the precision ring table is used unchanged
      for the 50 m fripistol face (catalogue groups them).
