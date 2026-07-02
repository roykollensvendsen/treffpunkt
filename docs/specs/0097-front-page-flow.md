# Spec 0097 — Home: bottom navigation and a clean start page

- **Status:** Accepted (revised after the first card-list layout was
  rejected by the owner)
- **Related:** the July 2026 UI analysis (bundle 2); specs 0084 (categories),
  0081 (felt resume), 0090 (statistics), 0094 (varsler)

## Context

The front page's app bar carried six icon-only actions, and the first
replacement (every destination as a full-width card) read as a monotonous
wall of identical cards with no hierarchy. The owner chose the standard
app answer: a bottom navigation bar, and a home tab that contains only
shooting.

## Requirements

1. A **bottom navigation bar** with five destinations — **Hjem**,
   **Mine økter**, **Statistikk**, **Konkurranser**, **Forum** — always
   visible, icon + label. The destinations reuse the existing keys, and
   switching to Mine økter / Konkurranser refreshes their background reads
   (as the old push-navigation did).
2. The **Hjem** tab contains only shooting: the resume cards («Fortsett
   økt», «Fortsett felt-økt»), a highlighted **«Skyt igjen»** card naming
   the most recent exercise (hidden with no history), and the four
   categories in a **2×2 grid**. App bar: **Treffpunkt**, with the bell
   (spec 0094) and Innstillinger.
3. **Brukerveiledning** moves to Innstillinger (its key with it).
4. **Felt** opens the course preview directly while only one course
   exists; **MIL** is a disabled «kommer senere» tile.
5. The build-version stamp (spec 0028) stays visible on the Hjem tab.

## Rationale

Bottom navigation makes every top destination one thumb-reach tap with a
permanent label — no tooltips, no scrolling, no guessing — and frees the
home tab to be about the sport. The grid halves the category footprint and
gives the «Skyt igjen» hero visual priority.

## Design

- `HomeShell` (new): a `NavigationBar` over an indexed body of the five
  existing screens (each keeps its own Scaffold/app bar); destination
  switches run the same provider invalidations the old push helpers did.
  `AuthGate` builds `HomeShell` where it built the picker.
- `ProgramPickerScreen` becomes the Hjem tab: hero + grid, no «Mer»
  section; the category grid tiles are compact Cards (disabled state for
  MIL).
- `SettingsScreen` gains a Brukerveiledning entry (`helpButtonKey`).

## Verification

### System tests
- `home_shell_test` (new): the bar shows the five labelled destinations;
  tapping each opens its screen (keys preserved); Hjem shows the app bar
  with bell + settings.
- `program_picker_screen_test`: hero/grid behaviours (Skyt igjen with and
  without history, felt resume card, MIL disabled, Felt direct, category
  navigation, resume cards) — no Mer cards.
- `settings_screen_test`: Brukerveiledning opens the manual.
- The real-flow and integration tests navigate via the bar.

## Open questions
- None.
