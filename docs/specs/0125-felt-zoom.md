# Spec 0125 — Zoom og panorering på felt-skivene

- **Status:** Accepted
- **Related:** owner request in-session 2026-07-03 («La oss kunne
  zoome og panne felt-skivene på samme måte som andre skiver»); specs
  0080 (felt recorder), 0034/0098-era zoom on the ring target

## Context

The ring target zooms and pans (pinch, trackpad scroll, on-target
＋/−/reset buttons) so a shot can be placed precisely. The felt hold
pictures — where precision matters just as much, with small inner
zones on distant figures — could not.

## Rationale

Reuse the ring target's exact recipe: an `InteractiveViewer` around
the hold picture with the same scale range (1–6×), pinch/trackpad
support and the same on-picture zoom buttons — extracted to a shared
`ZoomControls` widget so the two targets cannot drift apart. Gestures
sit INSIDE the viewer, so tap coordinates arrive already mapped back
into picture space and the placement/fraction maths is untouched by
zoom, exactly as on the ring target. The hold picture is not square,
so the centred-zoom transform uses the centre point per axis.

## Requirements

1. The felt recorder's hold picture zooms 1–6× with pinch, trackpad
   scroll and the shared ＋/−/reset buttons, and pans when zoomed.
2. Placing a shot while zoomed lands exactly where the finger points;
   the stored fractions are unaffected by zoom.
3. The ring target's behaviour is unchanged (it now uses the shared
   `ZoomControls`).

## Verification

- Widget: the zoom buttons scale the recorder's transformation (in,
  reset, clamped range); a tap at the visual centre after a centred
  zoom places the shot at the same picture point as without zoom.
- Existing felt recording tests pass unchanged (identity transform).
- Existing ring-target zoom tests pass against the shared controls.
