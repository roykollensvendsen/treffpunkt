# Spec 0128 — Pinch på feltbildet skal zoome, ikke skyte

- **Status:** Accepted
- **Related:** owner report in-session 2026-07-04 («når jeg prøver å
  zoome på norgesfelt blir det avsatt treffpunkter og zooming virker
  ikke konsistent (med gesture)»); specs 0125 (felt zoom), 0021 (the
  ring target's scroll guard)

## Context

Spec 0125 gave the felt recorder zoom, but a pinch on a touch screen
both placed stray shots and zoomed unreliably. Two causes, both
already solved on the ring target:

1. The recorder placed shots on **tap-down**, which fires before the
   gesture arena knows a second finger is coming — the first finger of
   every pinch planted a shot. The ring target places on **tap-up**,
   which only fires for a completed tap.
2. The screen's ListView competed for the pinch's vertical component
   (and vertical pans), so zoom/pan only partly reached the
   InteractiveViewer. The ring screen suspends page scrolling while a
   pointer hovers or presses the target (spec 0021).

## Rationale

Adopt the ring target's proven answers verbatim: place on tap-up, and
wrap the recorder in the same hover/press scroll guard so the page
stops scrolling while the shooter's fingers are on the picture. No new
mechanism — parity with the target the shooter already knows.

## Requirements

1. A pinch on the hold picture never places a shot; a completed tap
   places exactly one, at the tap point.
2. While a pointer is on the picture, the page does not scroll — the
   pinch/pan reaches the viewer whole; releasing restores scrolling.

## Verification

- Widget: a two-finger pinch on the recorder places no shot and raises
  the scale; a plain tap still places one. While a pointer is down on
  the picture the ListView's physics is non-scrollable, and it is
  restored on release.
- The 0125 zoom test and the recording suites pass unchanged.
