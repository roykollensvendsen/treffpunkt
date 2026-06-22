# Spec 0004 — Program, series and series scoring

- **Status:** Accepted
- **Related:** ADR-0012 (session model), ADR-0003 (Riverpod), spec 0001
  (air-rifle scoring)

## Context

Increment 0 scored a single shot on the 10 m air-rifle target. Real recording
(the requirements added 2026-06-22, ADR-0012) is organised as a *program* shot
in *series* of a fixed number of shots on one target face. This spec adds the
pure-Dart core for one series: a `Program` (single-stage), a `Series` of shots
with a capacity, and series scoring (per-shot ring, inner-ten flag, running
total and maximum), plus an optional inner ten on `TargetGeometry`.

This is the first slice of the ADR-0012 model. The `Session` aggregate root,
multi-stage programs and the competition link arrive with their consumers
(offline persistence, competitions); they are out of scope here.

## Requirements

1. A `Program` names a discipline, owns a `TargetGeometry` and a shots-per-series
   count, and produces a fresh empty `Series`.
2. A `Series` holds up to `capacity` shots placed against a geometry: `placeShot`
   appends the next shot and is rejected once full; `moveShot` replaces a placed
   shot; the series reports placed / remaining / complete. It is an immutable
   value type — every operation returns a new series.
3. `TargetGeometry` may carry an optional inner-ten ("X") ring; air rifle has
   none.
4. `ScoringService.isInnerTen` reports whether a shot is an inner ten — always
   false when the geometry records none.
5. `ScoringService.scoreSeries` returns each placed shot's ring score and
   inner-ten flag, the running total, the inner-ten count and the maximum total
   (capacity × highest ring).
6. The 10 m air-rifle scoring (spec 0001) is unchanged: its integer and decimal
   vectors still pass.
7. Pure Dart — no Flutter or Supabase imports; passes `very_good_analysis`.

## Rationale

Keeping the recording core pure (like `ScoringService`) makes a new discipline
mostly *data*, not code, and unit-testable without a UI. `Series` is a value type
so placing or moving a shot is a pure transformation, matching Riverpod's
immutable-state model. Inner ten is optional on the geometry so disciplines that
do not record it (air rifle) carry no fabricated number, while pistol (spec 0005)
sets a sourced one. Scoping this slice to one series — deferring the `Session`
root, stages and the competition link to their consumers — avoids speculative
generality.

## Design

```
lib/features/scoring/domain/
  program.dart        Program { name, geometry, shotsPerSeries; newSeries() }
  series.dart         Series { geometry, capacity, shots; placeShot / moveShot;
                      placedCount / remaining / isComplete }
  series_score.dart   ShotScore { ring, isInnerTen };
                      SeriesScore { shots, total, innerTens, maxTotal }
  target_geometry.dart  + innerTenDiameterMm? / hasInnerTen /
                        innerTenScoringRadiusMm
  scoring_service.dart  + isInnerTen, scoreSeries
```

Inner ten uses the same gauge "next ring outward" rule as ring scoring
(`innerTenRadius + pelletRadius`).

## Verification

### Unit tests
- `series_test`: a fresh series is empty and not complete; `placeShot` appends
  without mutating the original; complete at capacity; placing beyond capacity
  throws; `moveShot` replaces one shot and leaves the others; an invalid index
  throws; `Program.newSeries` makes a right-capacity empty series.
- `series_score_test`: air rifle records no inner ten; a target with an inner ten
  flags central shots at the boundary (in / out); `scoreSeries` sums rings,
  counts inner tens and computes the maximum.

### System tests
- The existing `scoring_service_test` (spec 0001) stays green — no air-rifle
  regression.

## Open questions
- The `Session` aggregate root (stable id, timestamp, location, weapon, optional
  competition reference, lifecycle) lands with offline persistence (ROADMAP 0009)
  and competitions (0010 / 0011).
- Inner-ten dimensions and the 25 m pistol geometry are pinned with a source in
  spec 0005.
