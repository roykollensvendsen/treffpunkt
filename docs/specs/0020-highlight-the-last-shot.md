# Spec 0020 — Highlight the last shot

- **Status:** Accepted
- **Related:** spec 0006 (series scoring screen), spec 0002 (move a placed
  shot), spec 0004 (series domain)

## Context

While shooting a series the shooter places shots one after another, and the
target soon carries several near-identical amber markers. After looking away —
to load, to read the wind, to note a score — it is hard to tell at a glance
which marker is the one just fired. The shooter wants the most recently placed
shot ("siste skudd") visually emphasised, distinct from the earlier shots, so
they can instantly see where their latest shot landed.

This enhances the series scoring screen (spec 0006); it changes the
presentation only — no scoring, domain or data behaviour changes.

## Requirements

1. On the target, the most recently placed shot (the highest index in the
   series) is drawn emphasised: clearly distinct from the earlier amber
   markers, yet still readable as a shot.
2. Earlier shots are drawn exactly as before.
3. A shot currently being dragged keeps its drag styling. When the dragged
   shot is also the last shot, the drag styling wins — precedence is
   drag > last-shot-highlight > normal.
4. When the series has no shots, nothing is highlighted.
5. The shots list mirrors the target: the row of the most recently placed shot
   carries a matching, subtle emphasis, and that emphasis moves to the new last
   row as each further shot is placed. A zero-shot series has no emphasised row.
6. The decision of which shot to emphasise is exposed in a testable way so it
   can be unit-tested without rendering. Presentation only; passes
   `very_good_analysis`.

## Rationale

The "last shot" is simply the highest index in firing order, so the rule is a
one-liner: `shots.isEmpty ? null : shots.length - 1`. Exposing it as a computed
`SeriesPainter.highlightedIndex` keeps the rule pure and unit-testable without a
canvas, and lets the painter and the shots list agree on the same shot.

On the target the highlight is a larger marker (≈1.4× the pellet radius) in the
same amber fill with an extra outer "halo" ring in a distinct highlight colour
(`Colors.deepOrange`). Growing the marker and adding a ring reads as "this one"
without inventing a second shot colour or hiding the pellet, and stays legible
on both the black bull and the white field. Drag styling (`lightBlueAccent`)
already signals "I am moving this shot"; letting it win avoids two competing
emphases on one marker and keeps spec 0002's behaviour intact.

In the list the matching emphasis is a bold ring value plus a `Key` on the
emphasised row, so tests can find it and so the visual cue is consistent with
the target without a heavy redesign.

## Design

`SeriesPainter` gains:

```dart
/// The index of the shot to emphasise (the most recently placed), or `null`
/// when the series is empty.
int? get highlightedIndex => shots.isEmpty ? null : shots.length - 1;
```

`paint` draws each marker as today, except the shot at `highlightedIndex` (when
it is not the dragged shot) is drawn at `radius * 1.4` with the normal amber
fill, the normal black outline, and an additional `deepOrange` stroked halo ring
just outside it. The dragged shot (`draggingIndex`) keeps its `lightBlueAccent`
fill and is never given the halo. `shouldRepaint` is unchanged in spirit: it
already repaints when `shots` or `draggingIndex` change, which is exactly when
the highlighted marker can move or change styling.

In `series_screen.dart` the `_ShotsList` learns the index of the last placed
shot (`placed - 1`, or none when `placed == 0`) and passes a `highlighted` flag
to the matching `_ShotRow`. The highlighted row renders its ring value in
`deepOrange` bold and carries `lastShotRowKey`, so the list and the target agree
on "the latest shot".

## Verification

### Unit tests

- `series_painter_test`: `highlightedIndex` is `null` for an empty series and
  equals `shots.length - 1` for a non-empty one (checked at one and several
  shots).
- `series_painter_test` (render proof, recording `Canvas`): with several shots
  and no drag, the last marker draws an extra circle (the halo) and a larger
  filled radius that the earlier markers do not. With `draggingIndex` set to the
  last shot, that marker is drawn with the drag fill and *without* the halo —
  drag wins.

### Widget tests

- `series_screen_test`: after placing shots, the last shot's list row carries
  `lastShotRowKey`; after placing one more shot the key moves to the new last
  row; a zero-shot series has no such row.

## Open questions

- None. The highlight colour and size are a presentation choice and can be
  tuned without changing the rule or the tests that pin the behaviour.
