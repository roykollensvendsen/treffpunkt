# Spec 0131 — Knappene flyter over den frostede bunnmenyen

- **Status:** Accepted
- **Related:** owner report in-session 2026-07-04 («ny tråd og ny
  konkurranse knappene er nå skjult av knappelinja på bunnen av
  skjermen»); specs 0129/0130 (frosted edges)

## Context

Spec 0129's `extendBody` made each tab fill the whole screen behind
the frosted navigation bar. A tab's floating action button is
positioned by the tab's own (inner) Scaffold, which now reaches the
screen's bottom — so «Ny tråd» and «Ny konkurranse» slid in behind
the bar.

## Rationale

The shell already announces the bar's height to its body through
`MediaQuery` padding — the same channel the scroll padding uses. The
FABs simply rise by that inset. Standalone (outside the shell, e.g. a
pushed route) the inset is zero and nothing changes.

## Requirements

1. The Forum and Konkurranser FABs sit fully above the navigation
   bar inside the shell, and are unchanged standalone.

## Verification

- Widget: in the shell, each FAB's bottom edge is at or above the
  navigation bar's top edge (regression test on both tabs).
