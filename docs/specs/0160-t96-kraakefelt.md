<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0160 — T96 («Kråkefelt») som feltprogram

## Summary

Add **T96** — the national field-shooting exercise also known as
*Kråkefelt* — as a third felt course. Everything follows the official NSF
rulebook *Nasjonale pistolregler for feltpistol og T96* (2026), § 8.26:

- **16 series** (standplasser), all on the same **5-delt T96 target**:
  five circular figures ⌀ 110 mm with a ⌀ 45 mm inner zone, centre
  spacing 240 mm horizontally and vertically (the five-face of a die),
  middle figure centred on the four others (§ 8.26.4).
- **Program** (§ 8.26.3), series → distance / time / position:
  1–6 at **11 m** and 7–12 at **15 m**, each block 150 s, 150 s, 20 s,
  20 s, 10 s, 10 s alternating **stående fri / stående én hånd** (fri on
  the odd series); 13–16 at **25 m**: 150 s, 150 s, 20 s, 20 s, all
  **stående fri**. Exception: **Magnum (Gruppe 3) shoots every series
  with two hands**.
- **Groups** as in ordinary felt (§ 8.25.3): Gruppe 1 six shots per
  series, Gruppe 2 five, and — unlike NorgesFelt — **Gruppe 3** (Magnum,
  five shots) is offered.
- **Scoring** (§ 8.26.5): 1 point per hit, 1 per distinct figure hit,
  **and 1 per inner-zone hit** — the rulebook's own example: 6 hits over
  5 figures with 6 inner zones = 17 points. Course maxima follow:
  **272** (Gruppe 1), **240** (Gruppe 2), **240** (Gruppe 3).

Recorder, save/resume, history, sync, personal records, statistics and
competitions all reuse the felt engine; stored rounds carry course id
`t96`.

## Rationale

- Requested by the domain expert (2026-07-16): «T96 … skutt i samme
  grupper, med gruppe 3 i tillegg med 5 skudd. Skiva er 5-delt T96» —
  with the series/distances/positions to be taken from the rules, which
  is exactly § 8.26.3 above.
- T96 *is* felt («konkurransen følger i sin helhet NSFs feltreglement»,
  § 8.26.1) with a fixed course, so modelling it as a `FeltCourse` gives
  the whole recording/sync/competition stack for free. The two genuinely
  new rules — inner zones scoring points and Gruppe 3 being offered —
  become course properties, not forks of the engine.
- The target is five plain circles; no new traced figure art is needed
  (the composed-art circle shape already exists). This deliberately does
  not touch the NorgesFelt figure drawings.

## Design

Domain (`felt_course.dart`, `felt_scoring.dart` — pure Dart):

