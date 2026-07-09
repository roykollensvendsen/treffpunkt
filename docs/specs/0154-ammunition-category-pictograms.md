<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0154 — Ammunisjons-piktogrammer for Luft og Fin/Grov

- **Status:** Accepted
- **Related:** 0101 (visual identity part 2 — category pictograms),
  0084 (program categories), 0097 (front-page flow)

## Summary

The two ammunition-defined categories on the program picker get pictograms
drawn from their **actual round**, in natural colour, instead of the shared
ring-target glyph: **Luft** shows a 10 m match wadcutter pellet in lead, and
**Fin/Grov** shows a .22 LR cartridge in copper and brass. The MIL silhouette
and Felt figure-pair pictograms (spec 0101) are unchanged.

## Rationale

- Under spec 0101 every category tile got its own monochrome pictogram, but
  Luft and Fin/Grov both leaned on a ring target that varied only by bull
  size — the two precision-target categories read almost the same at a
  glance. What actually separates them to a shooter is the *ammunition*: an
  air pellet versus a live cartridge.
- Drawing the real round makes the distinction instant and unambiguous, and
  the natural two-tone colouring (lead head/skirt, copper bullet on a brass
  case) carries more recognition than a tinted silhouette — so these two
  pictograms are fixed-colour, not theme-tinted like the monochrome ones.
- The outlines are **measured, not freehand**: the pellet is an octagon
  traced from the left pellet on the official COAL match-pellet data sheet
  (a wadcutter flat-head diabolo — flat head, thin waist, flared hollow
  skirt, flat base), and the cartridge is traced from the public-domain
  SAAMI-style .22 LR dimensional drawing.

## Design

- `PelletPictogram` (Luft) and `CartridgePictogram` (Fin/Grov) live beside
  the existing pictograms in `lib/core/presentation/category_pictograms.dart`.
  Each fits its normalized outline into the ambient `IconTheme` size, centred
  with a small margin, and paints in fixed natural colours — it ignores the
  theme colour by design.
  - Pellet: a lighter flat head polygon over a darker flared-skirt polygon;
    aspect ≈ 0.856 (a touch taller than wide).
  - Cartridge: a copper bullet polygon over a brass case-and-rim polygon;
    aspect ≈ 0.308 (tall and slim).
- `_categoryPictogram` on the program picker returns `PelletPictogram` for
  `nsfLuft` and `CartridgePictogram` for `nsfFinGrov`; `mil` and `felt` are
  unchanged. The tile text and layout are untouched.

## Verification

1. `category_pictograms_test`: `PelletPictogram` and `CartridgePictogram`
   each build and paint at a given size without error, and expose the
   documented outline points.
2. `program_picker_screen_test`: the Luft tile renders a `PelletPictogram`
   and the Fin/Grov tile a `CartridgePictogram`; MIL still renders a
   `SilhouettePictogram` and Felt a `FeltFiguresPictogram`.
3. Manual: the two pictograms read at 26 px tile size and enlarged, in both
   light and dark themes (rendered and signed off before merge).
