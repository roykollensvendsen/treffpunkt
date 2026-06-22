# Program catalogue

The authoritative reference for the official shooting **programs** Treffpunkt
supports. Each seeded `ProgramDefinition` (see
[ADR-0012](../adr/0012-shooting-session-domain-model.md)) implements one row here.

## Scope

**In scope — concentric-ring targets** (scored 1–10 or 5–10, integer + optional
inner ten, or decimal). **Out of scope** (different scoring, separate later):
field (*felt*, T96/Kråkefelt), silhouette *figures*, magnum, PPC 1500, running
target (*løpende elg*) and shotgun.

## Sourcing & confidence

Target-face **geometry** is taken verbatim from **ISSF Technical Rules §6.3.4**
(NSF reprints the same tables) — all **high** confidence, cross-checked against
Wikimedia/target-maker spec sheets. Program **structures** (shot counts, faces)
are high-confidence at the ISSF level; a few NSF-specific **timings** rest on club
/ SNL sources because the canonical *NSF Pistolregler* PDF is offline. National-only
events (hurtigpistol, sprintluft, fripistol-B, NAIS, 15 m/200 m rifle) are sourced
from the NSF 2019/2023 *Nasjonalt regelverk*. Items still needing the father are
listed at the bottom. Confidence: **H** / **M** / **L**.

## Target faces (shared geometry)

Diameters in millimetres, centre at the origin. The full ring table is the 10-ring
plus the step repeated outward.

| Face | Rings | 10-ring ⌀ | Step (⌀) | Inner-ten ⌀ | Black ⌀ | Scoring | Conf. |
|------|-------|-----------|----------|-------------|---------|---------|-------|
| 10 m air rifle | 1–10 | 0.5 | +5 → 45.5 | — | 30.5 | decimal 10.0–10.9 | H |
| 10 m air pistol | 1–10 | 11.5 | +16 → 155.5 | 5.0 | 59.5 | integer + inner-ten (decimal in finals) | H |
| 25 m precision / 50 m pistol | 1–10 | 50 | +50 → 500 | 25 | 200 | integer + inner-ten | H |
| 25 m rapid / silhouette | 5–10 | 100 | +80 → 500 | 50 | 500 (whole) | integer + inner-ten | H |
| 50 m rifle | 1–10 | 10.4 | +16 → 154.4 | 5.0 | 112.4† | integer + X (decimal?†) | H (geom) |
| 300 m rifle | 1–10 | 100 | +100 → 1000 | 50 | 600† | integer + X (decimal?†) | H (geom) |
| Colt (Fripistol-B, NSF) | 1–10 | 25 | +25 → 250 | 12.5 | — | integer + inner-ten | H |
| 10 m air-duel (NSF) | 5–10 | 23 | +26.5 → 155.5 | 11.5 | — | integer + inner-ten | H |
| 200 m rifle (NSF, scaled) | 1–10 | 64 | +66.67 → 664 | 30.67 | 397 | integer + inner-ten | H |
| 15 m / luftsprint (NSF) | 1–10 | 2 | +9 → 83 | — | 38 / 29 | integer | H |

The **gauge** (inward-edge rule) is ⌀ 5.6 mm for .22, ⌀ 9.65 mm for centre-fire
**pistol** (grovpistol) and ⌀ 8 mm for the centre-fire **rifle** (300 m, ≤ 8 mm
class)† — the two centre-fire gauges differ because the bullet edges do.

† The rifle rows above are **geometry-confirmed (ISSF §6.3.4) but
course-of-fire-, scoring-style-, black- and calibre/gauge-unconfirmed**: scoring
style (integer + X vs decimal), the exact NSF course of fire, the rendered black
diameter, and — for 300 m — the exact centre-fire gauge edge are
confirm-with-the-father flags (specs 0017 / 0018). They are seeded integer + X
with the geometry shown; the flagged facts are not asserted as sourced. See the
"Still to confirm" list below.

## Programs

