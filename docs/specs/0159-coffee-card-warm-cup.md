<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0159 — Varm kopp på «Spander en kaffe»

## Summary

The «Spander en kaffe» thank-you card (spec 0146) led with a neutral, outlined
Material coffee glyph — indistinguishable from the app's chrome icons. It now
leads with a filled cup tinted in the palette's warm amber, so the thank-you
reads as a friendly aside rather than another piece of chrome.

## Rationale

- Everything warm and inviting about a «Vipps en kaffe» card was carried by the
  copy alone; the icon was the same muted tone as every functional icon around
  it. A small warm cup gives the card the friendly note it's meant to have.
- Spec 0100 is explicit that colours come from the theme, not hard-coded Material
  constants. The one warm accent in `TreffColors` is the amber (`draggedShot`);
  reusing it as the palette's warm tone keeps the card on-palette without
  inventing a coffee-brown. It is used purely as a colour here — not as a shot
  marker.

## Design

- The coffee card's `leading` becomes `Icon(Icons.coffee, color:
  TreffColors.of(context).draggedShot)` — a filled cup in the palette amber.
- Nothing else changes: the title, subtitle, Vipps tap and placement (last,
  below the shooting flows) are untouched — still a thank-you, never a nag.

## Verification

- `program_picker_screen_test`: the coffee card's leading is an `Icons.coffee`
  icon carrying the theme's `draggedShot` colour.
- Visual: rendered on Hjem, light and dark, signed off before merge.
