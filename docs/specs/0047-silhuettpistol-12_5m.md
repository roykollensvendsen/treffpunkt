<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0047 — Silhuettpistol 12,5 m (reduced silhouette air-pistol practice)

- **Status:** Accepted
- **Related:** spec 0040 (auto-detect holes — this is the face it was tuned
  against), spec 0005 (25 m pistol faces, whose rapid ring proportions this
  reuses), reference [program catalogue](../reference/program-catalogue.md)

## Context

The father practises air pistol at 12.5 m on a **"Siluett 12,5 m"** target — a
silhouette-pistol face with **rings 5–10 only**, the whole scoring area black,
printed on a single **A4 sheet** (the footer reads `Siluett 12,5m.dwg …`). It is
the printout the scan / auto-detect feature (spec 0040) was developed against, so
seeding it as a pickable program lets the shooter choose it directly instead of
borrowing the 25 m rapid overlay.

Measured off a photo of the print, the face is the **25 m rapid ring proportions
scaled to 0.4**: ring 5 (outer) ⌀ 200 mm, even 32 mm step inward, 10-ring ⌀ 40 mm,
inner ten ⌀ 20 mm. (⌀ 200 mm is the largest ring layout that fits A4.) Scoring is
ring-proportional, so this matches the rapid face's scoring exactly — which is why
that overlay already fit.

## Requirements

1. **One offered program** `Silhuettpistol 12,5 m`, air pistol (4.5 mm),
   **30 shots in 6×5** on the reduced silhouette face, integer + inner-ten (X),
   resolvable by name and offered in the picker.
2. **One target face** `12,5 m Silhuett`: rings 5–10, ⌀ 200/168/136/104/72/40,
   whole-black bull ⌀ 200, inner ten ⌀ 20, air calibre 4.5 mm.

## Design

- A `TargetGeometry.silhuett12_5m()` constructor with the measured ring table
  (`_silhuett12_5mRingDiametersMm`), `blackBullDiameterMm = 200`,
  `innerTenDiameterMm = 20`, `lowestRingValue = 5`, calibre 4.5 mm. The rings are
  uniform (32 mm step), so the existing scoring model applies unchanged.
- A single `ProgramDefinition` `silhuettpistol12_5m` with one 6×5 *Duell* stage,
  added to `ProgramCatalogue.all`. No `secondsPerSeries` — the father shoots it
  untimed; a turning-target time can be added later if confirmed.

## Rationale

A dedicated face (rather than reusing the 500 mm rapid geometry) makes the
calibre-to-ring ratio correct, so the auto-detect's expected hole size matches the
real torn holes on the A4 print — better seeded markers — while scoring stays
identical to the rapid face it is derived from. 6×5 follows the duel-series
convention of the 25 m programs.

## Verification

- **Unit (`pistol_target_geometry_test`):** the face's numbers (rings 5–10,
  ⌀ 200 outer / ⌀ 40 inner, inner ten ⌀ 20, calibre 4.5, uniform 32 mm step,
  max scoring radius 102.25 mm); an integer-score table across every ring with
  the miss boundary just past the 5-ring; inner-ten either side of the 20 mm ring.
- **Unit (`program_catalogue_test`):** Silhuettpistol is 30 shots in 6×5, pistol,
  air calibre, on the ⌀ 200 face (rings 5–10), in `all`, resolvable by name;
  catalogue size is 14.
- **Gates:** format, `analyze --fatal-infos`, full test, reuse, `mkdocs
  --strict`.

## Known limitations / to confirm with the father

The ring diameters were **measured off a phone photo** (rapid proportions at the
measured ⌀ 200 mm), and the course of fire (duel 6×5 = 30, untimed) is the
father's practice format, not a published NSF program. Confirm the exact ring
table and whether the duel series carries a per-series time limit. The dense
overlapping central cluster on this face is where the auto-detect heuristic
under-counts (spec 0040) — a known limit until the contributed-image model lands.
