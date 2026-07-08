<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0153 — Live desimalverdi på loupen mens man sikter

## Summary

While aiming a shot with the loupe (specs 0150–0152), a small badge on the
loupe now shows the **decimal score** of the point under the crosshair
(e.g. «10,4»), updating live as the finger slides — so you see the value
before you lift. Always shown with one decimal. On the ring target and the
scan overlay (ring scoring); not on the felt recorder, which scores
treff/figur without decimals.

## Rationale

- The loupe already puts the exact point in view; showing what that point is
  worth, before committing, is the natural next step — you can nudge for the
  tenth you want and lift.
- Always decimals (the user's choice): the loupe is a precision aid, so it
  shows the finest value regardless of the session's decimal-entry mode.

## Design

- `MagnifierOverlay.readoutAt(Offset focal) → String?`: called with the
  current focal (viewport) point; a non-null result is drawn as a badge on
  the loupe, on the side away from the finger. Felt passes none.
- The ring target and scan map the focal back through the zoom
  (`toScene`), turn it into a `Shot`, score it with
  `ScoringService.decimalScore` and format it with the shared
  `norDecimalScore` (Norwegian comma), e.g. «10,4»; a miss reads «0,0».
- `norDecimalScore` is extracted to a shared helper and reused by the
  scorecard's existing decimal label.

## Verification

1. `magnifier_overlay_test`: a `readoutAt` result renders as a badge on the
   loupe and updates as the finger moves; no badge without `readoutAt`.
2. `series_target_test`: pressing near the centre shows a «10,…» readout;
   pressing off the target shows «0,0».
3. Existing placement tests unchanged.
