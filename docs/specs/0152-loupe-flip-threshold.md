<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0152 — Loupen blir over fingeren til den er halvveis utenfor

## Summary

The magnifier loupe (spec 0150) floats above the finger and flips below it
near the top edge. It now stays above **as long as possible** — flipping only
once it is **50 % off the top edge** (its centre, the crosshair, reaching the
edge) — instead of flipping the moment its top touched the edge.

## Rationale

- Above the finger is the readable position (the finger isn't between your
  eye and the loupe); flipping early gave it up too soon. Letting it ride up
  to half-clipped keeps the crosshair visible above the finger far longer.
- Below 50 % the crosshair (the loupe's centre) is still on-screen, so the
  focal point stays readable; past 50 % the crosshair itself would clip, so
  the loupe flips below the finger.

## Design

- In `TargetLoupe`, the above/below choice becomes
  `fitsAbove = focal.dy - lift >= 0` (flip when the above-centre would rise
  above the top edge) instead of requiring the whole loupe to fit. The Stack
  clips the part that rides off the top.

## Verification

`magnifier_overlay_test`: with room above, the loupe centre sits above the
touch point; when the finger is close enough to the top that the above
position would be more than half-clipped, the loupe centre sits below the
touch point.
