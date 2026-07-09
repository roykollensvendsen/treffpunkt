<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0155 — Jevn vertikal rytme på Hjem

## Summary

The front page (Hjem) had an uneven vertical rhythm: the resume/hero cards at
the top sat tight together, then a conspicuous empty band opened up before the
category grid, then the spacing tightened again toward the «Spander en kaffe»
card. The band was not deliberate whitespace — it came from the category grid
reserving far more cell height than the tiles' content needs. This spec removes
it so the page reads as one evenly-spaced column.

## Rationale

- The category grid was a `GridView.count(childAspectRatio: 2)`. On a phone the
  two columns give ~175 px-wide cells, so a fixed 2∶1 aspect forced each cell to
  ~88 px tall — while a tile's actual content (a 26 px pictogram beside one or
  two short text lines) is barely half that. Every cell carried ~30 px of dead
  space, and the block of it above the first row read as a ~65 px gap between the
  «Skyt igjen» hero and the grid (measured live: 68 px, versus ~20 px elsewhere).
- A fixed `childAspectRatio` is also fragile: the right number changes with text
  scale, locale string length and screen width, so it would drift out of true
  again. Letting the tiles size to their **content** removes both the dead space
  and the fragility.
- Consistency/visual-hierarchy: uneven spacing — tight, then a void, then tight —
  reads as "unfinished / something failed to load," and it's the first thing the
  eye does after the primary actions, on every launch.

## Design

- Replace the fixed-aspect `GridView.count` with a small `Column` of **rows**:
  each row is an `IntrinsicHeight` `Row` of two `Expanded` `_CategoryTile`s
  (so the pair shares one height and the two columns stay aligned), separated by
  the same spacing token used between the other sections. Tiles now take their
  content height — no reserved slack.
- Normalise the inter-section gaps on Hjem to one consistent value so the resume
  cluster, the category rows and the coffee card sit on an even rhythm.
- No change to the tiles themselves, the pictograms, the card content, tap
  targets or semantics — purely the surrounding layout.

## Verification

- `program_picker_screen_test`: the vertical gap between the «Skyt igjen» card
  and the first category tile is small and even (no >24 px band), and the four
  tiles still form a 2×2 with the paired tiles top-aligned (existing 2×2
  assertion keeps passing).
- Existing picker tests (categories present, tap opens the category, resume/
  shoot-again cards) unchanged.
- Visual: rendered before/after on Hjem in light and dark (resume-cluster and
  first-run states), signed off before merge.
