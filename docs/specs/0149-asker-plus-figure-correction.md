<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0149 — Asker+ hold 9 og 10: figurretting fra fasitfoto

## Summary

A photo of the physical NorgesFelt Asker+ course (range, 2026-07-08) showed
the hand sketch (spec 0145) was slightly wrong. Two corrections:

- **Hold 9** drops from six hexagons to **five**, alternating green-lying /
  red-standing and starting and ending on green-lying (**G-R-G-R-G**). Still
  laid out in two rows (3 + 2) so the hold picture keeps its proportions.
- **Hold 10** becomes, left→right: a **lying green hexagon**, the **owl**,
  the **three stolper rotated 90°** (three lying green stolper stacked, each
  the tre-kvadrater figure — spec 0086 — with the middle square as inner
  zone), and a **standing green hexagon**. The big oval is gone; both
  hexagons are green.

## Rationale

- The figures must match the sheet the family actually shoots. The sketch
  (spec 0145) over-counted hold 9 by one and mis-described hold 10 (it had
  an oval and vertical stolper; the real hold has two green hexagons
  flanking three *lying* stolper, no oval).
- The per-course maxima are unchanged (103/90): hold 9 lost a figure and
  hold 10 gained one, and the min(shots, figures) terms net out.

## Verification

1. `felt_course_test`: hold 9 is five hexagons; hold 10 is hexagon, owl,
   three stolper, hexagon; Asker+ maxima stay 103/90.
2. `felt_hold_art_data_test`: hold 9 art has five equal-area ringed
   hexagons in two rows (G-R-G-R-G); hold 10 art is a green hexagon, the
   owl, nine stolpe squares grouped by row (anchored 2/5/8, middle inner),
   and a green hexagon — six scoring figures.
3. Renders reviewed and signed off by the domain expert (2026-07-08).
