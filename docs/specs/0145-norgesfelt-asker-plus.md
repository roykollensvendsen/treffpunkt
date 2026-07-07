<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0145 — NorgesFelt Asker+ (en andre feltløype med hold 9 og 10)

## Summary

Add a second felt course, **«NorgesFelt Asker+»**: the eight NorgesFelt 2026
holds followed by two new holds designed by the family (layout from a
hand-drawn sketch, figures measured from official blink images):

- **Hold 9** (25 m, stående fri): six elongated hexagons (hold 8's hexagon),
  alternating **lying/standing** starting lying, coloured alternately
  **green, red, green, red, green, red**. Every hexagon has an inner-treff
  ring (white on green, light-red on red).
- **Hold 10** (25 m, stående fri), left→right: **three «stolper»** (hold 8's
  three-square stripe, green, middle square = inner zone), the **hold 1 big
  oval lying** (black, rotated 90°, inner ring kept), and an **owl («Ugle»)**
  — a new figure measured from the official owl blink (black silhouette,
  white inner-treff ring in the belly).

The recorder, scorecard, history, sync, competitions and statistics all work
for both courses; stored rounds carry their course and old rounds keep
resolving to NorgesFelt 2026.

## Rationale

- The family shoots a private extension of the official course; recording it
  should be as first-class as the official one. This is also the first proof
  that the felt feature generalises beyond one hardcoded course: today the
  course is the globals `norgesfelt2026` + `norgesfelt2026Art` plus ~10
  hardcoded name strings.
- We introduce a tiny **`FeltCourse`** domain value (id, name, hold defs,
  max-points, program/record-key encodings) and thread it through the
  screens. No schema change: the course id rides in the session snapshot
  JSON (jsonb payload for sync), and `fromJson` defaults missing ids to
  NorgesFelt 2026, so every stored round remains valid.
- **Course max must be computed, not cited**: Asker+ has no official max.
  From the scoring rules (points = treff + distinct figures per hold, inner
  is tiebreak only — specs 0080/0085): per hold max = shots + min(shots,
  figures), so course max = shots × holds + Σ min(shots, figures per hold).
  - Asker+ Gruppe 1 (6 shots): 60 + (32 + 6 + 5) = **103**.
  - Asker+ Gruppe 2 (5 shots): 50 + (30 + 5 + 5) = **90**.
  - NorgesFelt 2026 keeps its **official** 80/47 (spec 0068) untouched. Note
    the official Gruppe 2 value (47) is *lower* than the formula value (70);
    the official number wins for the official course, the formula is only
    used where no official number exists.
- The owl is a genuinely new figure type (`FeltFigureType.owl`, «Ugle»); its
  vector model (`tool/felt/models/hold-10.json`) was measured from the
  official blink with the tool/felt harness (matchScore 0.980, boundary
  median 1.0 px) and signed off by the domain expert together with the
  composed hold 9 and hold 10 renders on 2026-07-07.
- Program names follow the spec 0140 encoding («the group is the program»):
  `NorgesFelt Asker+ (Gruppe 1/2)` — old program strings must keep parsing
  to (2026, group). Records/statistics bucket per course + group
  (`NorgesFelt Asker+ · Gruppe N`), so Asker+ personal bests do not pollute
  the official-course records (spec 0143 pattern).

## Design

- `FeltCourse` (domain): `id`, `name`, `holds` (List<FeltHoldDef>),
  `maxPoints(FeltShooterGroup)`, `programName(group)`, `recordKey(group)`.
  Two instances: `norgesfelt2026Course` (wraps the existing list, official
  80/47) and `askerPlusCourse` (10 holds, computed max). `feltCourseById`
  resolves an id (unknown/absent → 2026).
- `FeltSessionSnapshot` gains `courseId` (serialised; absent → 2026).
- `tool/felt/gen_dart.py` emits holds 1–10 and two consts:
  `norgesfelt2026Art` (1–8, unchanged content) and `askerPlusArt`
  (`[...norgesfelt2026Art, hold9, hold10]`). Presentation maps course id →
  art list (`feltArtForCourse`).
- Screens take the course (tile → course screen → setup → recorder →
  scorecard/detail/my-sessions labels). The felt category shows one tile per
  course.
- Competitions: create-form offers all four felt programs;
  `feltCompetitionGroup`/new `feltCompetitionCourse` parse both encodings;
  result submission uses the round's course for `program` and `maxTotal`.
  `feltCompetitionResultId` is unchanged (course-independent).

## Verification

Unit tests:

1. `felt_course_test`: Asker+ has 10 holds; holds 1–8 are identical objects
   to `norgesfelt2026`'s; hold 9 is six hexagons; hold 10 is three stripes +
   big oval + owl; `feltCourseById` round-trips both ids and defaults
   unknown/null to 2026.
2. `felt_competition_test`: max points — 2026 stays 80/47; Asker+ is 103/90
   (and the formula terms are asserted: 60+43, 50+40).
3. `felt_competition_test`: `programName` yields «NorgesFelt Asker+
   (Gruppe 1)» / «(Gruppe 2)»; parsing maps all four program strings to the
   right (course, group); a non-felt program parses to null.
4. Record keys: 2026 keys unchanged («NorgesFelt-løype 2026 · Gruppe N»);
   Asker+ keys are «NorgesFelt Asker+ · Gruppe N».
5. `felt_session_snapshot_test`: snapshot JSON round-trips `courseId`;
   legacy JSON without the field resolves to 2026.
6. `felt_hold_art_data_test`: `askerPlusArt` has 10 holds numbered 1–10 and
   shares holds 1–8 with `norgesfelt2026Art`; hold 9 art has six ringed
   figures; hold 10 art has 11 figures forming five score groups (three
   3-square stolper anchored at indices 0/3/6 with middle `innerZone`, oval
   and owl with rings).

Widget tests:

7. Felt category screen shows both course tiles; the Asker+ tile opens the
   course screen titled «NorgesFelt Asker+» listing 10 holds and
   «maks 103/90».
8. Recorder on Asker+: title says «Hold 1/10»; recording a full Gruppe 1
   round through hold 10 produces a scorecard with 10 hold rows.
9. Scorecard for a stored Asker+ round draws hold 9/10 art (and a 2026
   round still draws 2026 art).
10. My-sessions/resume cards label an Asker+ round «NorgesFelt Asker+»;
    resuming reopens the recorder on the Asker+ course.
11. Competition create-form offers the four felt programs; shooting an
    Asker+ (Gruppe 2) competition forces Gruppe 2 on the Asker+ course; the
    submitted result carries program «NorgesFelt Asker+ (Gruppe 2)» and
    maxTotal 90.
12. Statistics/records: an Asker+ PB banners against the Asker+ key and
    lists under «NorgesFelt Asker+ · Gruppe N» without touching 2026
    records.

System tests: none — `integration_test/` does not exercise felt (verified);
the CI-only suites are unaffected.
