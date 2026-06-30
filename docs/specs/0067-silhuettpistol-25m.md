# Spec 0067 — Silhuettpistol 25 m (5-target bank)

- **Status:** Accepted
- **Related:** spec 0031 (hurtigpistol/NAIS — the rapid family), spec 0058
  (per-series review targets), spec 0066 (the forum thread that planned this).

## Context
The NSF **Silhuettpistol** (25 m) program was requested by the domain expert
(pappa): **60 shots = 12 series of 5, split four series each at 8 / 6 / 4 s**.
Unlike every existing program, a series is **not** fired on one face — the shooter
fires **one shot at each of five separate silhouette targets**, and records the
hits **in firing order**. The five silhouettes are the same face as the 25 m
rapid/duel target (`pistol25mRapid`, rings 5–10, inner-ten 50 mm), so the *score*
is unchanged; only the *recording and review presentation* differ.

## Requirements
1. A new offered program **25 m Silhuettpistol** (.22): three timed stages
   (8 / 6 / 4 s), each four 5-shot series, on the rapid/silhouette face.
2. While recording a series, the **active** silhouette (the next shot) is shown
   **full size and zoomable** — tap to place its shot (or long-press a placed
   shot to drag), exactly like a normal target. The other silhouettes are a
   small, scrollable **thumbnail strip**; the active one is highlighted, and
   tapping any thumbnail focuses it (to review or fix it). Shots fill in firing
   order, one per silhouette.
3. The scorecard **reviews** each series as a row of five mini-targets, each
   showing its one shot.
4. Scoring and persistence are **unchanged** (a series is still 5 shots on one
   geometry).

## Rationale
**A series stays one ordered list on one geometry; only the layout changes.**
All five silhouettes share `pistol25mRapid()`, so shot _k_ scores the same wherever
it is shown. A new `StageDefinition.targetsPerSeries` (default `1`) drives the
presentation: shot _k_ → silhouette `k ~/ shotsPerTarget` (here `k`, one shot each).
Because the shots stay a single ordered list, **`Shot`, `ScoringService` and
`SessionSnapshot` are untouched** — resume rebuilds from the catalogue stage,
which now carries `targetsPerSeries`, so a part-recorded bank restores correctly.

**A big focused target plus a thumbnail strip.** `SilhouetteSeriesTarget` shows
the focused silhouette full size in an `InteractiveViewer` (zoom + place + drag,
mirroring the normal target) and the rest as a horizontal thumbnail strip;
tapping a thumbnail focuses it. The review renders the row of mini-targets. All
reuse `SeriesPainter` (with a new `highlightLast: false` so a filled silhouette
isn't haloed). The single-face **camera scan is hidden** for a silhouette series
(a 5-target photo is out of scope for v1; manual placement only).

## Design
- `program_definition.dart`: `StageDefinition.targetsPerSeries` (+ `shotsPerTarget`
  / `targetIndexForShot`).
- `program_catalogue.dart`: `silhuettpistol25m` (3 × 4 × 5, 8/6/4 s,
  `targetsPerSeries: 5`), added to `all`.
- New `silhouette_series_target.dart`: the interactive 5-mini-target bank (tap the
  active one to place; long-press a placed shot to drag).
- `series_screen.dart`: record branch (bank vs single face) and hide scan when
  `targetsPerSeries > 1`; review branch (`_SilhouetteReview`, N mini-targets) on
  the same `seriesReviewTargetKey`.
- `series_painter.dart`: `highlightLast` flag.

## Verification
- **Unit:** the program is in `all` (count 13 → 14), 60 shots, stages 8/6/4 s × 4
  × 5, `targetsPerSeries 5`, `shotsPerTarget 1`, `targetIndexForShot(k) == k`; a
  normal stage stays `targetsPerSeries 1`.
- **Widget:** a silhouette series renders N mini-targets (not the single target),
  the scan action is hidden, tapping the active target fills the series in order;
  the scorecard reviews the series as N mini-targets.
- **Gates:** `dart format`, `flutter analyze`, full `flutter test`, `reuse lint`,
  docs build. No migration, no backend.

## Open questions / future
- **Camera scan** of a silhouette bank (5 faces in one photo).
- A **grov / centre-fire** Silhuettpistol variant (trivial once the bank exists).
- Per-mini-target zoom for precise placement.
