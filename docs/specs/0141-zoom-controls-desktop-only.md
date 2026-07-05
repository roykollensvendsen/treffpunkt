# Spec 0141 — Zoomknappene er for musa

- **Status:** Accepted
- **Related:** owner report in-session 2026-07-05 («på telefon dekker
  kontrollene, for å zoome, skivene … kanskje bare vise disse på
  desktop?»); specs 0021 (ring zoom), 0125 (felt zoom), 0045 (scan)

## Context

The on-target ＋/−/reset button stack existed for mouse users, but it
was drawn on every platform — and on a phone it sat on top of the
face, covering scoring zones the shooter needed to see and tap.

## Rationale

Touch screens already have the better tool: the pinch (and the pan),
which every zoomable surface supports. The buttons earn their place
only where fingers are absent — desktop platforms with a mouse. One
shared rule (`zoomControlsVisible`, keyed on the target platform)
gates all four control stacks: the ring target, the felt recorder,
the silhouette target and the scan overlay. Pinch, trackpad scroll
and every mapping underneath are untouched.

## Requirements

1. The zoom button stacks render only on desktop platforms; on
   Android/iOS they are absent and gestures carry the zoom.
2. All four zoomable surfaces follow the one shared rule.

## Verification

- Widget: on the test default (Android) the ring target renders no
  zoom buttons but keeps its InteractiveViewer; the existing
  button-driven zoom tests run under a desktop platform override and
  pass unchanged.
- The pinch tests (specs 0021/0128) are platform-independent and
  green.
