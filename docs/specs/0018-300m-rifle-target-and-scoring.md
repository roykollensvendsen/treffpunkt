# Spec 0018 — 300 m rifle target and scoring

- **Status:** Accepted
- **Discipline:** ISSF / NSF 300 m rifle (centre-fire, ≤ 8 mm)
- **Related:** Spec 0001 (10 m air-rifle target & scoring), spec 0004 (program,
  series & scoring), spec 0005 (25 m pistol target & scoring), spec 0017 (50 m
  rifle target & scoring), ADR-0004 (spec-driven + TDD), ADR-0012 (session
  domain model), `docs/reference/program-catalogue.md`

## Context

The 300 m rifle (centre-fire, full-bore) is the long-range ISSF rifle discipline
— shot prone or three-position on a single large concentric-ring face at 300 m.
It follows the 50 m rifle (spec 0017) as the next official rifle face Treffpunkt
records. This spec defines the target geometry and pins it behind a vector
table, exactly as spec 0001 does for air rifle, spec 0005 for the 25 m pistol
faces and spec 0017 for the 50 m rifle, so the numbers can never silently drift.

The face is added as a named `TargetGeometry.rifle300m()` constructor reusing
the generalised geometry + scoring from spec 0004; it shares the one scoring
code path with every other concentric-ring discipline. A representative ISSF
program ("300 m Rifle", 60 shots in six 10-shot series) is seeded into the
catalogue with integer + inner-ten scoring. The *exact NSF* course of fire,
scoring style, black and calibre are recorded as confirm-with-the-father flags,
not seeded as fact.

## Requirements

1. The 300 m rifle face matches the ISSF geometry: rings 1–10, 10-ring ⌀ 100 mm,
   a uniform 100 mm diameter step out to ring 1 (⌀ 1000 mm), inner ten ("X")
   ⌀ 50 mm, black ⌀ 600 mm (render-only, not scoring).
2. Scoring is **integer + inner ten** (no decimal): each shot scores a whole
   ring 1–10 and is additionally flagged as an inner ten ("X") when its centre
   falls inside the inner-ten ring. The inner-ten count is a tie-break, not a
   higher score.
3. A shot outside the 1-ring is a **miss** (0).
4. Scoring applies the **gauge** (inward-edge) rule with the calibre's edge: a
   centre-fire gauge defaulting to ⌀ 8 mm. A shot scores ring *N* when its centre
   lies within `ringOuterRadius(N) + bulletRadius`.
5. The logic is pure Dart with no Flutter dependency, reusing the generalised
   `TargetGeometry` + `ScoringService` from spec 0004, so it is unit-testable in
   isolation. No existing geometry or the scorer is changed.

## Domain facts (ISSF Technical Rules §6.3.4)

Diameters in millimetres, centre at the origin. The ring outer diameters are
ordered from the outermost ring (1) inward to the innermost (10), matching the
`TargetGeometry.ringOuterDiametersMm` convention
(`outerDiameterMm(ring) == ringOuterDiametersMm[ring - lowestRingValue]`).

| Ring | 10  | 9   | 8   | 7   | 6   | 5   | 4   | 3   | 2   | 1    |
| ---- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---- |
| ⌀ mm | 100 | 200 | 300 | 400 | 500 | 600 | 700 | 800 | 900 | 1000 |

- Each integer ring is 100 mm larger in diameter than the next (50 mm in radius).
  The ring spacing is uniform — `hasUniformRings` is true.
- Inner ten ("X"): ⌀ **50 mm**.
- Aiming black ("blink"): ⌀ **600 mm** — covers roughly rings 5–10. Render-only,
  not used in scoring. *(Confirm with the father — see below.)*
- Calibre / gauge: **centre-fire** (≤ 8 mm class), edge defaulting to ⌀ **8 mm**,
  bullet radius 4.0 mm. *(Confirm with the father — see below.)*

## Design

We model the face in millimetres with the centre at the origin, exactly as
spec 0001, spec 0005 and spec 0017 do. A shot is the offset `(dx, dy)` in mm;
its distance from centre is `d = sqrt(dx² + dy²)`.

### Integer scoring — the gauge "next ring outward" rule

A shot scores ring *N* if the bullet's edge touches ring *N*. Equivalently, its
**centre** lies within `scoringRadius(N) = ringOuterRadius(N) + bulletRadius`,
where the bullet radius is the calibre edge / 2 (4.0 mm for an 8 mm gauge). The
score is the highest *N* whose `scoringRadius(N) ≥ d`; outside the 1-ring it is a
miss (0). This is the same `ScoringService.integerScore` used by every other
concentric-ring face. With the default 8 mm gauge the centre-distance thresholds
are:

| Ring       | 10   | 9     | 8     | 7     | 6     | 5     | 4     | 3     | 2     | 1     | miss |
| ---------- | ---- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ---- |
| `d ≤` (mm) | 54.0 | 104.0 | 154.0 | 204.0 | 254.0 | 304.0 | 354.0 | 404.0 | 454.0 | 504.0 | >504 |

### Inner ten ("X")

