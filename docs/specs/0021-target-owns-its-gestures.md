# Spec 0021 — The target owns its gestures

- **Status:** Accepted
- **Related:** spec 0006 (series scoring screen), spec 0005 (interactive target
  zoom), ADR-0003 (Riverpod)

## Context

The shooting target on the session screen is interactive: you can zoom in with a
mouse-wheel / trackpad scroll and pan it by dragging, so you can place each shot
precisely (the `InteractiveViewer` in `series_target.dart`, with
`trackpadScrollCausesScale: true`). That target sits inside the session screen's
`SingleChildScrollView`, which scrolls the whole page when the content is taller
than the window.

On web and desktop the two compete. A mouse-wheel or trackpad scroll, and a
click-drag, made while the pointer is over the target are swallowed by the page's
`Scrollable` — the page scrolls instead of the target zooming or panning. The
user reported it as "zoom and pan don't always work; the scroll goes to the page
instead of the target." The target's gestures are effectively unreachable
whenever the page can scroll.

## Requirements

1. While a mouse / trackpad pointer is over the interactive target, the target
   owns the wheel/trackpad zoom and the drag pan: these gestures must reach the
   target's `InteractiveViewer` and must **not** scroll the surrounding page.
2. Moving the pointer off the target restores normal page scrolling: a
   wheel/trackpad scroll over any non-target area (header, shots list, legend)
   scrolls the page as before.
3. The change is mouse/trackpad-only. The touch pinch-to-zoom path on phones and
   tablets is unchanged; no other gesture behaviour on the screen regresses.
4. The target's own gesture logic (tap to place, long-press to move, the
   `InteractiveViewer` configuration) is untouched.
5. Riverpod state is unaffected; the screen still passes `very_good_analysis` and
   is testable headlessly.

## Rationale

The clean, idiomatic fix is to stop the page `Scrollable` from competing for the
pointer while it is over the target, rather than to fight the gesture arena with
custom recognisers. A `SingleChildScrollView` consults its `physics`: setting
them to `const NeverScrollableScrollPhysics()` makes the page refuse the scroll
offset and the drag, so the wheel/trackpad scroll signal and the drag fall
through to the `InteractiveViewer` underneath, which then zooms and pans. When
the pointer is anywhere else, the physics are the platform default (`null`) and
the page scrolls normally.

A `MouseRegion` around the target tracks "is the pointer over the target?".
`MouseRegion`'s `onEnter` / `onExit` fire only for hovering devices — mouse and
trackpad — so touch is never affected: a finger does not "hover", so `_overTarget`
stays false on a phone and the page keeps its normal physics, leaving the touch
pinch-to-zoom and single-finger page scroll exactly as they were.

Alternatives rejected: (a) a custom `Listener` translating `PointerScrollEvent`
into `InteractiveViewer` transforms re-implements what `InteractiveViewer`
already does and is fragile; (b) removing the page scroll altogether breaks small
windows where the content genuinely overflows; (c) an `Expanded`/`Flexible`
non-scrolling target region changes the established responsive layout and the
overflow behaviour the other specs rely on.

## Design

`SessionView.build` delegates the scroll body to a small private
`StatefulWidget`, `_SessionScrollBody`, that owns the hover state:

```
_SessionScrollBody(
  wide: bool,                 // responsive flag from the LayoutBuilder
  maxWidth: double,           // _maxWideContentWidth or _maxContentWidth
  builder: (hoverGuard) => Widget,   // builds the layout, wrapping the target
)
  bool _overTarget = false;
  Widget _hoverGuard(Widget target) => MouseRegion(
        onEnter: (_) { if (!_overTarget) setState(() => _overTarget = true); },
        onExit:  (_) { if (_overTarget)  setState(() => _overTarget = false); },
        child: target,
      );

  build => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: _overTarget ? const NeverScrollableScrollPhysics() : null,
        child: _CenteredContent(maxWidth: maxWidth, child: builder(_hoverGuard)),
      );
```

`SessionView.build` keeps the `LayoutBuilder`, the `wide` flag, the
`_wideLayout` / `_stackedLayout` builders, all keys, `SeriesTarget` and the
`InteractiveViewer` config exactly as they are; it now passes the target through
`hoverGuard` so only the target is wrapped, and returns `_SessionScrollBody`
instead of the inline `SingleChildScrollView`. The `setState` guards avoid
needless rebuilds when `onEnter` / `onExit` repeat.

Because the guard is a `MouseRegion`, `_overTarget` only ever becomes true for a
hovering (mouse / trackpad) pointer, so the touch path is structurally
unaffected.

## Verification

### Widget tests (`test/features/scoring/presentation/series_screen_test.dart`)

- **Physics suspend on hover, restore on exit** (deterministic): pump the session
  screen; the page `SingleChildScrollView.physics` is initially **not** a
  `NeverScrollableScrollPhysics`. Move a synthetic mouse pointer
  (`PointerDeviceKind.mouse`) to the centre of the target (`seriesTargetKey`):
  the page `SingleChildScrollView.physics` is now
  `isA<NeverScrollableScrollPhysics>()`. Move the pointer off the target: the
  physics revert to not-`NeverScrollableScrollPhysics`.
- **End-to-end wheel/drag fall-through** (not asserted in a widget test): with the
  page physics suspended, Flutter's `Scrollable` registers neither the pointer
  scroll signal nor a drag recogniser (it bows out when the physics rejects the
  user offset — `NeverScrollableScrollPhysics.allowUserScrolling` is `false`), so
  the wheel/trackpad scroll and the drag reach the target's `InteractiveViewer`. A
  headless behavioural test of this proved unreliable (synthetic
  `PointerScrollEvent`s do not drive the page `ScrollPosition` under
  `flutter test`), so the deterministic physics-suspend test above is the guard
  and the fall-through rests on the framework semantics, verified against the
  Flutter SDK source (`scrollable.dart` `_receivedPointerSignal`).
- All existing `series_screen` / `series_target` tests stay green (tap-to-place,
  long-press-to-move, the responsive layout, the accessibility semantics and the
  scorecard caption are unchanged).

## Open questions

- Touch pinch-to-zoom and single-finger pan on the target are handled by the
  follow-up spec 0022 (suspend the page scroll while a finger is on the target).
  A drag that *starts* on the target no longer scrolls the page on any platform;
  the surrounding content scrolls normally.
