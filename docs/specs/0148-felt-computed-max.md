<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0148 — Feltmaks beregnes alltid: 47-en for Gruppe 2 var feil

## Summary

Every felt course maximum is now **computed** from the scoring rules (per
hold: shots + min(shots, figures)): NorgesFelt 2026 shows **80/70** for
Gruppe 1/2 (previously 80/**47**), Asker+ stays 103/90. The
`officialMax` override mechanism (spec 0145) is removed.

## Rationale

- Spec 0068 cited 80/47 as the official course maxima from norgesfelt.no.
  On 2026-07-07 the domain expert shot deliberate max rounds in the app:
  Gruppe 1 gave exactly 80 (official = formula ✓), but a perfect Gruppe 2
  round scored **70** — exactly the formula value (40 treff + 30 figur) —
  and he confirmed the per-shot scoring is correct. A shooter beating the
  displayed «maks 47» by 23 points makes the label absurd; whatever the 47
  on norgesfelt.no counts, it is not the maximum of *this* scoring.
- With the only official override falsified, the override mechanism has no
  user — `FeltCourse.maxPoints` computes unconditionally, one honest rule
  everywhere (program tiles, course preview, competition maxTotal).

## Verification

1. `felt_course_test`: 2026 maxima are 80/70 (asserting the formula terms);
   Asker+ stays 103/90.
2. `felt_sync_test`: a Gruppe 2 competition result submits maxTotal 70.
3. Program tiles / preview / competitions read `maxPoints` — covered by the
   existing spec 0147 tile test (subtitle carries the computed max).
