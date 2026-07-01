# Spec 0080 — Feltskyting: recording hits and NorgesFelt scoring

- **Status:** Accepted.
- **Related:** 0068 (feltskyting figures & course), 0079 (composed holds). This
  adds recording and scoring on top of them.

## Context
The course preview (specs 0068/0079) draws the eight NorgesFelt 2026 holds as
faithful composed pictures, but a shooter cannot yet record a result. Field
shooting is scored by **hits on figures**, not rings: you fire a set number of
shots per hold at the figures, and score per hit. This adds recording a full
NorgesFelt session by **placing each shot on the hold picture**, with the score
updating live.

The two NorgesFelt rules the domain expert confirmed:
- **Shots per hold** depend on the shooter's group: **6** shots for group 1,
  **5** for groups 2 and 3, per standplass (hold).
- **Scoring** is NorgesFelt's *treff + figur + innertreff*: **1 point per hit**
  (a shot that lands on a figure), **1 point per distinct figure hit** on the
  hold, and **1 point per inner-zone hit**. (In ordinary NSF felt the inner zone
  is only a tie-breaker; NorgesFelt makes it point-giving — hence "innertreff på
  alle figurer".)

## Requirements
1. Start a felt session by choosing the **shooter group** (1 / 2 / 3), which sets
   the shots-per-hold (6 / 5 / 5).
2. Go hold by hold. On each hold, **place each shot** as a marker on the composed
   picture (up to the hold's shot count); the app determines **which figure** the
   shot hit and whether it landed in that figure's **inner zone**. A shot that
   lands on no figure is a miss (bom). A placed shot can be removed (undo/clear).
3. The **hold score** updates live: `treff + distinct figures hit + inner hits`.
4. A **session total** across the eight holds, shown on a scorecard at the end.

## Rationale
**Pure-Dart scoring, presentation-layer hit-testing.** The scoring rule is pure
arithmetic over a list of shots, so it lives in the Flutter-free domain
(`FeltShooterGroup`, `FeltShot`, `FeltHoldTally`, `FeltSessionTally`). Deciding
*which figure and inner zone* a placed point falls in needs the composed
geometry (`FeltHoldArt`, `dart:ui` paths), so the hit-test lives in presentation
(`feltHitTest`) and produces the pure `FeltShot` the domain scores.

**Reuse the composed hold art.** Each shot is hit-tested with the same
`feltArtFigurePath` the painter draws, and the inner zone is the figure's ring
(`FeltArtRing`): a shot is *inner* when it is inside the figure and within the
ring radius of the ring centre. So recording is exactly consistent with what is
drawn.

**Place-the-shot recording.** The shooter places each shot where it hit, the way
the ring-target scan places shots, rather than toggling per-figure counts — it is
closer to the real target and lets the app derive figure/inner itself.

## Design
- `felt_scoring.dart` (domain): `enum FeltShooterGroup { one, two, three }` with
  `shotsPerHold` (6/5/5) and a label; `@immutable class FeltShot` (`figureIndex`
  nullable — null is a miss — and `inner`); `FeltHoldTally` over a hold's shots
  (`treff`, `figures`, `inner`, `points`); `FeltSessionTally` over the eight holds
  (`points`, per-hold tallies).
- `felt_hit_test.dart` (presentation): `FeltShot feltHitTest(FeltHoldArt art,
  Offset p)` — the topmost figure whose path contains `p`, with `inner` true when
  `p` is within that figure's ring.
- `felt_record_screen.dart` (presentation): group picker → per-hold placement on
  a `FeltHoldArtView` with tap-to-place shot markers (capped at the group's shot
  count), live hold + running total, previous/next hold, and a final scorecard.
  Reached from the course preview.

## Verification
- **Unit** (`felt_scoring_test.dart`): group shot counts are 6/5/5; a hold tally
  from a known shot list scores `treff + distinct figures + inner` (the
  documented example — 6 hits over 5 figures with 6 inner = 17); misses
  (`figureIndex == null`) score nothing; a session sums its holds.
- **Unit** (`felt_hit_test_test.dart`): a point inside a figure returns that
  figure's index; a point within its ring returns `inner: true`; a point off
  every figure returns a miss; the inner point of a white knockout resolves to
  the knockout figure.
- **Widget** (`felt_record_screen_test.dart`): choosing a group then tapping the
  hold places a shot marker and updates the hold score; placing beyond the shot
  count is refused; the running total reflects placed shots; a scorecard shows
  the eight holds and the total.

## Out of scope
- Persisting/resuming a felt session, "Mine økter" and competition sync (later,
  like the ring sessions).
- Auto-detecting shot holes from a photo of a field target.
- A different yearly course than NorgesFelt 2026.
