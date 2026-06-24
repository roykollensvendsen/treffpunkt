<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0036 — Rename "10 m Air Pistol" → "10 m Luftpistol 60 skudd"

- **Status:** Accepted
- **Related:** spec 0035 (40-shot air pistol), spec 0009 (offline persistence /
  `byName` resolution), `docs/reference/program-catalogue.md`

## Context

After spec 0035 added "10 m Luftpistol 40 skudd", the 60-shot program was still
the English "10 m Air Pistol" — out of step with the Norwegian catalogue
(Finpistol, Grovpistol, … , Luftpistol 40 skudd). This renames it to **"10 m
Luftpistol 60 skudd"** for a consistent pair.

The program **name is a stored identity**: `SessionRecord.program` and the
`sessions` / `competition_results` / `competitions` `program` columns hold it, and
`ProgramCatalogue.byName` resolves a saved session back to its definition by it. A
blind rename would orphan every session, competition and result already stored
under "10 m Air Pistol" (real test data from the maintainer, his father and
Isak). So the old name must stay resolvable.

## Requirements

1. **New display name.** The 60-shot program shows as "10 m Luftpistol 60 skudd"
   in the picker, scorecards and "Skyt nå".
2. **Old name still resolves.** A session or competition stored under "10 m Air
   Pistol" still loads and launches — no data migration, nothing orphaned.
3. **No behaviour change** otherwise: same target, scoring, weapon class, shots.

## Design

- Rename `ProgramCatalogue.airPistol10m`'s `name` to "10 m Luftpistol 60 skudd"
  (`lib/features/scoring/domain/program_catalogue.dart`).
- Add a private `_renamedFrom = {'10 m Air Pistol': '10 m Luftpistol 60 skudd'}`
  and make `byName` map an incoming name through it before matching, so the old
  name resolves to the renamed program. This is the same "old data still loads"
  guarantee the air-rifle reference already relies on, generalised to renames.
- The **target geometry** name (`TargetGeometry.airPistol10m()`) is left as
  "10 m Air Pistol": it is the ISSF face label, rebuilt from the program and never
  stored, so it has no backward-compat impact.

## Rationale

Putting the alias in the catalogue's resolver — not a new field on
`ProgramDefinition` — keeps the rename a pure resolution concern and the domain
entity unchanged. No migration is needed precisely because stored names are never
rewritten; they resolve forward through `_renamedFrom`. Fixtures and real rows
keyed on "10 m Air Pistol" keep working, which the competition "Skyt nå" test now
exercises directly.

## Verification

### Unit (`program_catalogue_test.dart`)
- `airPistol10m.name` is "10 m Luftpistol 60 skudd"; it is in `all` and is 60
  shots.
- `byName('10 m Air Pistol')` resolves to the renamed program (the alias path);
  every program resolves by its own current name.

### Widget / integration
- The picker, "Mine økter" cards/scorecards and the "Skyt nå" setup show the new
  name (updated assertions).
- A competition fixed to the old "10 m Air Pistol" still launches "Skyt nå" — the
  setup screen shows the renamed program (backward-compat through the alias).

### Manual
The picker lists "10 m Luftpistol 60 skudd"; an older synced session named "10 m
Air Pistol" still opens its scorecard; an existing competition fixed to it still
launches.

## Known limitations / next increment

`_renamedFrom` is the single place to record future program renames. The English
ISSF geometry label is unchanged; Norwegianising it is a separate, optional
change.
