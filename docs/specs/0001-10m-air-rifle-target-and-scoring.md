# Spec 0001 — 10 m air-rifle target and scoring

- **Status:** Accepted
- **Discipline:** ISSF / NSF 10 m air rifle (luftrifle)
- **Related:** ADR-0004 (spec-driven + TDD)

## Context

Treffpunkt's first vertical slice scores a single 10 m air-rifle target. A shot
is recorded as the position where the pellet struck, and the app must turn that
position into a score the same way a referee or an electronic target does.

This spec defines the target geometry, the two scoring methods (whole-ring and
decimal), and the exact numbers, so the scoring logic can be implemented as a
pure-Dart function and verified test-first.

## Requirements

1. The target geometry matches the ISSF 10 m air-rifle target.
2. Scoring accounts for the pellet caliber (4.5 mm), as real scoring does.
3. The app can compute both the **integer** score (1–10, whole rings) and the
   **decimal** score (e.g. 10.4) for any shot position.
4. A shot outside the scoring area scores 0 (a miss).
5. The logic is pure Dart with no Flutter dependency, so it is unit-testable in
   isolation.

## Domain facts (ISSF, followed by NSF for luftrifle)

Ring outer diameters (millimetres):

| Ring | 10  | 9   | 8    | 7    | 6    | 5    | 4    | 3    | 2    | 1    |
| ---- | --- | --- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| ⌀ mm | 0.5 | 5.5 | 10.5 | 15.5 | 20.5 | 25.5 | 30.5 | 35.5 | 40.5 | 45.5 |

- Each integer ring is 5 mm larger in diameter than the next (2.5 mm in radius).
- Aiming black ("blink"): the central black disc has ⌀ 30.5 mm (ring 4 outer).
- Pellet caliber: **4.5 mm** (.177"), so the pellet radius is **2.25 mm**.

## Design

We model the target in millimetres with the centre at the origin. A shot is the
offset `(dx, dy)` in mm from the centre; its distance from centre is
`d = sqrt(dx² + dy²)`.

### Integer scoring — the gauge "next ring outward" rule

A shot scores ring *N* if the pellet's edge touches ring *N*. Equivalently, its
**centre** lies within `scoringRadius(N) = ringOuterRadius(N) + pelletRadius`.
The score is the highest *N* whose `scoringRadius(N) ≥ d`. Because rings are
evenly spaced, the centre-distance thresholds fall on a clean 2.5 mm grid:

| Ring        | 10  | 9   | 8   | 7    | 6    | 5    | 4    | 3    | 2    | 1    | miss |
| ----------- | --- | --- | --- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| `d ≤` (mm)  | 2.5 | 5.0 | 7.5 | 10.0 | 12.5 | 15.0 | 17.5 | 20.0 | 22.5 | 25.0 | >25  |

### Decimal scoring — used by electronic targets and finals

Each integer ring's 2.5 mm band is divided into ten 0.25 mm steps; moving 0.25 mm
toward the centre adds 0.1 to the score, up to a maximum of **10.9** at the
centre. With `t = ceil(d / 0.25)`:

`decimal = (110 − t) / 10`, capped at `10.9`, and `0.0` when `d > 25.0`.

By construction `floor(decimal) == integer` for every shot.

> Note: the decimal model assumes evenly spaced rings, which holds for 10 m air
> rifle. Other disciplines are out of scope for this spec (see ROADMAP 0010+).

## Verification

### Unit tests — geometry

- `airRifle10m` has caliber 4.5 mm and pellet radius 2.25 mm.
- Ring 10 outer ⌀ = 0.5 mm; ring 1 outer ⌀ = 45.5 mm; black bull ⌀ = 30.5 mm.
- `scoringRadius(10) = 2.5 mm`; `scoringRadius(1) = 25.0 mm`.

### Unit tests — scoring vectors (shot at distance `d` from centre)

| `d` (mm)  | integer | decimal |
| --------- | ------- | ------- |
| 0.0       | 10      | 10.9    |
| 0.25      | 10      | 10.9    |
| 0.50      | 10      | 10.8    |
| 1.00      | 10      | 10.6    |
| 2.25      | 10      | 10.1    |
| 2.50      | 10      | 10.0    |
| 2.60      | 9       | 9.9     |
| 5.00      | 9       | 9.0     |
| 7.50      | 8       | 8.0     |
| 10.00     | 7       | 7.0     |
| 12.50     | 6       | 6.0     |
| 15.00     | 5       | 5.0     |
| 17.50     | 4       | 4.0     |
| 20.00     | 3       | 3.0     |
| 22.50     | 2       | 2.0     |
| 25.00     | 1       | 1.0     |
| 25.01     | 0       | 0.0     |
| 30.00     | 0       | 0.0     |

Additional cases:
- A diagonal shot `(3, 4)` has `d = 5.0` → integer 9, decimal 9.0 (checks the
  distance calculation).
- A negative-axis shot `(-2.5, 0)` → integer 10 (sign independence).
- Property: for every vector, `integerScore == decimalScore.floor()` and the
  decimal value is within `[0.0, 10.9]`.

### System test

Launching the app, tapping the centre of the rendered target, and reading the
score shows the maximum value (10.9). Covered by
`integration_test/place_shot_test.dart`.

## Open questions

- Exact ISSF electronic-target decimal radii may be refined against the official
  rulebook; the model above is internally consistent and matches whole-ring
  scoring. Tracked for a future revision.
