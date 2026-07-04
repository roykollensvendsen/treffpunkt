# Spec 0138 — Pennen: flytende knapper som krymper

- **Status:** Accepted
- **Related:** owner request in-session 2026-07-04 («de to flytende
  knappene kan godt være runde og teksten bli borte når vi scroller
  litt nedover i listene. gjerne et penn/blyant symbol i stedet for
  +»)

## Context

«Ny tråd» and «Ny konkurranse» stayed fully extended over the lists,
covering content while scrolling — and the + icon said less than a
pen would about what the buttons do (write something new).

## Rationale

The Material pattern, shared once: a `CollapsingFab` in core that is
extended (pen icon + label) at the top of the list — where there is
room and a first-time user needs the words — and collapses to a round
icon-only button as soon as the list is scrolled (> 64 px), animated,
with the label kept as the tooltip/semantics. Each screen feeds it a
scroll signal via a `NotificationListener` around its body, so no
scroll controllers change hands.

## Requirements

1. Both buttons show the pen (`edit_outlined`) and their label at the
   top of the list, and collapse to round icon-only while scrolled.
2. Scrolling back to the top re-extends them; the semantic label and
   the test key survive both states.

## Verification

- Widget: at the top the label and pen are visible; after a scroll
  the label is gone but the button (by key) remains; scrolling back
  re-extends it.
- Existing FAB tests (tap-to-create, above-navbar position) pass
  unchanged.
