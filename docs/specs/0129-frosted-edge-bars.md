# Spec 0129 — Frostede kanter: innholdet skinner gjennom

- **Status:** Accepted
- **Related:** owner request in-session 2026-07-04 («la komponentene på
  toppen og bunnen av skjermen være halv gjennomsiktige (sprer lyset
  fra komponentene under når man scroller) slik at man ser tydelig at
  det går an å scrolle lenger opp/ned»)

## Context

The app's top and bottom bars were opaque, so a list that continued
beneath them gave no visual hint of it — the classic «is there more?»
doubt.

## Rationale

Frosted glass is the established answer: the bars become translucent
with a backdrop blur, so content scrolling beneath them shines
through, diffused — an unmistakable «there is more» signal that also
keeps the bars' own labels readable. Three shared pieces in core keep
every surface identical: `FrostedAppBar` (a drop-in `AppBar`),
`FrostedBottomBar` (wraps any bottom bar) and `frostedScrollPadding`
(the scrollable's padding so content starts clear of the bars but
slides under them). Applied to the surfaces where scrolling happens:
the home shell's navigation bar, the five tab roots' app bars, and
the recording screen's app bar and action bar. Remaining inner
screens keep their opaque bars for now and can adopt the pieces one
by one.

## Requirements

1. The home shell's bottom navigation is frosted and content extends
   beneath it (`extendBody`).
2. The five tab roots (Hjem, Mine økter, Statistikk, Stevner, Forum)
   use `FrostedAppBar` with `extendBodyBehindAppBar`, their scroll
   content padded with `frostedScrollPadding` so it slides under both
   bars.
3. The recording screen's app bar and its Angre/Fullfør bar are
   frosted the same way.
4. Bar content stays readable (≥ ~0.7 surface opacity).

## Verification

- Widget: the shell renders a frosted (backdrop-filtered) navigation
  bar and `extendBody`; a tab root and the recording screen render
  `FrostedAppBar` with `extendBodyBehindAppBar`; existing suites pass
  (the bars' keys and semantics are unchanged).
- Screenshot with content mid-scroll shining through both bars.
