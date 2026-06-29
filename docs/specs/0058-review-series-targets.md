# Spec 0058 — Review the target with its shots on the scorecard

- **Status:** Accepted
- **Related:** spec 0023 (per-series scorecard), spec 0026 (saved sessions),
  spec 0039 (scan a paper target). A request from the user's father.

## Context
When you finish (or later reopen) a session, the scorecard showed only the
**numbers** per series. The father asked to see **the target with the hit
points** again — the actual shot placement — when he reviews a saved session.

The shot coordinates are already stored losslessly in the session payload (the
`SessionSnapshot`), so the target can be redrawn with its shots; only the scan
photo itself is not kept (just the resulting shots).

## Requirements
1. On the scorecard, each series shows its **target with every shot** drawn at
   its recorded position (the same target used while shooting), under that
   series' score row.
2. This appears wherever the scorecard is shown: on completion, when reopening a
   **saved session** (the father's case), and on another shooter's competition
   result.
3. A series with no shots shows no target (nothing to draw).

## Rationale
**Redraw from the stored shots — no new storage.** The session payload already
round-trips every series' `geometry` and `shots`, so the existing `SeriesPainter`
(the target + shot markers used live) can paint a read-only target from the
saved series. Nothing new is persisted; the scan photo is not needed.

**One optional parameter on the shared scorecard.** `SessionScorecard` gains an
optional `seriesByStage` (the session's `sealedSeriesByStage`). When given, each
`_SeriesResultRow` paints its target; when omitted, the scorecard is unchanged.
All three call sites already hold the session, so they pass it through.

## Design
- `SessionScorecard(seriesByStage:)` → `_StageScoreRow(series:)` →
  `_SeriesResultRow(series:)`. When `series.shots` is non-empty, the row shows a
  constrained (≤240 px) square `CustomPaint` with
  `SeriesPainter(geometry, shots)`, keyed `seriesReviewTargetKey(stage, series)`.
- Passed from: the live completion screen, `SessionDetailScreen` (saved
  sessions), and `CompetitionResultScreen` — each via
  `session.sealedSeriesByStage`.

## Verification
### System tests
- Completing a single-series program shows the series' review target
  (`seriesReviewTargetKey(0, 0)`).
- Opening a saved multi-series session from "Mine økter" shows the first series'
  review target.

## Open questions
- A future step could store the **scan photo** too and offer it as an
  alternative view, and let you tap a target to enlarge it.
