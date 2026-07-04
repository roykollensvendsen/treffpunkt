# Spec 0132 — Klarere glass, og forumet glir under

- **Status:** Accepted
- **Related:** owner feedback in-session 2026-07-04 («kan vi gjøre det
  frossne glasset mer gjennomsiktig? Spesielt på forumsiden er det
  vanskelig å se gjennom»); specs 0129–0131

## Context

Two separate things read as «milky glass»: the frost's 72 % surface
opacity left little of the content visible, and on the forum page
nothing ever passed beneath the bars at all — the thread list stopped
above the navigation bar, so the «glass» had nothing behind it.

## Rationale

Lower the shared frost opacity to 55 %: the backdrop blur, not the
tint, is what keeps the bar's own labels readable, so the tint can be
much lighter. And give the forum's thread list the same under-bar
scrolling as the other tabs (bottom side — the filter header keeps
the top). One shared constant changes every bar at once, by design.

## Requirements

1. `frostedBarColor` uses 55 % surface opacity, everywhere.
2. The forum thread list scrolls under the navigation bar; the
   filters/presence header stays fixed and clear of the top bar.

## Verification

- Existing frosted-bar tests pass (structure unchanged).
- Screenshot: forum threads visibly passing beneath the clearer bar.