The inner ten is a separate flag, not a higher ring. A shot is an inner ten when
its centre lies within `innerTenScoringRadius = innerTenRadius + bulletRadius`,
applying the same gauge rule. For the 8 mm gauge that is `25 + 4.0 = 29.0 mm`.
The count of inner tens is a leaderboard tie-break
(`ScoringService.scoreSeries` already sums it); the ring score is unchanged.

### Calibre / gauge

The 300 m face is shot with full-bore centre-fire rifles. The exact gauge edge
NSF uses for the ≤ 8 mm class is a confirm-with-the-father flag; the constructor
defaults to ⌀ 8 mm and takes a `caliber` override, exactly as the centre-fire
pistol faces do (spec 0005). A wider gauge reaches one ring further out at the
same centre distance, which the gauge-edge test exercises.

### Scoring style — integer + inner ten in the seeded program

The seeded "300 m Rifle" program records **integer + inner ten**, mirroring the
ISSF qualification round and the 25 m pistol and 50 m rifle programs. The face
*does* have uniform ring spacing, but whether NSF scores 300 m rifle to a decimal
— and the exact NSF course of fire — is a confirm-with-the-father flag below, so
the program is seeded integer + X and the decimal question is left open rather
than guessed.

### Why reuse the existing types rather than a bespoke rifle model

The generalised `TargetGeometry` (spec 0004) already carries everything this
face needs: a list of ring outer diameters from the outermost inward, an optional
`innerTenDiameterMm`, and a calibre that feeds the shared gauge rule. Adding the
300 m face as a named constructor keeps one scoring code path for every
concentric-ring discipline, so a single set of `ScoringService` tests guards them
all. A separate rifle scorer would duplicate the gauge and miss logic and risk
the two drifting.

## Verification

The exact tests below prove the requirements. New geometry-locking vectors live
in `test/features/scoring/domain/rifle_300m_target_geometry_test.dart`. They do
not change the geometry or the scorer; spec 0001's air-rifle vectors, spec 0005's
pistol vectors and spec 0017's 50 m rifle vectors remain green.

### Unit tests — geometry

`rifle_300m_target_geometry_test.dart`, group *"300 m rifle face"*:

- *geometry numbers match the ISSF 300 m rifle face* — name `'300 m Rifle'`,
  calibre 8.0 mm, bullet radius 4.0 mm, `lowestRingValue` 1, `highestRing` 10;
  ring outer ⌀ 1 = 1000 (outermost), 10 = 100 (innermost), 9 = 200, 5 = 600 —
  proving the outermost-to-innermost ordering of `ringOuterDiametersMm`;
  `hasUniformRings` true; black ⌀ 600, inner-ten ⌀ 50, inner-ten scoring radius
  29.0 mm.

### Unit tests — scoring vectors (8 mm gauge; shot at distance `d` from centre)

`rifle_300m_target_geometry_test.dart`, *integer score across every ring, both
sides of the boundary* (offsets nudged ±0.01 mm off the exact radius). Every
interior ring boundary is pinned on **both** faces: the outer side (just past the
edge, the lower ring) and the inner side (just inside the edge, the higher ring):

| `d` (mm) | ring | | `d` (mm) | ring |
| -------- | ---- |-| -------- | ---- |
| 0.00     | 10   | | 303.99   | 5    |
| 53.99    | 10   | | 304.01   | 4    |
| 54.01    | 9    | | 353.99   | 4    |
| 103.99   | 9    | | 354.01   | 3    |
| 104.01   | 8    | | 403.99   | 3    |
| 153.99   | 8    | | 404.01   | 2    |
| 154.01   | 7    | | 453.99   | 2    |
| 203.99   | 7    | | 454.01   | 1    |
| 204.01   | 6    | | 503.99   | 1    |
| 253.99   | 6    | | 504.01   | 0    |
| 254.01   | 5    | | 600.00   | 0    |

Plus:
- *inner ten on either side of the 50 mm ring* — `d = 28.99 mm` is an inner ten,
  `d = 29.01 mm` is a plain ten (still ring 10, not an inner ten).
- *distance is radial, not per-axis, and sign-independent* — `(-30, 30)`
  (`d ≈ 42.43 mm`) scores 10; `(-80, 80)` (`d ≈ 113.14 mm`) scores 8.
- *a wider gauge reaches one ring further out* — at `d = 53.5 mm` a 6 mm gauge
  (ten radius 53.0 mm) scores a nine while the default 8 mm gauge (ten radius
  54.0 mm) scores a ten.

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

- [ ] **Course of fire** — the seeded program is "300 m Rifle", 60 shots in
      6×10. Confirm the exact NSF course(s): 60 prone, 3×20 (60-shot
      three-position) or the full 3×40 (120-shot) match, the 200 m scaled face,
      and any class reductions.
- [ ] **Decimal vs integer scoring** — the program is seeded integer + inner ten.
      Confirm whether NSF scores 300 m rifle to a decimal (as electronic targets
      / ISSF finals do) or to whole rings + X in club matches.
- [ ] **Black diameter** — asserted ⌀ 600 mm (covers roughly rings 5–10).
      Confirm the exact NSF black for the 300 m rifle face (render-only).
- [ ] **Calibre / gauge edge** — asserted centre-fire ⌀ 8 mm. Confirm the exact
      gauge NSF uses for the 300 m ≤ 8 mm class.
