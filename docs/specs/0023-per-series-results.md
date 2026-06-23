# Spec 0023 — Per-series results on the scorecard

- **Status:** Accepted
- **Related:** spec 0006 (series scoring screen), spec 0004 (program, series &
  scoring), ADR-0012 (session model)

## Context

In Treffpunkt each `Series` is one target face (skive): a stage is shot as
several series, patching ("lapping") the face between them. The session
scorecard (spec 0006) today shows only a subtotal per stage and the grand
total — the individual skive results are summed away.

The domain expert (the shooter's father) wants to read **each skive's result
separately**, the way a paper scorecard lists every face. Seeing per-series
scores lets a shooter spot a weak face, compare faces within a stage and check
each skive against the paper record. This spec enhances spec 0006's scorecard
to list every series under its stage while keeping the per-stage subtotal and
the grand total.

## Requirements

1. The session scorecard lists, under each stage, every series (skive) it
   contains, in firing order, each with its own result.
2. A series row shows a label (`Serie 1`, `Serie 2`, …) and the series' ring
   total over its maximum (`total / maxTotal`), appending the inner-ten count
   (`· N×X`) when the series has any.
3. The series rows are visually subordinate to the stage subtotal (e.g.
   indented and smaller), which is kept, as is the grand total.
4. A single-series stage shows exactly one such row — every skive is shown.
5. Each series row carries a screen-reader `Semantics` label consistent with
   the existing score labels (e.g. "Serie 1: 48 av 50, 2 indre tiere") and a
   findable `Key` so tests can locate it.
6. The per-stage subtotal still equals the sum of its series, and the grand
   total still equals the sum of the stages — the added rows only expose the
   numbers already computed, they do not change any total.

## Rationale

A series is already the unit of one skive in the domain, and
`ScoringService.scoreSeries` already produces a `SeriesScore` for each. The
stage-scoring loop in `scoreSession` already calls it once per series to build
the subtotal, so the per-series scores exist transiently and are then thrown
away. The smallest faithful change is to **keep** them: `StageScore` gains a
`List<SeriesScore> series` field that the loop fills, and the scorecard renders
one subordinate row per entry. The stage `total` / `innerTens` / `maxTotal`
stay as they are, so every existing total is unchanged and the invariants
(stage = sum of its series, session = sum of its stages) hold by construction.

Rendering the rows from the existing `StageScore` keeps the view a pure
function of the score — no new query, no new provider, no change to the
recording flow. Reusing the shared `_scoreSemanticsLabel` keeps the spoken
phrasing identical to the stage and series-total labels.

## Design

Domain (`lib/features/scoring/domain/`):

- `StageScore` gains a required `final List<SeriesScore> series` — the
  per-series scores in firing order, stored unmodifiable.
- `ScoringService.scoreSession` collects each `scoreSeries(series)` result for
  the stage into that list (the loop already computes them) and passes it to
  `StageScore`. The stage `total` / `innerTens` / `maxTotal` are unchanged.

Presentation (`lib/features/scoring/presentation/series_screen.dart`):

- `_StageScoreRow` renders, below the stage subtotal row, one subordinate row
  per `score.series` entry: a `Serie N` label and `total / maxTotal` with a
  `· N×X` suffix when `innerTens > 0`, indented and in a smaller style.
- Each series row is wrapped in `Semantics` with a `_scoreSemanticsLabel`
  ("Serie 1: 48 av 50, 2 indre tiere") and carries a `seriesResultRowKey` so a
  widget test can find the rows.

## Verification

### Unit tests

- `session_score_test`: a two-stage program with several series per stage
  (e.g. via `ProgramCatalogue.finpistol25m` or a small custom program) —
  `StageScore.series` has length = the stage's `seriesCount`, and each entry
  has the expected per-series `total` / `innerTens` / `maxTotal`. Assert the
  invariants `stage.total == sum(series.total)`,
  `stage.innerTens == sum(series.innerTens)` and
  `stage.maxTotal == sum(series.maxTotal)`.

### Widget tests

- `series_screen_test`: completing a multi-series program to the scorecard
  (e.g. `finpistol25m`, precision = 6 series) shows six series rows under that
  stage with the correct scores; a single-series program (air rifle) shows one
  series row under its stage. The per-series semantics label (e.g.
  "Serie 1: 50 av 50, …") is announced.

## Open questions

- None.
