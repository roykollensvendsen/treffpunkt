<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0147 — Feltprogrammer som 6- og 5-skuddsvarianter

## Summary

The Felt category stops being «two courses, then pick a group inside the
recorder» and becomes **four programs**, like the ring categories: each
course is offered as a **6-shot (Gruppe 1)** and a **5-shot (Gruppe 2)**
variant. Tapping a program goes **straight to the setup step** — the course
preview with every hold is no longer in the shooting flow; it stays one tap
away behind a «Se løypa» action on the setup screen. The recorder never
asks for a group again: every entry path (program tile, resume, «Skyt
igjen», competition) now knows it.

## Rationale

- Shooters pick a concrete program everywhere else in the app; felt was
  the odd one out with its group question mid-flow. Encoding the variant
  in the tile mirrors the ring programs and removes a whole screen from
  every round (the group picker, spec 0080; the remembered group,
  spec 0099, is superseded — the "memory" is now simply which tile you
  tap). Gruppe 3 stays unoffered (spec 0088).
- Previewing all holds before shooting was mandatory but rarely wanted
  (the recorder shows each hold anyway). The preview keeps existing for
  studying the course, reachable from the setup screen, but the flow is
  tile → setup → hold 1.

## Design

- `program_category_screen`: the Felt category lists, per course, two
  `TappableCardTile`s — title = course name, subtitle
  «6 skudd per hold (Gruppe 1) · maks 80 poeng» / «5 skudd … (Gruppe 2) ·
  maks 47 poeng» (computed per course, so Asker+ shows 103/90). Keys
  `felt-<courseId>-<group>`.
- `FeltSetupScreen` takes a required `group` (the old competition-only
  `forcedGroup` generalised) and gains a «Se løypa» app-bar action opening
  the course preview.
- `FeltCourseScreen` becomes a pure preview: the «Skyt løypa» button goes
  away.
- `FeltRecordScreen`: group comes from the widget or the restored round —
  the in-recorder group picker and the «Bytt gruppe» action are removed,
  along with the remembered-group store/providers (spec 0099).
- Front page: the felt «Skyt igjen» card reopens the last round's course
  **and group**.

## Verification

Widget tests:

1. The Felt category shows four program tiles (2026 ×2, Asker+ ×2) with
   the per-variant maxima; tapping the Asker+ 5-shot tile opens the setup
   titled «NorgesFelt Asker+»; confirming opens the recorder on hold 1/10
   capped at 5 shots — no group picker in between.
2. The setup screen's «Se løypa» action opens the course preview for its
   course; the preview has no shoot button.
3. The recorder never shows a group picker: a fresh recorder with a group,
   a restored round and a competition round all start on their hold
   directly; the «Bytt gruppe» action is gone.
4. The felt «Skyt igjen» card reopens the last round's course and group
   (subtitle carries the group).
5. Competitions still lock course + group (unchanged spec 0140/0145
   encoding) — regression-guarded by the existing competition tests.
