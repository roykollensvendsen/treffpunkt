# Spec 0086 — Felt: the stripe figures score as one figure with the middle square as innertreff

- **Status:** Accepted
- **Related:** spec 0079 (composed hold art), 0080 (hit recording), 0085
  (innertreff as tiebreaker)

## Context

On Hold 2 and Hold 8 of NorgesFelt-løype 2026 the stripe figures ("Stor
stripe", "Liten stripe") are printed as **three squares in a row or column**.
The domain expert clarifies how they score: the three squares are **one
figure**, and a hit in the **middle square counts as innertreff** — there is
no inner-treff ring on these figures.

The composed art (spec 0079) already *draws* each stripe faithfully as three
separate squares, but the hit test treats every square as its own figure and
none of them as an inner zone. So today a shooter who hits two squares of
the same stripe is credited two figure points, and a middle-square hit earns
no tiebreak count.

## Requirements

1. A hit on any of a stripe's three squares scores as a hit on **that
   stripe** (one figure): hits on two squares of the same stripe credit the
   figure point once.
2. A hit in the **middle** square of a stripe is an **innertreff** (the
   spec-0085 tiebreak count). The outer squares are plain hits.
3. This applies to all six stripes: Hold 2's two Stor striper, Hold 8's
   Stor stripe and three Små striper.
4. The drawing is unchanged — three squares, no inner-treff ring.
5. With the squares grouped, the number of scorable figures per hold equals
   the course definition's figure count (6 on Hold 2, 6 on Hold 8), so the
   per-hold figure points can no longer exceed the official maximum.

## Rationale

The composed art keeps one entry per drawn shape (the three squares), and the
scoring identity is layered on as data: each square part names the figure it
scores as, and the middle part is flagged as the inner zone. The alternative
— merging each stripe into one multi-part art figure — would complicate the
draw model (multi-path figures) for no visual gain, and the hit test is the
single place scoring identity is resolved.

Rounds recorded **before** this fix keep their stored resolution: a shot's
figure and inner flags are resolved at placement time and stored (specs
0080/0081), like a filled-in paper scorecard. Only the total points formula
(spec 0085) is recomputed from stored flags; re-resolving old shots'
positions against the corrected art would require the presentation-layer art
in the domain and silently rewrite history.

## Design

- `FeltArtFigure` (spec 0079) gains two optional fields:
  - `scoreIndex` — the index of the figure this shape scores as; unset means
    the shape scores as itself. The three squares of a stripe all carry the
    first square's index.
  - `innerZone` — `true` on the middle square: a hit on this shape is an
    inner-zone hit.
- `feltHitTest` (spec 0080) resolves a hit on shape *i* to
  `figureIndex = scoreIndex ?? i`, and `inner` is true within a figure's
  ring **or** when the hit shape is an `innerZone` part.
- `felt_hold_art_data.dart`: Hold 2's squares 4–6 and 7–9 group to score
  indices 4 and 7 (middles 5 and 8 are inner zones); Hold 8's squares 2–4,
  5–7, 8–10 and 11–13 group to 2, 5, 8 and 11 (middles 3, 6, 9, 12).
- The grouping lives in the reconstruction **models**
  (`tool/felt/models/hold-{2,8}.json`, the same `scoreIndex`/`innerZone`
  fields) and `tool/felt/gen_dart.py` emits it, so regenerating the art data
  from the models preserves spec-0086 scoring.

## Verification

### Unit tests
- `felt_hit_test_test`: on a synthetic three-square group, a hit on an outer
  square resolves to the group's score index with `inner` false; a hit on
  the middle square resolves to the same index with `inner` true; two hits
  on different squares of the group count one distinct figure.
- `felt_hold_art_data_test`: holds 2 and 8 carry the exact groupings above —
  each stripe's squares share one score index, exactly the middle square is
  an inner zone, and the number of distinct scorable figures equals the
  course's figure count (6 and 6). No other hold uses `scoreIndex` or
  `innerZone`.

### System tests
- `felt_record_screen_test`: two taps on different squares of the same
  Hold-2 stripe (via hold navigation) score "Treff 2 · Figur 1", and a tap
  on the middle square adds the ringed-X inner count.

## Open questions
- None.
