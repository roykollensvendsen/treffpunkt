<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0151 — Nytt treff settes der fingeren løftes

## Summary

When placing a **new** shot, the shot now lands **where the finger lifts**,
not where it first touched. With the loupe (spec 0150) you press, slide to
aim precisely, and release — the shot is committed at the release point. This
replaces the old tap-only placement, which was cancelled the moment the
finger slid, so aiming with the loupe placed nothing.

## Rationale

- The loupe invites press-and-slide aiming; placement had to follow through
  and commit at the lift point, or the loupe's precision was unusable.
- One rule across the ring target, the scan overlay and the felt recorder:
  the `MagnifierOverlay` already tracks the single pointer, so it reports the
  release (`onCommit`) — position and whether the finger moved — and each
  screen commits a shot there.

## Design

- `MagnifierOverlay.onCommit(position, {moved})` fires on the release of a
  single-finger gesture (never a pinch or a cancel), with the release point
  in the overlay's (viewport) coordinates and whether the finger passed touch
  slop.
- Each screen's commit:
  - maps the viewport point back through the zoom with
    `TransformationController.toScene` (so a zoomed-in placement lands right);
  - **skips** when the gesture grabbed an existing marker to drag it (a
    `_grabbed` flag set on pick-up), so moving a shot never also places one;
  - **skips** when the gesture moved on a zoomed-in view — that is a pan, not
    a placement (at 1× there is no pan, so a slide is loupe aiming).
- The old `onTapUp` placement is removed from all three screens; a tap is a
  zero-move commit, so it still places at the release point exactly as before.

## Verification

1. `magnifier_overlay_test`: a tap commits at the release point (not moved);
   a slide commits at the **lift** point (moved); a pinch commits nothing.
2. `felt_record_screen_test`: pressing an empty corner, sliding to the hare's
   inner zone and lifting there scores the hit — the shot lands at the lift,
   not the touch-down.
3. Existing ring / scan / felt placement tests (taps) still pass unchanged.
