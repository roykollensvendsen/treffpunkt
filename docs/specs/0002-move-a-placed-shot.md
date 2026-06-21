# Spec 0002 — Move a placed shot by long-press and drag

- **Status:** Accepted
- **Related:** spec 0001, ADR-0003 (Riverpod)

## Context

On a touchscreen you currently place a shot by tapping; the marker jumps to where
you tap. To adjust a shot precisely — especially since the pellet marker is large
relative to the rings — you need to pick it up and drag it. This was envisaged in
the original brief: long-press the shot, it changes colour, and you drag it where
you want.

## Requirements

1. Tapping places (or moves) the shot to the tapped point (unchanged).
2. Long-pressing on the placed marker "picks it up": it is marked as being dragged
   and the marker changes colour.
3. While picked up, dragging moves the marker and the score updates live.
4. Releasing drops the marker at its final position; it is no longer dragged.
5. A long-press away from the marker does nothing (you cannot pick up empty space).
6. Works with touch and mouse; the drag state is pure UI state.

## Rationale

Long-press-to-pick-up (rather than a plain drag) avoids moving a shot by accident
while panning, and matches the original interaction design. Tapping stays the fast
way to place a shot. The pick-up radius is generous (6 mm) so a finger can grab the
marker comfortably even though the marker itself is only 4.5 mm.

## Design

- A `ShotPlacement` value holds the `Shot?` and an `isDragging` flag, exposed via
  `shotPlacementProvider` (Riverpod). The drag flag is UI-only state.
- `TargetCanvas` maps `onTapUp` to *place*, and the long-press callbacks
  (`onLongPressStart` / `onLongPressMoveUpdate` / `onLongPressEnd`) to
  *pick up → drag → drop*. Using `onTapUp` (not `onTapDown`) keeps taps and
  long-presses cleanly separated in the gesture arena.
- Pick-up only starts if the press is within `6 mm` of the marker centre.
- `TargetPainter` draws the marker in a distinct colour while `isDragging`.

## Verification

### Unit tests (`ShotPlacementNotifier`)
- starts empty and not dragging;
- `place` sets the shot and is not dragging;
- `pickUp` marks the shot as dragging;
- `dragTo` moves the shot while keeping it picked up;
- `drop` ends the drag and keeps the shot.

### Widget test (`TargetCanvas`)
- Place a shot in the centre (score 10.9). Long-press the marker → `isDragging`
  becomes true. Drag 5 mm outward → score becomes 9.0. Release → `isDragging`
  false and the shot stays at 9.0.

## Open questions
- Should the marker show an offset or crosshair so the impact point stays visible
  under a finger? Deferred as a UX refinement.
