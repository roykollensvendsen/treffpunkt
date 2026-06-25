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
| Colt (Fripistol-B, NSF) | 1–10 | 25 | +25 → 250 | 12.5 | — | integer + inner-ten | H |
| 10 m air-duel / Sprintluft (NSF) | 5–10 | 23 | +26.5 → 155.5 | 11.5 | (whole) | integer + inner-ten | H |
| 200 m rifle (NSF, scaled) | 1–10 | 64 | +66.67 → 664 | 30.67 | 397 | integer + inner-ten | H |
| 15 m / luftsprint (NSF) | 1–10 | 2 | +9 → 83 | — | 38 / 29 | integer | H |

The **gauge** (inward-edge rule) is ⌀ 5.6 mm for .22 and ⌀ 9.65 mm for the
centre-fire **pistol** (grovpistol).

## Programs

| Program (NO) | ISSF | Dist. | Calibre | Stages → faces | Shots | Scoring | Conf. |
|---|---|---|---|---|---|---|---|
| Luftrifle | 10 m Air Rifle | 10 m | air 4.5 mm | 1 face (air rifle) | 30 / 40 / 60 | decimal | H |
| Luftpistol 60 | 10 m Luftpistol 60 skudd | 10 m | air 4.5 mm | 1 face (air pistol); 6×10 | 60 | integer + X | H |
| Luftpistol 40 | 10 m Luftpistol 40 skudd | 10 m | air 4.5 mm | 1 face (air pistol); 4×10 | 40 (W/V/J) | integer + X | H |
| Finpistol (6F) | 25 m Sport Pistol | 25 m | .22 | Presisjon 6×5 (precision) + Duell 6×5 (rapid, 3 s/7 s) | 60 | integer + X | H |
| Grovpistol (6G) | 25 m Centre-Fire | 25 m | 7.62–9.65 mm | as finpistol (precision + rapid) | 60 | integer + X | H |
| Standardpistol (5) | 25 m Standard | 25 m | .22 | 3 stages 4×5 on precision @ 150/20/10 s | 60 | integer + X | H |
| Silhuettpistol (4) | ~25 m Rapid Fire | 25 m | .22 | rapid face; 2×30 @ 8/6/4 s | 60 | integer + X | M |
| Hurtigpistol fin/grov | national | 25 m | .22 / c-f | rapid/duel face; (prøve) + 4×5 @10 s + 4×5 @8 s + 4×5 @6 s | 60 | integer + X | H |
| NAIS fin/grov | national | 25 m | .22–.32 / .38–.45 | rapid/duel face; 2×5 @150 s + 2×5 duell + 1×5 @20 s + 1×5 @10 s | 30 | integer + X | H |
| Fripistol (2A) | 50 m Pistol | 50 m | .22 | precision/50 m face; 6×10, 2 h | 60 | integer + X (X scored) | H |
| Sprintluft (3D) | national | 10 m | air 4.5 mm | air-duel face; 30 in 15 min | 30 | integer + X | H |
| Storluft (luftduell-skive) | national (korona) | 10 m | air 4.5 mm | air-duel face; 4×10 | 40 | integer + X | M |
| Storluft (5,5 m) | national (korona) | 5.5 m | air 4.5 mm | std air-pistol face; 4×10 | 40 | integer + X | M |

(NAIS, fripistol-B, 15 m rifle and 10 m luftsprint are documented in the sources;
seeded as confirmed.)

Both air-pistol programs use the Norwegian display names above; the ISSF
international name for the 60-shot match is "10 m Air Pistol", kept as a
resolver alias (`ProgramCatalogue._renamedFrom`, spec 0036) so sessions and
competitions stored under it still load.

## Still to confirm with the father / a live NSF rulebook
- **Per-series precision time** for fin/grov: 5 min (Evje) vs 6 min (SNL).
- **Silhuettpistol** exact series-per-timing and single-turning vs 5-target bank.
- **Luftpistol** face: ISSF 11.5 mm (asserted) vs the national air-duel face.
- **Fripistol** modelling: true 50 m (precision face) vs national Fripistol-B 25 m
  (Colt face) — or both.
- Class reductions for women / juniors / veterans.
- **Storluft** (spec 0043): the 4×10 series split and the luftduell-face
  black-bull (cosmetic) — the FSU 2020 source gives only "40 skudd … på
  Sprintluft-skive (eller vanlig skive på 5,5 meter)". It was a corona-era
  home program (shootable unapproved), not a standing NSF program.

NAIS and hurtigpistol fin/grov are now **confirmed and seeded** (spec 0031) from
the NSF *Skyteprogrammer – Pistol* (§8.26 hurtig, §8.29 NAIS) and the NSF
*Reglement for merkeskyting til NAIS-medaljen*: hurtig is 60 shots (12×5, timed
10/8/6 s) and NAIS is 30 shots (6×5: 2×150 s + 2 duell + 20 s + 10 s), both on the
rapid/duel face.

## Sources
- ISSF Technical Rules §6.3.4 (target tables) and Pistol/Rifle Rules (event
  structures); NSF *Nasjonalt regelverk* (pistol 2019, rifle 2023).
- Evje Pistolklubb, Oslo PK, Store norske leksikon (SNL), Wikipedia/Wikimedia and
  target-maker spec sheets (cross-checks).
- Spec 0001 (10 m air rifle).
