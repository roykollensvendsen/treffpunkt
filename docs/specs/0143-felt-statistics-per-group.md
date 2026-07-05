<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0143 — Felt-statistikk per gruppe

- **Status:** Accepted
- **Related:** spec 0090 (progress curves), 0102 (Rekorder per felt group),
  0140 (felt competitions are fair within one group), 0142 (pers line)

## Context

The Statistikk screen offered the NorgesFelt course as **one** exercise
(spec 0090), mixing Gruppe 1 and Gruppe 2 rounds into a single curve.
That was always shaky — the groups shoot different figures, so their
points are not comparable (spec 0140) — and it broke the pers line
(spec 0142): felt records are per group (spec 0102), so a mixed curve got
**no** record shown at all. The domain expert asks where the felt pers
went.

## Requirements

1. The statistics exercise list offers the felt course **per group**:
   «NorgesFelt-løype 2026 · Gruppe 1» and «· Gruppe 2» — the exact
   record-key labels the Rekorder page uses (spec 0102) — each listing
   only when that group has a dated round, ordered after the catalogue
   programs.
2. Each felt curve plots only its group's rounds, so every point on the
   curve is comparable with every other.
3. Each felt curve gets the pers line (spec 0142) from **its** group's
   effective record: the group's baseline (startverdi) and every round of
   that group. Spec 0142's mixed-group exception (req 5) is obsolete —
   there is no mixed curve any more — and is superseded by this spec.

## Rationale

- **The group is part of the exercise.** Competitions are fair only
  within one group (spec 0140) and records are kept per group
  (spec 0102); statistics was the one place still pretending otherwise.
  Splitting the curve makes the three features tell one story — and the
  pers line falls out for free instead of needing an exception.
- **The Rekorder labels, verbatim.** Reusing `feltRecordKey(group)` as
  the exercise name means the dropdown, the trophy page and the baseline
  dialog all speak the same words.

## Design

- `StatisticsScreen` buckets felt rounds by `feltRecordKey(round.session.group)`
  instead of one shared name, offers the two keys (when populated) after
  the catalogue programs, and computes the pers for a felt key from that
  group's baseline + rounds — the same `bestResult` path as the ring
  exercises.

## Verification

### System tests (widget)

- Rounds in both groups yield **two** felt entries in the dropdown; each
  curve plots only its group's rounds and carries its own group's record
  as `persPoints` (baseline included).
- With rounds in one group only, only that group's entry is offered.

## Open questions

- None.
