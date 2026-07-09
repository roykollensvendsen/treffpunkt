<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0158 — Program-radene bærer disiplin-glyfen

## Summary

On Hjem, each category tile leads with its discipline pictogram; one level in,
the program rows led with nothing and only carried a trailing chevron. The same
"pick from a list" step spoke two visual languages back to back, and the
discipline glyph you tapped on Hjem vanished on the next screen. The program
rows now lead with the same discipline pictogram, so the glyph is the consistent
identifier across both levels.

## Rationale

- Adjacent screens for the same conceptual action looked structurally different:
  Hjem tiles had *pictogram, no chevron*; program rows had *chevron, no icon*.
  The pictogram — the strongest identifier — was dropped exactly when the user
  drilled in.
- Putting the glyph back on the rows makes the discipline the through-line and
  matches the tile you came from. The chevron stays a list-row idiom (Hjem's
  grid tiles keep none — a trailing chevron there crowds the narrow 2-column
  tiles and wraps the longest label, so the pictogram, not the chevron, is the
  element unified across the two idioms).
- The rows share one category, so all wear that category's glyph; this reinforces
  "you are in NSF Luft" rather than reading as noise.

## Design

- `TappableCardTile` gains an optional `leading` widget, passed straight to the
  inner `ListTile.leading` (the one shared navigation tile of the picker pages,
  spec 0084) — so the accessibility contract stays in one place.
- `categoryPictogram(ProgramCategory)` (the mapping already behind the Hjem
  tiles) is made public and reused: each ring program row and each felt course
  row passes `leading: categoryPictogram(category)`.
- No change to titles, subtitles, the chevron, tap behaviour or semantics; the
  Hjem tiles are untouched.

## Verification

- `tappable_card_tile_test`: a tile given `leading` renders it; without one it
  renders none (existing behaviour).
- `program_category_screen_test`: an NSF Luft program row contains a
  `PelletPictogram`; a felt course row contains a `FeltFiguresPictogram`.
- Visual: rendered the NSF Luft list and the Felt list, light and dark, signed
  off before merge.
