# Spec 0098 — Shooting screen: a real «Fullfør serie» button and undo

- **Status:** Accepted
- **Related:** the July 2026 UI analysis (bundle 2); specs 0004/0006 (series
  flow), 0080 (the felt recorder's Angre, the pattern to match)

## Context

«Fullfør serie» — the most frequent navigation action in a match (6–12×
per session) — is a small icon-only check in the app bar, disabled with no
explanation until the series is full. And a misplaced ring shot can only be
corrected by long-press-drag within 6 mm; the felt recorder has an Angre
button, the ring screen has none.

## Requirements

1. While shooting, a **bottom action bar** shows a full-width
   **«Fullfør serie (n/N)»** button (the existing `sealSeriesKey` moves onto
   it) — disabled until the series is full, its label always showing the
   count — replacing the app-bar check icon.
2. Beside it, **«Angre»** removes the last placed shot (disabled at zero
   shots), exactly like the felt recorder's Angre. Undo works repeatedly
   down to an empty series.
3. The bar is absent on the scorecard (the session-complete state) and the
   scan action stays in the app bar.

## Rationale

A big labelled bottom button matches the felt recorder's Neste/Fullfør row
and outdoor/gloved use; the count in the label explains why it is disabled.
Undo needs a domain operation (`Series.removeLastShot`) rather than UI
trickery, mirroring `placeShot`.

## Verification

### Unit tests
- `series_test`: `removeLastShot` removes the newest shot, repeatedly, and
  throws on an empty series.

### System tests
- `series_screen_test`: the bar shows «Fullfør serie (0/10)» disabled;
  placing shots updates the count; Angre removes the last shot (count and
  total drop) and is disabled at zero; a full series enables the button and
  tapping it advances (existing seal tests keep passing via the moved key);
  the bar is gone on the scorecard.

## Open questions
- None.
