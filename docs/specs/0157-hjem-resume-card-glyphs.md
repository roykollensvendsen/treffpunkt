<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0157 — Fortsett-kortene bærer disiplin-glyfen

## Summary

When both a ring session and a felt round are in progress, Hjem shows two
«Fortsett» cards stacked together. They used to be visual twins — the same
`secondaryContainer` colour and the same `play_circle_outline` leading icon — so
you had to read the subtitle to tell "continue rifle" from "continue field".
Each resume card now carries its **discipline glyph** as its leading icon: the
ring `TargetIcon` for a scoring økt, the felt figure pair for a felt-økt.

## Rationale

- Two identical cards force the eye to fall back on reading text to distinguish
  a rifle session from a felt round — a visual-hierarchy miss on the busiest
  version of the front page.
- The app already draws these two disciplines everywhere else with distinct
  glyphs — the `TargetIcon` ring for shooting and the `FeltFiguresPictogram`
  square-and-circle for felt (specs 0100/0101). Reusing them on the resume cards
  makes the cards self-identifying and consistent with the category grid right
  below, at no extra vocabulary.
- The «Skyt igjen» hero keeps its `TargetIcon`; a scoring «Fortsett økt» sharing
  that ring glyph is correct (both are ring shooting) and the two cards are still
  told apart by their colour (`secondary` vs `primary` container) and text.

## Design

- `resumeSessionKey` card (Fortsett økt): `leading` → `TargetIcon(size: 28)`.
- `feltResumeSessionKey` card (Fortsett felt-økt): `leading` →
  `FeltFiguresPictogram(size: 28)`.
- Nothing else changes — titles, subtitles, the discard trailing button, tap
  behaviour and semantics are untouched.

## Verification

- `program_picker_screen_test`: the felt resume card contains a
  `FeltFiguresPictogram` and the ring resume card a `TargetIcon`; neither shows
  the old `play_circle_outline`.
- Existing resume/discard/tap tests unchanged.
- Visual: rendered in the full three-card cluster, light and dark, signed off
  before merge.
