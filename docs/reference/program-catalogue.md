# Program catalogue

The authoritative reference for the official shooting **programs** Treffpunkt
supports. Each seeded `ProgramDefinition` (see
[ADR-0012](../adr/0012-shooting-session-domain-model.md)) implements one row here,
so this page is the single source of truth — and the single home for every
"confirm with the father / NSF Skytterboka" checkpoint.

## Scope

**In scope — concentric-ring targets** (scored 1–10 or 5–10, integer + optional
inner ten, or decimal). Treffpunkt's `TargetGeometry` + `ScoringService` already
represent and score these.

**Out of scope (for now)** — different scoring paradigms, each a separate later
effort: silhouette / zone targets (*silhuettpistol*), field (*felt*: T96,
Norgesfelt, finfelt/grovfelt), running target (*løpende elg*), practical (PPC) and
shotgun (trap/skeet).

## Sourcing & confidence

Geometry is taken from the **ISSF Rule Book** (high confidence). The complete
**NSF** program set and its NSF-specific structures (series counts, time limits,
permitted calibres) are not reliably available online — the NSF "Skyteprogrammer"
document is an image scan — so every NSF-specific value below is marked
**⚑ (confirm with far / NSF Skytterboka)** and must be verified before its
`ProgramDefinition` is locked. Confidence: **H**igh / **M**edium / **L**ow.

## Target faces (shared geometry)

A program references one or more of these faces. Diameters in millimetres, centre
at the origin. "Ring step" is the increase in *outer diameter* per ring outward.

| Face | Rings | 10-ring ⌀ | Ring step | Inner-ten (X) ⌀ | Black ⌀ | Scoring | Conf. |
|------|-------|-----------|-----------|------------------|---------|---------|-------|
| 10 m air rifle | 1–10 | 0.5 | +5.0 → 45.5 | — (decimal) | 30.5 | integer + decimal 10.0–10.9 | H |
| 10 m air pistol | 1–10 | 11.5 | +16.0 → 155.5 ⚑ | 5.0 | 59.5 | integer + inner-ten (decimal in finals) | M |
| 25 m precision (pistol) | 1–10 | 50 | +50 → 500 | 25 | 200 | integer + inner-ten | H |
| 25 m rapid / duel (pistol) | 5–10 | 100 | +80 → 500 | 50 | — | integer + inner-ten | H |
| 50 m precision (free pistol) | 1–10 | 50 | +50 → 500 ⚑ | 25 | 200 | integer + inner-ten | M |
| 50 m rifle (smallbore) | 1–10 | TBD ⚑ | TBD ⚑ | TBD / decimal | TBD | decimal 10.0–10.9 | L |
| 300 m rifle | 1–10 | TBD ⚑ | TBD ⚑ | TBD | TBD | integer / decimal | L |

The **bullet gauge** (inward-edge rule: a hole touching a ring line scores the
higher ring) is ⌀ 5.6 mm for .22 and ⌀ 9.65 mm for centre-fire (ISSF, H).

## Programs

| Program (NO) | ISSF | Disc. | Dist. | Weapon class / calibre | Face(s) → stages | Series (shots × count) | Timing | Conf. |
|---|---|---|---|---|---|---|---|---|
| Luftrifle | 10 m Air Rifle | rifle | 10 m | air 4.5 mm | air rifle | 10 × N (match 60) ⚑ | match limit | H / M |
| Luftpistol | 10 m Air Pistol | pistol | 10 m | air 4.5 mm | air pistol | 5 × N (40 / 60) ⚑ | match limit | M |
| Standardpistol | 25 m Standard Pistol | pistol | 25 m | .22 | precision | 5 × 12 = 60 ⚑ | 150 / 20 / 10 s | M |
| Finpistol | 25 m (fin) | pistol | 25 m | .22 | precision + rapid → *presisjon*, *duell* | 5 × N per stage ⚑ | presisjon slow; duell timed ⚑ | M |
| Grovpistol | 25 m (grov) | pistol | 25 m | centre-fire 7.62–9.65 mm | precision + rapid → *presisjon*, *duell* | as finpistol ⚑ | as finpistol ⚑ | M |
| Fripistol | 50 m Pistol | pistol | 50 m | .22 | 50 m precision | 10 × 6 = 60 ⚑ | ~2 h total ⚑ | M |
| Hurtigpistol fin / grov | 25 m rapid | pistol | 25 m | .22 / centre-fire | rapid / duel | 5 × N ⚑ | timed (e.g. 8 / 6 / 4 s) ⚑ | L |
| Miniatyrrifle 50 m | 50 m Rifle | rifle | 50 m | .22 | 50 m rifle | per position ⚑ | match | L |
| 300 m rifle | 300 m Rifle | rifle | 300 m | centre-fire | 300 m rifle | per position ⚑ | match | L |

NAIS and any other NSF programs are added once confirmed with the father.

## To confirm with the father / NSF Skytterboka
- The complete official NSF program set (which programs; Norwegian names / codes).
- Per program: shots per series, number of series, time limits, permitted calibres.
- 10 m air pistol: the full ring table; inner-ten vs decimal in NSF practice.
- The 50 m free-pistol face exact ring table; 50 m and 300 m rifle target geometry.
- Whether finpistol / grovpistol = 6×5 *presisjon* + 6×5 *duell* (60 shots), and
  the *duell* timing (e.g. 3 s exposed / 7 s hidden, or 20 / 10 s series).

## Sources
- ISSF Technical Rules, Pistol Rules and Rifle Rules (2023); ISSF Rules for Paper
  Target Scoring.
- NSF Pistolregler; NSF "Skyteprogrammer og tillatte kalibre".
- Spec 0001 (10 m air rifle) for the air-rifle face.
