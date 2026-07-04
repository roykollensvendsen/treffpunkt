# Spec 0139 — Pillen glir til sirkel

- **Status:** Accepted
- **Related:** owner follow-up in-session 2026-07-04 («kan vi animere
  overgangen?»); spec 0138 (the collapsing buttons)

## Context

Spec 0138's collapse swapped two widgets through an
`AnimatedSwitcher` — a scale-out/scale-in pop, not a transition the
eye can follow.

## Rationale

One continuous morph instead: a single button whose label's width and
opacity are driven by the same eased curve
(`TweenAnimationBuilder`, 250 ms), clipped so the text never spills
out of the shrinking pill — the pill visibly glides into the circle
and back. The label survives as tooltip and semantics; the test key
is stable across the whole animation.

Hard-won detail: the label sits in an `Align(widthFactor: t)` — and an
`Align` given a `widthFactor` but no `heightFactor` expands to ALL
available height, which silently blew the button up to fill the
Scaffold and swallow taps meant for the list beneath. `heightFactor:
1` pins it.

## Requirements

1. The extended→round transition is one continuous animation of the
   same widget (no widget swap); 250 ms, eased.
2. The button's footprint is icon-sized when collapsed and never
   exceeds its visible pill (no invisible hit area).

## Verification

- The spec-0138 widget test asserts by measured width: > 100 px
  extended, < 70 px collapsed, re-extended at the top.
- The full suite passes — the competitions interaction tests double
  as the no-invisible-hit-area regression net (they failed loudly
  when the Align expanded).