| Program (NO) | ISSF | Dist. | Calibre | Stages → faces | Shots | Scoring | Conf. |
|---|---|---|---|---|---|---|---|
| Luftrifle | 10 m Air Rifle | 10 m | air 4.5 mm | 1 face (air rifle) | 30 / 40 / 60 | decimal | H |
| Luftpistol | 10 m Air Pistol | 10 m | air 4.5 mm | 1 face (air pistol) | 60 (40 W/V/J) | integer + X | H |
| Finpistol (6F) | 25 m Sport Pistol | 25 m | .22 | Presisjon 6×5 (precision) + Duell 6×5 (rapid, 3 s/7 s) | 60 | integer + X | H |
| Grovpistol (6G) | 25 m Centre-Fire | 25 m | 7.62–9.65 mm | as finpistol (precision + rapid) | 60 | integer + X | H |
| Standardpistol (5) | 25 m Standard | 25 m | .22 | 3 stages 4×5 on precision @ 150/20/10 s | 60 | integer + X | H |
| Silhuettpistol (4) | ~25 m Rapid Fire | 25 m | .22 | rapid face; 2×30 @ 8/6/4 s | 60 | integer + X | M |
| Hurtigpistol (7F/7G…) | national | 25 m | .22 / c-f | rapid face; prøve + 4×5 @10 s + 4×5 @8 s + 4×5 @6 s | 60 | integer + X | H |
| Fripistol (2A) | 50 m Pistol | 50 m | .22 | precision/50 m face; 6×10, 2 h | 60 | integer + X (X scored) | H |
| Sprintluft (3D) | national | 10 m | air 4.5 mm | air-duel face; 30 in 15 min | 30 | integer + X | H |
| 50 m rifle | 50 m Rifle | 50 m | .22† | 50 m rifle face; 6×10 prone (3×20 / 3×40?†) | 60 | integer + X (decimal?†) | M† |
| 200/300 m rifle | 300 m Rifle | 200/300 m | c-f ≤ 8 mm† | 300 m / scaled 200 m face; 6×10 (3×20 / 3×40?†) | 60 | integer + X (decimal?†) | M† |

(NAIS, fripistol-B, 15 m rifle and 10 m luftsprint are documented in the sources;
seeded as confirmed.)

## Still to confirm with the father / a live NSF rulebook
- **Per-series precision time** for fin/grov: 5 min (Evje) vs 6 min (SNL).
- **Silhuettpistol** exact series-per-timing and single-turning vs 5-target bank.
- **Luftpistol** face: ISSF 11.5 mm (asserted) vs the national air-duel face.
- **Fripistol** modelling: true 50 m (precision face) vs national Fripistol-B 25 m
  (Colt face) — or both.
- **NAIS** shot count (30 per 2011 reglement vs 6×5 per Evje).
- Class reductions for women / juniors / veterans.
- **50 m & 300 m rifle** (specs 0017 / 0018 — geometry is ISSF-sourced, the rest
  is flagged):
  - **Course of fire** — seeded as 6×10 prone; confirm 60 prone vs 3×20 vs 3×40.
  - **Scoring style** — seeded integer + X; confirm whether NSF scores these to a
    decimal (as electronic targets / ISSF finals do).
  - **Black diameter** — 50 m ⌀ 112.4 mm, 300 m ⌀ 600 mm asserted (render-only);
    confirm the exact NSF black.
  - **Calibre / gauge** — 50 m asserted .22 LR (only permitted class?); 300 m
    centre-fire ⌀ 8 mm gauge edge (vs the ⌀ 9.65 mm pistol gauge) — confirm the
    exact ≤ 8 mm class gauge.

## Sources
- ISSF Technical Rules §6.3.4 (target tables) and Pistol/Rifle Rules (event
  structures); NSF *Nasjonalt regelverk* (pistol 2019, rifle 2023).
- Evje Pistolklubb, Oslo PK, Store norske leksikon (SNL), Wikipedia/Wikimedia and
  target-maker spec sheets (cross-checks).
- Spec 0001 (10 m air rifle).
