# Spec 0068 — Feltskyting (field shooting), hit counter

- **Status:** Accepted (v1: the per-hold hit counter)
- **Related:** spec 0066 (the forum thread that planned this), the program
  catalogue (the ring-scored programs this sits beside).

## Context
Pappa's **planned** forum thread "Feltskyting" asks for **field shooting**
(NSF feltpistol — see norgesfelt.no). Field shooting is fundamentally different
from every program in the app so far: a **course (løype) of holds (stations)**
with **figure targets at varying distances**, scored by **hits**, not rings, and
the course **changes every competition**. So the existing model (place a shot on
a ringed face, score by distance from centre) does not apply.

The chosen v1 (confirmed with the user) is a **per-hold hit counter**: pick a
class, then for each of the course's holds record the **hits** and **inner hits**;
the app sums the total. No figure placement, no course data — just the score the
way field shooting is actually scored.

## Requirements
1. From the program list, a **Feltskyting** section offers the classes
   **Finfelt / Grovfelt / Militærfelt / Revolverfelt** (all 6 shots per hold).
2. The recorder shows the **10 holds**; each hold has a **Treff** (hits, 0–6) and
   an **Inner** (inner hits) counter with − / + buttons.
3. **Hits** are capped at the class's shots-per-hold and at 0; **inner hits**
   never exceed that hold's hits.
4. A live **total** shows hits (out of the max) and inner hits.

## Rationale
**A separate, pure domain — not the ring `Session`.** `FeltSession(feltClass,
holds)` with `FeltHold(hits, innerHits)` and `withHold(...)` that clamps; totals
are simple sums. It deliberately does **not** reuse the shot/geometry/series
machinery, because field shooting is hit-scored and course-variable. The recorder
is a self-contained `FeltScreen` holding the session in local state.

**Why not model the course.** Distances, figures and figure counts per hold come
from the yearly Løypebeskrivelse and differ per competition; recording the
**result per hold** captures the score without that data and without modelling
figure geometry or hit detection.

## Design
- `lib/features/felt/domain/felt_session.dart`: `FeltClass` enum, `FeltHold`,
  `FeltSession` (+ `start`, `withHold`, totals).
- `lib/features/felt/presentation/felt_screen.dart`: the recorder (a total header
  + a − / + counter per hold).
- Program picker: a **Feltskyting** section of four class cards launching
  `FeltScreen`.

## Verification
- **Unit:** totals sum hits/inner; hits clamp to shots-per-hold and 0; inner
  never exceeds hits.
- **Widget:** counting hits updates the total; inner is capped at hits; hits do
  not go below zero; the class name shows.

## Out of scope / next
- **Offline resume** of a felt session (the immediate next step — the recorder is
  currently in-memory).
- Showing a felt result in **"Mine økter"** and syncing it to **competitions**.
- The exact NSF **figure-bonus** scoring (a point per figure hit) and the
  spesial/magnum classes (5 shots/hold) — to confirm with pappa; v1 counts hits
  per hold (the dominant score) + inner hits (the tiebreak).
- Per-hold **distance/figure** course data (a true løype), and figure placement.
