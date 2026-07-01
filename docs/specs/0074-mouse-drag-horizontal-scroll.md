# Spec 0074 — Mouse-drag scrolling for horizontal strips

- **Status:** Accepted.
- **Related:** 0068 (feltskyting course preview — its per-hold figure strips).

## Context
On the **NorgesFelt-løype 2026** preview each hold shows its figures in a
horizontal strip. On a phone you swipe to see the ones off-screen, but in a
**desktop/web browser** there is no touch swipe, the mouse wheel only scrolls
vertically, and Flutter's default omits the mouse from a scrollable's drag
devices — so the figures past the edge are unreachable, and it isn't obvious the
strip scrolls at all.

## Requirements
1. Horizontal strips can be scrolled with the **mouse/trackpad** on desktop/web
   (drag, and the scrollbar).
2. It is **discoverable** that the figure strips scroll.

## Rationale
**App-wide drag devices.** The real cause is general — any horizontal scrollable
has it — so `MaterialApp.scrollBehavior` uses an `AppScrollBehavior` that adds
`mouse` and `trackpad` (and keeps `touch`/`stylus`) to `dragDevices`. Click-and-
drag then scrolls anywhere, at no cost to touch. This is Flutter's documented fix
for desktop/web scrolling.

**A visible scrollbar on the figure strips.** To make the scroll obvious (not
just possible), each hold's strip has an always-visible `Scrollbar` bound to its
own controller; the scrollbar itself is also draggable.

## Design
- `lib/core/presentation/app_scroll_behavior.dart`: `AppScrollBehavior extends
  MaterialScrollBehavior` overriding `dragDevices`.
- `lib/app.dart`: `MaterialApp(scrollBehavior: const AppScrollBehavior())`.
- `felt_course_screen.dart`: a `_FigureStrip` (stateful) wraps the per-hold
  `SingleChildScrollView` in a `Scrollbar` (own `ScrollController`,
  `thumbVisibility: true`, bottom padding so the bar clears the labels).

## Verification
- **Unit** (`app_scroll_behavior_test.dart`): `dragDevices` includes `mouse`,
  `trackpad` and `touch`.
- **Widget** (`felt_course_screen_test.dart`): the course preview shows
  `Scrollbar`s on the figure strips (plus the existing 8-holds checks).

## Out of scope
- Converting vertical wheel to horizontal scroll; arrow-button affordances.
