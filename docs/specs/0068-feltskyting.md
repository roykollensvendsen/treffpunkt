# Spec 0068 — Feltskyting (figure-based field shooting)

- **Status:** Accepted — figure catalogue + course preview shipped; recording &
  scoring planned.
- **Related:** the program catalogue (ring-scored programs this sits beside);
  forum thread "Feltskyting" (norgesfelt.no) that planned it.

## Context
Field shooting (NSF feltpistol, **norgesfelt.no**) is scored by **hits on figure
silhouettes** at varying distances across a **course of holds** — not by rings.
An early hit-counter version was rejected by the domain expert: the real thing
needs the **actual figures** (hare, wolf head, ptarmigan, hexagon, triangle,
circles, …) drawn to scale, recorded as hits/inner per figure.

The NorgesFelt 2026 course (reconstructed from the official files on
norgesfelt.no): **8 holds**, distances 15/25 m, shooting positions, **10 s**
shooting time, an **inner zone on every figure**, max **80/47** points.

## Requirements (this increment)
1. A **figure catalogue**: each NorgesFelt figure drawn as scalable **vector**,
   with its inner zone — geometric shapes parametrically, the three animal
   silhouettes as **traced** outlines.
2. A **course preview** (the NorgesFelt 2026 løype): the 8 holds with their
   figures rendered to **real relative size**, reachable from the program list
   under **Feltskyting**.
3. Figures are drawn the way the **real targets** look: a **black silhouette on
   a white plate** (independent of the app theme), with the **inner zone** ringed
   at the figure's **centre of mass** — so the ring sits on a triangle's lower
   third or an animal's body, not the bounding-box centre.

## Rationale
**Vector figures, reconstructed faithfully.** Geometric figures (circle, oval,
triangle, hexagon, stripe, egg, bowling pin) are parametric paths. The animals
were **traced from the official hold images** (potrace → contour) into
normalised polygon paths (`felt_animal_paths.dart`), so they scale cleanly and
match the originals. Each figure carries a real cm size, so a hold renders its
figures to true relative scale at a shared px-per-cm.

**A separate feature, not the ring `Session`.** Field shooting is hit-scored and
the course changes yearly, so `felt/` has its own domain (`FeltFigure`,
`FeltHoldDef`, the `norgesfelt2026` course) and presentation, deliberately apart
from the ring scoring machinery.

## Design
- `felt_figure.dart`: `FeltFigureType` + `FeltFigure` (type, cm size, inner zone).
- `felt_animal_paths.dart`: generated, traced animal polygons (hare/wolf/rype).
- `felt_figure_painter.dart`: `figurePath` (parametric + polygon), `figureCentroid`
  (area centroid for the inner-zone placement) + `FeltFigureView` (draws the black
  silhouette on a white plate with the inner ring at a given px-per-cm).
- `felt_course.dart`: the 2026 course (8 holds, figures with cm sizes).
- `felt_course_screen.dart`: the preview, opened from the picker.

## Verification
- **Widget:** the preview shows all 8 holds and their figures (the traced animals
  and a circle render).
- **Unit:** `figureCentroid` centres symmetric shapes on the box, places a
  triangle two-thirds down, and lands the animals on their body (off the box
  centre) — matching where the photos ring the inner zone.
- Figures proven faithful by re-rendering the generated paths against the source
  images during reconstruction.

## Out of scope / next (pending the domain expert)
- **Recording & scoring**: per hold, mark hits + inner per figure (or place
  shots), with the total. Blocked on two NorgesFelt details asked of pappa:
  **shots per hold**, and the **Treff vs Poeng** rule (figure bonus?).
- Refine the egg / stripe / bowling-pin / 1-6 shapes (currently approximated).
- Offline resume, "Mine økter", competition sync; loading a different yearly
  course.
