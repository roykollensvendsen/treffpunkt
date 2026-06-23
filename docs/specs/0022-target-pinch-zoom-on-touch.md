# Spec 0022 — the target owns pinch-zoom on touch

Status: Accepted

## Context

Spec 0021 stopped the page scroll from stealing the target's wheel / trackpad
zoom and drag pan on desktop, by suspending the page `SingleChildScrollView`
while a mouse / trackpad pointer hovers the target. It explicitly left touch out
of scope.

On a phone (reported on Firefox / Android) pinch-to-zoom on the target still
fails: a two-finger pinch with any vertical component is lost to the page's
vertical scroll, so the target zooms only on a near-horizontal pinch, if at all,
and a vertical pinch scrolls the page instead of zooming it.

## Requirements

1. A two-finger pinch on the target zooms the target regardless of the gesture's
   direction (vertical, horizontal or diagonal) — it is never stolen by the page
   scroll.
2. A single-finger drag on the target pans it when zoomed in (it does not scroll
   the page).
3. Releasing all fingers restores normal page scrolling; areas outside the
   target (header, shots list, totals, legend) still scroll the page normally.
4. The desktop behaviour from spec 0021 is preserved; this adds to it.

## Rationale

A `MouseRegion` only reacts to hovering devices, so it cannot help touch. The
conflict is in the gesture arena: the page's `VerticalDragGestureRecognizer`
competes with the target `InteractiveViewer`'s scale / pan recogniser, and for a
vertically-moving pinch the page's vertical drag wins. The remedy is the same as
spec 0021 — let the page physics arbitrate rather than fight the arena: while a
finger is pressed on the target, suspend the page scroll so its drag recogniser
is not built, leaving the `InteractiveViewer` to win the pinch / pan in any
direction.

Detecting "a finger is on the target" needs a `Listener` (which observes pointer
down / up without joining the arena), not a `MouseRegion`. Suspending on any
pointer-down (not only two) also fixes single-finger pan when zoomed in; the cost
is that a drag starting on the target no longer scrolls the page — acceptable,
since the target is one element and the surrounding content scrolls normally,
which is how embedded maps and zoomable images behave.

## Design

`_SessionScrollBody` (spec 0021) gains a finger count alongside its hover flag:

- `bool _hovering` (mouse / trackpad, via `MouseRegion`) and `int _pointersDown`
  (via a `Listener`'s `onPointerDown` / `onPointerUp` / `onPointerCancel`).
- `bool get _suspendScroll => _hovering || _pointersDown > 0;` drives the page
  `SingleChildScrollView.physics` (`NeverScrollableScrollPhysics` while true).
- The scroll guard wraps the target in both the `MouseRegion` and the `Listener`;
  the `Listener` only observes pointers, so the target's own tap / long-press /
  pinch are unaffected. State updates rebuild only when `_suspendScroll` flips.

`series_target.dart` (the `InteractiveViewer` and its gesture logic) is unchanged.

## Verification

### Widget test (`test/features/scoring/presentation/series_screen_test.dart`)

- **A finger on the target suspends page scrolling** (deterministic): with a
  touch pointer pressed at the target centre, the page
  `SingleChildScrollView.physics` becomes `NeverScrollableScrollPhysics`; lifting
  the finger restores it. This is red before the `Listener` is added and green
  after.
- The spec-0021 hover test and all existing target / screen tests stay green.

### Manual (device)

- On a phone, a two-finger pinch on the target zooms it in any direction; a
  single-finger drag pans it when zoomed; dragging outside the target scrolls the
  page. Real-device touch gesture behaviour cannot be simulated headlessly (a
  synthetic pinch does not drive the gesture arena the way a real one does), so
  the deterministic physics test above is the automated guard and the end-to-end
  behaviour is confirmed on-device.
