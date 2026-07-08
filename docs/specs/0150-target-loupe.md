<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0150 — Forstørrelsesglass ved plassering og flytting av skudd

## Summary

On a touch screen the finger hides the exact spot where a shot lands. A
**magnifier loupe** — a small circular, magnified view that floats above the
finger with a crosshair on the focal point — now appears while a shot is
being placed (a touch) or moved (a drag) on every shot-placement surface:
the ring target, the scan overlay and the felt hold recorder. The finger no
longer occludes the point being set.

## Rationale

- Precise placement on small figures / tight rings is exactly where the
  occlusion hurts, and it is the same interaction on three screens — so the
  fix is one reusable overlay, not three.
- Flutter's built-in `RawMagnifier` (the widget behind the text-selection
  loupe) samples the rendered target beneath it, so the loupe shows the real
  rings/figures **and** the current shot marker, magnified — no new package,
  works on web and mobile.
- Shown for a single pointer only: a two-finger pinch-zoom must not raise a
  loupe. Positioned above the finger, flipping below when near the top edge,
  and clamped horizontally so it stays on-screen; the focal offset keeps the
  crosshair on the true finger point regardless.

## Design

- `MagnifierOverlay` (`lib/core/presentation/magnifier_overlay.dart`): wraps
  a target child, tracks pointers with a `Listener` (never joining the
  gesture arena, so tap / long-press / pinch are untouched), and stacks a
  `RawMagnifier` loupe over the child at the single active pointer. The loupe
  is `IgnorePointer`, circular, ~1.8× magnification, with a small ring
  crosshair marking the focal point. Hidden when zero or ≥2 pointers are down.
- Wired into `SeriesTarget` (ring), `ScanTargetScreen`'s placement overlay
  and `FeltRecordScreen`'s `_HoldRecorder` by wrapping their existing
  interactive area — the gesture logic is unchanged.

## Verification

1. `magnifier_overlay_test`: a single pointer-down shows a `RawMagnifier`
   over the child; pointer-up hides it; a second simultaneous pointer
   (pinch) hides it; a disabled overlay never shows one.
2. `series_target_test`: pressing the ring target shows the loupe during the
   press and removes it on release; placing/dragging still works.
3. `felt_record_screen_test` / scan: a touch on the hold / photo shows the
   loupe.

System tests: none — `integration_test/` places shots at fixed points via
the existing gestures, which are unchanged.
