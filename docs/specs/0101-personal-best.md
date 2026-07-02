# Spec 0101 — Visual identity, part 2: «Ny pers!», logo mark, pictograms

- **Status:** Accepted
- **Related:** the July 2026 UI analysis (bundle 3); specs 0100 (identity
  part 1), 0090 (progress statistics), 0085 (felt tiebreak), 0023
  (scorecard)

## Context

Part 1 gave the app its palette; the moments the palette was reserved for
do not exist yet. Finishing a session with your best-ever result looks
exactly like finishing any other session — the shooter has to open the
statistics screen and squint at a curve to notice. And the home screen's
category tiles are bare text on grey; the app bar says "Treffpunkt" in
plain type with no mark.

## Rationale

The signal red of `TreffColors.lastShot` was explicitly reserved for "hit
moments" (spec 0100). A personal best is *the* hit moment: celebrating it
on the scorecard the second it happens is the cheapest possible reward
loop, and the comparison data already exists (the same merged history the
statistics screen reads). Norwegian shooters compare results as
`poeng + innertreff` (spec 0085), so "better" must be the lexicographic
pair, not points alone. A first-ever result is not a *new* personal best —
there is nothing beaten — so it gets no banner.

The logo mark and category pictograms carry the same identity onto the
home screen: the `TargetIcon` bull in signal red beside the wordmark, and
one small monochrome pictogram per category so the four tiles read at a
glance (rings for precision air, a heavier bull for 25 m fin/grov, a
head-and-shoulders silhouette for MIL — the targets those programs are
shot on — and a square-plus-circle pair for felt's figure holds).

## Requirements

1. **Domain rule** (pure Dart): a result `(points, inner)` is a *new
   personal best* against a list of prior results iff the list is
   non-empty and the result is lexicographically strictly greater than
   every prior result (`points` first, `inner` as tiebreak). Equalling
   the old best is not a new best.
2. **Ring scorecard**: when a live session completes, the scorecard shows
   a «Ny pers!» banner (signal-red `lastShot` field, white text) iff the
   session's `(total, innerTens)` is a new personal best among the
   shooter's other recorded sessions *of the same program* (pending +
   synced, merged and deduplicated by id exactly as «Mine økter» does,
   the just-finished recording's own id excluded). The historical detail
   view ("Mine økter") never shows the banner.
3. **Felt scorecard**: the finished-round screen shows the same banner
   iff the round's `(points, inner)` is a new personal best among the
   shooter's other felt rounds *of the same group* (local + synced
   merged, the current round's id excluded). The felt detail view never
   shows the banner.
4. **Logo mark**: the home app bar shows the `TargetIcon` with its bull
   in signal red beside the "Treffpunkt" wordmark.
5. **Category pictograms**: each category tile carries a small monochrome
   pictogram (air = fine rings, fin/grov = heavy bull, MIL = silhouette,
   felt = square + circle); the tile text is unchanged.

## Verification

Unit (`personal_best_test.dart`):

- more points than every prior → new best; fewer → not.
- equal points, more inner → new best (spec 0085 tiebreak).
- equal points, equal inner → **not** a new best.
- beats some priors but not all → not a new best.
- empty prior list → not a new best.

Widget:

- `series_screen_test`: completing a session with a seeded lower prior
  result for the same program shows the banner; with a higher prior (or
  no prior) it does not; a prior for a *different* program does not
  suppress it.
- `felt_record_screen_test`: a finished round beating a seeded lower
  same-group history round shows the banner; a higher prior hides it; a
  lower prior of the *other* group is ignored.
- `my_sessions`/felt detail: the stored-session scorecard renders without
  the banner.
- home: the app bar carries the `TargetIcon` mark; each category tile
  shows its pictogram.