- `FeltCourse` gains `innerScores` (default `false`; `true` for T96),
  `offeredGroups` (default `FeltShooterGroup.offered`; T96 offers
  1/2/3), `stationWord` (default `'Hold'`; T96 `'Serie'` — the
  rulebook's own word), an optional `note` (T96: the Magnum two-hands
  exception, shown on the course preview), and
  `positionFor(hold, group)` — the hold's position, except T96 ×
  Gruppe 3 → `'Stående 2 hender'` (§ 8.26.3's exception), carried as a
  per-group override map.
- `FeltHoldDef` gains an optional `time` label (`'150 sek'` …); the
  NorgesFelt holds stay `null` (their 10 s is a course-level fact and
  keeps its summary line).
- `FeltCourse.maxPoints` adds `shotsPerHold` when `innerScores` (every
  shot can be an inner hit): per series `shots + min(shots, figures) +
  shots` → 17/15/15 × 16 series.
- `FeltHoldTally` takes `innerScores` (default `false`): `points` =
  `treff + figures (+ inner)`. `FeltSessionRecord.tally` resolves the
  rule from its snapshot's `courseId` via `feltCourseById`, so every
  consumer (history, sync, statistics, records, competitions) scores
  T96 rounds correctly with no further changes.
- `t96Course` (`id: 't96'`, name `'T96'`): 16 generated hold defs, five
  full-circle figures each (⌀ 11 cm, inner 4,5 cm — *not* the flat-cut
  C-figure). `feltCourses` order: 2026, Asker+, T96.
- `FeltShooterGroup.offered` stays as the NorgesFelt default; Gruppe 3's
  «not offered» doc is scoped to NorgesFelt.

Presentation:

- `t96Art`: one composed sheet reused for all 16 series — white paper,
  five black (0xFF101010) full circles with grey inner rings, laid out
  as the die-five with true relative geometry (⌀ 110 / spacing 240 on a
  360 mm sheet). `feltArtForCourse` picks it by course id.
- Program tiles (spec 0147 pattern): T96 × its three groups → the Felt
  category lists seven tiles; subtitles use the course's `stationWord`
  («6 skudd per serie (Gruppe 1) · maks 272 poeng»).
- Recorder: title uses `stationWord` («Serie 3/16»), the header line
  shows distance · time · position (position via `positionFor`, so
  Gruppe 3 reads «Stående 2 hender»). Where `innerScores`, the score
  lines spell the breakdown «Treff X · Figur Y · Inner Z = P poeng» and
  drop the ringed-X suffix (inner is real points here, not the scoreless
  tiebreaker); NorgesFelt display is unchanged.
- Scorecard: rows named by `stationWord`, same breakdown rule.
- Course preview: per-hold cards show the time when set; the summary
  card shows the maxima for the offered groups, the `note`, and keeps
  «10 sek skytetid» only when no hold carries its own time.
- Personal records and competition creation iterate
  `course.offeredGroups`, so T96 gets three rows/programs (records key
  `'T96 · Gruppe N'`, program `'T96 (Gruppe N)'` — the existing
  encodings).

Out of scope: the § 8.26.6 doubled penalty deductions (the app records
hits, it does not adjudicate conduct penalties) and klasse A/U14/U16
administration (§ 8.26.2).

## Verification

### Unit tests

1. `t96Course` structure: 16 series; 1–6 at 11 m, 7–12 at 15 m, 13–16 at
   25 m; times 150/150/20/20/10/10 (11 m and 15 m blocks) and
   150/150/20/20 (25 m); positions alternate fri/én hånd per block, 25 m
   all fri; every series has five circle figures ⌀ 11 cm with 4,5 cm
   inner.
2. Maxima: T96 272/240/240; NorgesFelt 2026 stays 80/70 and Asker+
   103/90.
3. Tally: with `innerScores`, the rulebook example scores 17 (6 hits, 5
   figures, 6 inner); without, inner still adds nothing.
4. `FeltSessionRecord` with `courseId: 't96'` counts inner points; a
   record without a course id keeps NorgesFelt scoring.
5. Offered groups: T96 `[one, two, three]`, the NorgesFelt courses
   `[one, two]`; `positionFor` gives «Stående 2 hender» for Gruppe 3 on
   every T96 series and the series' own position otherwise.
6. `feltCourseById('t96')` resolves; T96 competition program names
   round-trip for all three groups.
7. `t96Art`: 16 sheets numbered 1..16 on white paper, five circle
   figures each, every figure with a positive inner ring, all sharing
   the same drawn geometry.

### System tests (widget)

8. The Felt category lists seven tiles; the T96 tiles read «… skudd per
   serie» with maks 272/240/240; tapping the Gruppe 3 tile opens the
   setup titled «T96 · Gruppe 3».
9. Recording T96: the recorder titles «Serie 1/16», the header shows
   «11 m · 150 sek · Stående fri» (and «Stående 2 hender» for a Gruppe 3
   round); a shot in an inner zone raises the series line to «Treff 1 ·
   Figur 1 · Inner 1 = 3 poeng» with the total following.
10. The T96 scorecard rows read «Serie N» with the inner-inclusive
    breakdown and total.
11. The T96 course preview shows 16 cards with their times, and the
    summary carries the Magnum note; the NorgesFelt preview keeps
    «10 sek skytetid».
12. The records page lists T96 rows for all three groups; creating a
    felt competition offers the three T96 programs.
