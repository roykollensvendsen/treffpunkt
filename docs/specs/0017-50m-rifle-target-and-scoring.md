# Spec 0017 — 50 m rifle target and scoring

- **Status:** Accepted
- **Discipline:** ISSF / NSF 50 m rifle (smallbore / miniatyrrifle, .22 LR)
- **Related:** Spec 0001 (10 m air-rifle target & scoring), spec 0004 (program,
  series & scoring), spec 0005 (25 m pistol target & scoring), ADR-0004
  (spec-driven + TDD), ADR-0012 (session domain model),
  `docs/reference/program-catalogue.md`

## Context

The 50 m rifle (smallbore, .22 LR) is one of the classic ISSF rifle disciplines
— shot prone or three-position on a single concentric-ring face at 50 m. It is
the next official rifle face Treffpunkt records after the 10 m air rifle
(spec 0001). This spec defines the target geometry and pins it behind a vector
table, exactly as spec 0001 does for air rifle and spec 0005 does for the 25 m
pistol faces, so the numbers can never silently drift.

The face is added as a named `TargetGeometry.smallbore50m()` constructor reusing
the generalised geometry + scoring from spec 0004; it shares the one scoring
code path with every other concentric-ring discipline. A representative ISSF
program ("50 m Rifle Prone", 60 shots in six 10-shot series) is seeded into the
catalogue with integer + inner-ten scoring. The *exact NSF* course of fire and
scoring style are recorded as confirm-with-the-father flags, not seeded as fact.

## Requirements

1. The 50 m rifle face matches the ISSF geometry: rings 1–10, 10-ring ⌀ 10.4 mm,
   a uniform 16 mm diameter step out to ring 1 (⌀ 154.4 mm), inner ten ("X")
   ⌀ 5.0 mm, black ⌀ 112.4 mm (render-only, not scoring).
2. Scoring is **integer + inner ten** (no decimal): each shot scores a whole
   ring 1–10 and is additionally flagged as an inner ten ("X") when its centre
   falls inside the inner-ten ring. The inner-ten count is a tie-break, not a
   higher score.
3. A shot outside the 1-ring is a **miss** (0).
4. Scoring applies the **gauge** (inward-edge) rule with the calibre's edge:
   ⌀ 5.6 mm for .22 LR. A shot scores ring *N* when its centre lies within
   `ringOuterRadius(N) + bulletRadius`.
5. The logic is pure Dart with no Flutter dependency, reusing the generalised
   `TargetGeometry` + `ScoringService` from spec 0004, so it is unit-testable in
   isolation. No existing geometry or the scorer is changed.

## Domain facts (ISSF Technical Rules §6.3.4)

Diameters in millimetres, centre at the origin. The ring outer diameters are
ordered from the outermost ring (1) inward to the innermost (10), matching the
`TargetGeometry.ringOuterDiametersMm` convention
(`outerDiameterMm(ring) == ringOuterDiametersMm[ring - lowestRingValue]`).

| Ring | 10   | 9    | 8    | 7    | 6    | 5    | 4     | 3     | 2     | 1     |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- | ----- | ----- | ----- | ----- |
| ⌀ mm | 10.4 | 26.4 | 42.4 | 58.4 | 74.4 | 90.4 | 106.4 | 122.4 | 138.4 | 154.4 |

- Each integer ring is 16 mm larger in diameter than the next (8 mm in radius).
  The ring spacing is uniform — `hasUniformRings` is true.
- Inner ten ("X"): ⌀ **5.0 mm**.
- Aiming black ("blink"): ⌀ **112.4 mm** — covers roughly rings 4–10. Render-only,
  not used in scoring. *(Confirm with the father — see below.)*
- Calibre / gauge: **.22 LR** (rimfire), edge ⌀ **5.6 mm**, bullet radius 2.8 mm.

## Design

We model the face in millimetres with the centre at the origin, exactly as
spec 0001 and spec 0005 do. A shot is the offset `(dx, dy)` in mm; its distance
from centre is `d = sqrt(dx² + dy²)`.

### Integer scoring — the gauge "next ring outward" rule

A shot scores ring *N* if the bullet's edge touches ring *N*. Equivalently, its
**centre** lies within `scoringRadius(N) = ringOuterRadius(N) + bulletRadius`,
where the bullet radius is the calibre edge / 2 (2.8 mm for .22). The score is
the highest *N* whose `scoringRadius(N) ≥ d`; outside the 1-ring it is a miss
(0). This is the same `ScoringService.integerScore` used by every other
concentric-ring face. Because the rings are evenly spaced, the .22 centre-distance
thresholds fall on a clean 8 mm grid:

| Ring       | 10  | 9    | 8    | 7    | 6    | 5    | 4    | 3    | 2    | 1    | miss |
| ---------- | --- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| `d ≤` (mm) | 8.0 | 16.0 | 24.0 | 32.0 | 40.0 | 48.0 | 56.0 | 64.0 | 72.0 | 80.0 | >80  |

### Inner ten ("X")

