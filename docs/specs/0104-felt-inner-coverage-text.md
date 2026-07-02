# Spec 0104 — Honest inner-zone coverage on the felt course preview

- **Status:** Accepted
- **Related:** forum thread «Norgesfelt» (bug, hold 5); specs 0068/0079
  (course & art), 0085 (inner as tiebreak), 0086 (stripe inner square)

## Context

The course preview's header claimed «innertreff på alle figurer». The
domain expert pointed out that hold 5's big triangle has no inner zone on
the official sheet — and the measured art (spec 0079) and the hit-test
agree: that figure has no ring, and a shot on it has never scored inner.
Only the text was wrong, and he asked for the exception to be written out.

## Rationale

The truth is already in the data: every art figure carries its ring (or
stripe inner square, spec 0086), so the preview can *derive* the coverage
per hold instead of asserting it globally. Deriving also names the
exception — the art's scoring figures line up one-to-one with the domain
figure list on every hold (verified across all 8), so hold 5 can say
which figure lacks the zone. No figure drawing or scoring changes.

## Requirements

1. The header drops the blanket claim and points to the per-hold cards.
2. Each hold card states its coverage, derived from the art: «Innertreff
   på alle figurer» when every scoring figure has a ring/inner square,
   otherwise «Innertreff på X av N figurer (ikke <figurnavn>)» — the
   names included only when the art's scoring figures match the hold's
   figure list one-to-one.
3. A stripe's shapes (shared `scoreIndex`, spec 0086) count as one
   scoring figure.
4. No change to the drawn art, the hit-test or the scoring.

## Verification

- `felt_course_screen_test`: the blanket claim is gone; hold 1 shows
  «Innertreff på alle figurer»; hold 5 shows «Innertreff på 1 av 2
  figurer (ikke Trekant stor)».
- Existing art/hit-test suites unchanged (no behavioural change).
