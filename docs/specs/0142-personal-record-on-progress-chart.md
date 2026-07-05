<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0142 — Personlig rekord på progresjonskurven

- **Status:** Accepted
- **Related:** spec 0090 (progress curves), 0101 (Ny pers!), 0102
  (Rekorder: startverdier + effective record), 0140 (felt competitions)

## Context

The Statistikk chart (spec 0090) shows how an exercise develops, and the
Rekorder page (spec 0102) knows the shooter's personal record — but the two
never meet. Looking at the curve, the natural questions are "how far below
my record am I?" and "which session was the record?". The domain expert asks
to show the personal record on the curve itself.

## Requirements

1. The progress chart draws a horizontal **pers line** at the selected
   exercise's **effective personal record** (spec 0102): the best of the
   manual baseline (startverdi) and **every** recorded session of the
   exercise — pending and synced, dated and undated — so it always agrees
   with the Rekorder page.
2. The line is an **annotation, not a series**: recessive (muted ink,
   dashed hairline — visibly different from the solid gridlines) with a
   direct label **«Pers N»** in text ink, so it needs no legend entry.
3. The record's **points** value places the line (innertreff is only the
   tiebreak, spec 0085 — it has no place on a points/inner chart line).
4. The y-scale **includes the record**, so a startverdi above every plotted
   session keeps the line (and the gap up to it) visible instead of
   clipping it.
5. ~~The **felt curve** mixes both shooter groups into one series
   (spec 0090) while felt records are per group (spec 0102). The pers line
   is drawn only when every plotted round is from **one** group — that
   group's effective record; with mixed groups no line is drawn (their
   points are not comparable, spec 0140).~~ **Superseded by spec 0143:**
   the felt statistics are per group, so every felt curve carries its
   group's record.
6. The screen-reader summary (spec 0090 req 7) names the record:
   «Pers: N poeng.»

## Rationale

- **Effective record, not plotted maximum.** The plotted curve omits
  undated sessions and knows nothing of the startverdi; the Rekorder page
  is the record's single source of truth. Showing anything else on the
  chart would contradict the trophy page one tap away.
- **A reference line, not a highlighted marker.** The record can live
  outside the plotted data (startverdi, undated session), where there is no
  marker to highlight; a horizontal line also shows the *distance* from
  every session to the record, which is the question being asked.
- **Dashed, muted, direct-labelled** follows the chart's design rules
  (spec 0090): gridlines stay solid hairlines, annotations must not outrank
  data ink, text wears text ink, and identity comes from a direct label
  rather than a legend entry.

## Design

- `StatisticsScreen` watches `personalRecordsProvider` (the baselines) and
  computes the selected exercise's effective record with `bestResult`
  (spec 0102) over the baseline plus every merged session of the exercise;
  for the felt curve it uses `feltRecordKey(group)` and the rounds of the
  single plotted group, or nothing when groups mix.
- `ProgressChart` gains a `persPoints` field (int?, null = no line), passed
  to the painter, included in the y-max, painted as a 1 px dashed line in
  the muted colour with a bold «Pers N» label in text ink at the left edge
  (below the line when it hugs the top of the plot), and spoken in the
  semantics summary.

## Verification

### System tests (widget)

- With sessions only, the chart receives the plotted maximum as
  `persPoints` and the semantics summary contains «Pers: 570 poeng».
- A baseline above every session (seeded via
  `initialPersonalRecordsProvider`) wins: `persPoints` is the baseline's
  points.
- An **undated** session above every dated one sets the record even though
  it is not plotted.
- Felt: rounds of one group yield that group's record (baseline included);
  rounds of both groups yield `persPoints == null`.

## Open questions

- Marking *which session* set the record (a filled trophy marker on that
  point) was considered and deferred: the record is often not on the chart
  at all (startverdi, undated session), and the line answers the distance
  question without a second annotation.
