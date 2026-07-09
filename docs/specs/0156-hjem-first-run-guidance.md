<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0156 — Ledetekst på et tomt Hjem (første gang)

## Summary

On a brand-new install — no session to resume and no history yet — Hjem showed
just the 2×2 category grid and the coffee card floating in the top third, with
the lower half of the screen blank. A short lead-in now sits above the grid on
that first-run state only — «Velg en gren for å starte økta di» — so the screen
guides a newcomer to start instead of reading as unfinished.

## Rationale

- The entry screen is the app's first impression. With no «Skyt igjen» hero yet
  (it needs history) and no «Fortsett»-card, nothing framed the grid or told a
  first-time user what to do, and the emptiness read as "unfinished app". This is
  the highest-stakes moment — every new user hits it exactly once.
- The grid **is** the call to action; a competing second CTA would only muddy it.
  A single orienting line is the lightest touch that gives the screen a purpose.
- Shown only on the empty first-run state: once there's a resume card or history,
  the hero/resume cards already orient the user and the line would be noise.

## Design

- When there is no saved ring session, no saved felt session and no shoot-again
  history (`saved == null && feltSaved == null && last == null`), render a
  `Text` («Velg en gren for å starte økta di», `firstRunLeadKey`) above the
  category rows, in `titleMedium` on `onSurfaceVariant`. Otherwise keep the plain
  spacing that was there.
- No new CTA, no change to the grid, the cards or navigation.

## Verification

- `program_picker_screen_test`: the lead-in shows on a fresh, empty picker;
  it is absent once a saved session, a saved felt session or shoot-again history
  is present.
- Manual: rendered on the first-run state, light and dark, signed off before
  merge.

## User docs

- Getting-started: note that a first-time Hjem invites you to pick a discipline
  to start.