The inner ten is a separate flag, not a higher ring. A shot is an inner ten when
its centre lies within `innerTenScoringRadius = innerTenRadius + bulletRadius`,
applying the same gauge rule. For .22 that is `2.5 + 2.8 = 5.3 mm`. The count of
inner tens is a leaderboard tie-break (`ScoringService.scoreSeries` already sums
it); the ring score is unchanged.

### Scoring style — integer + inner ten in the seeded program

The seeded "50 m Rifle Prone" program records **integer + inner ten**, mirroring
the ISSF qualification round and the 25 m pistol programs (spec 0005). The face
*does* have uniform ring spacing (so `ScoringService.decimalScore` would not trip
its `hasUniformRings && lowestRingValue == 1` assert), but whether NSF scores
50 m rifle to a decimal — and the exact NSF course of fire — is a
confirm-with-the-father flag below, so the program is seeded integer + X and the
decimal question is left open rather than guessed.

### Why reuse the existing types rather than a bespoke rifle model

The generalised `TargetGeometry` (spec 0004) already carries everything this
face needs: a list of ring outer diameters from the outermost inward, an optional
`innerTenDiameterMm`, and a calibre that feeds the shared gauge rule. Adding the
50 m face as a named constructor keeps one scoring code path for every
concentric-ring discipline, so a single set of `ScoringService` tests guards them
all. A separate rifle scorer would duplicate the gauge and miss logic and risk
the two drifting.

## Verification

The exact tests below prove the requirements. New geometry-locking vectors live
in `test/features/scoring/domain/rifle_50m_target_geometry_test.dart`. They do
not change the geometry or the scorer; spec 0001's air-rifle vectors and
spec 0005's pistol vectors remain green.

### Unit tests — geometry

`rifle_50m_target_geometry_test.dart`, group *"50 m rifle face"*:

- *geometry numbers match the ISSF 50 m rifle face* — name `'50 m Rifle'`,
  calibre 5.6 mm, bullet radius 2.8 mm, `lowestRingValue` 1, `highestRing` 10;
  ring outer ⌀ 1 = 154.4 (outermost), 10 = 10.4 (innermost), 9 = 26.4, 4 = 106.4
  — proving the outermost-to-innermost ordering of `ringOuterDiametersMm`;
  `hasUniformRings` true; black ⌀ 112.4, inner-ten ⌀ 5, inner-ten scoring radius
  5.3 mm.

### Unit tests — scoring vectors (.22; shot at distance `d` from centre)

`rifle_50m_target_geometry_test.dart`, *integer score across every ring, both
sides of the boundary* (offsets nudged ±0.01 mm off the exact radius):

| `d` (mm) | ring | | `d` (mm) | ring |
| -------- | ---- |-| -------- | ---- |
| 0.00     | 10   | | 48.01    | 4    |
| 7.99     | 10   | | 56.01    | 3    |
| 8.01     | 9    | | 64.01    | 2    |
| 15.99    | 9    | | 72.01    | 1    |
| 16.01    | 8    | | 79.99    | 1    |
| 24.01    | 7    | | 80.01    | 0    |
| 32.01    | 6    | | 100.00   | 0    |
| 40.01    | 5    | |          |      |

Plus:
- *inner ten on either side of the 5 mm ring* — `d = 5.29 mm` is an inner ten,
  `d = 5.31 mm` is a plain ten (still ring 10, not an inner ten).
- *distance is radial, not per-axis, and sign-independent* — `(-5, 5)`
  (`d ≈ 7.07 mm`) scores 10; `(-12, 12)` (`d ≈ 16.97 mm`) scores 8.

### System / integration tests

None added: this spec adds geometry and a catalogue entry only. The existing
guided-flow integration tests exercise the shared series / scorecard path that
this face reuses unchanged.

## Open questions / confirm with the father (NSF)

The ring geometry is sourced verbatim from the **ISSF Technical Rules §6.3.4**
(NSF reprints the same tables) — high confidence, cross-checked against the
program catalogue. The following NSF-specific details should still be confirmed
against the NSF *Skytterboka* / a live NSF rulebook, mirroring the
confirm-with-the-father flags in `docs/reference/program-catalogue.md`. None of
these affect ring scoring; do **not** change the geometry on a guess.

- [ ] **Course of fire** — the seeded program is "50 m Rifle Prone", 60 shots in
      6×10. Confirm the exact NSF course(s): 60 prone, 3×20 (60-shot
      three-position) or the full 3×40 (120-shot) match, and any women / junior /
      veteran reductions.
- [ ] **Decimal vs integer scoring** — the program is seeded integer + inner ten.
      Confirm whether NSF scores 50 m rifle prone to a decimal (as electronic
      targets / ISSF finals do) or to whole rings + X in club matches.
- [ ] **Black diameter** — asserted ⌀ 112.4 mm (covers roughly rings 4–10).
      Confirm the exact NSF black for the 50 m rifle face (render-only).
- [ ] **Calibre** — asserted .22 LR (edge ⌀ 5.6 mm). Confirm this is the only
      permitted calibre / weapon class for the NSF 50 m rifle programs.
