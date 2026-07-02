# Spec 0085 — Felt: innertreff as tiebreaker, not points

- **Status:** Accepted
- **Related:** spec 0080 (felt hit recording — partially superseded: the
  scoring formula), spec 0082 (felt rounds in Mine økter), spec 0083 (felt
  sync), spec 0023 (inner-ten display convention)

## Context

Spec 0080 scored a NorgesFelt hold as *treff + figur + innertreff* — one
point per hit, one per distinct figure hit **and one per inner-zone hit**.
The domain expert corrects this: **innertreff gives no points**. It is the
tiebreaker — with equal points, the shooter with the most inner hits wins.
Totals should therefore be presented as *points + inner count*, in the same
way the ring programs show a score with its inner tens ("600 · 60 Ⓧ",
spec 0023).

The corrected formula is confirmed by the course itself: NorgesFelt-løype
2026's official maximum of **80 points** (gruppe 1) equals exactly
48 treff + 32 figur — it is only reachable when inner hits add nothing.

## Requirements

1. A hold's points are **treff + distinct figures hit**. Inner-zone hits add
   **no** points.
2. Inner-zone hits are still counted, per hold and per session — the session
   inner count is the tiebreak number.
3. Everywhere a felt total is shown, the inner count follows the points using
   the spec-0023 inner-ten convention ("N poeng · M Ⓧ", the ringed X, hidden
   when M = 0): the recording screen's hold line and running total, the
   scorecard's hold rows and total row, and the "Mine økter" card.
4. Totals are recomputed from the stored per-shot data, so rounds recorded
   under the spec-0080 formula — local and synced — show the corrected
   points with no migration.

## Rationale

Points and tiebreaker are kept as two numbers rather than folding inner into
a compound score: that is how the official result works, and it reuses the
app's existing inner-ten display convention (spec 0023), so a felt total
reads exactly like a ring-program total.

No `felt_sessions` schema change: the denormalised `points` column simply
receives the corrected value on future uploads. Nothing reads that column
today (the app recomputes from the `payload` snapshot); a future scoreboard
that needs the tiebreak recomputes it from `payload` or adds a column then.

## Design

- `FeltHoldTally.points` becomes `treff + figures`; `inner` is unchanged.
- `FeltSessionTally` gains `inner` — the summed inner hits across holds.
- The presentation sites (recording screen, scorecard, Mine økter card)
  render totals through `innerTenScoreText` (spec 0023) with the felt inner
  count as the `innerTens` argument.
- `FeltSessionRecord` is untouched: `tally`/`points` already recompute from
  the snapshot, which is why old rounds correct themselves.

## Verification

### Unit tests
- `felt_scoring_test`: an all-inner hold scores treff + figures only
  (6 hits over 5 figures, 6 inner → 11 points, inner 6); a plain hit still
  scores 2; the session total drops inner and `FeltSessionTally.inner` sums
  the holds' inner counts.
- `felt_session_record_test`: a record's recomputed points follow the
  corrected formula (2 hits over 2 figures + 1 inner → 4, not 5).

### System tests
- `felt_record_screen_test`: an inner-zone hit shows
  "Treff 1 · Figur 1  =  2 poeng" with "1 Ⓧ" appended (the drawn InnerTenX)
  on the hold line, and "Totalt så langt: 2 poeng · 1 Ⓧ".
- `felt_in_my_sessions_test`: the finished round saves with the corrected
  points and the Mine økter card shows "2 poeng" with the ringed X count.

## Open questions
- None.
