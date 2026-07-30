<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0165 — Tørravtrekk per våpen (velg våpentype)

- **Status:** Draft
- **Related:** spec 0161 (the dry-fire log), spec 0162 (its sync + the
  `dry_fire_entries` table), spec 0163 (dry-fire in «Mine økter»),
  spec 0007 / ADR-0014 (the weapon domain model + catalogue), ADR-0017
  (client-generated ids, manual migrations)

## Summary

Today a dry-fire bout records only the target discipline (**Presisjon** or
**Duell**) — not which pistol it was practised with. A shooter dry-fires their
air pistol, their finpistol and their grovpistol, and wants to follow each
separately. This adds a **weapon type** to every dry-fire registration:
**Luftpistol**, **Finpistol** (.22) or **Grovpistol**, picked in the register
sheet alongside the discipline, shown in «Mine økter», and synced. The
per-weapon *statistics* are the following increment (spec 0166); this increment
records and carries the weapon everywhere an entry appears.

Requested by a shooter (Roy's father): «tørravtrekk for luftpistol også, og
mulighet for valg av våpen».

## Requirements

1. The register sheet lets the shooter choose a **weapon type** — Luftpistol,
   Finpistol or Grovpistol — for the bout, in addition to the discipline.
2. An accepted registration stores the chosen weapon type on the entry, next to
   the existing discipline and count.
3. The weapon type is one of a small, fixed set aligned to the catalogue's
   pistol classes (spec 0007): Luftpistol → air 4.5 mm, Finpistol → .22 LR,
   Grovpistol → centre-fire.
4. **Both** disciplines (Presisjon and Duell) remain available for **every**
   weapon type — air pistol has a national duel form too (Sprintluft / Storluft
   on the luftduell face; see the program catalogue), so nothing is hidden.
5. A dry-fire entry recorded **before** this feature (no weapon) stays valid: it
   loads, syncs and displays as an entry *without* a weapon, and still counts in
   the totals. No backfill, no guess.
6. The weapon survives an app restart (offline persistence) and, when signed in,
   is backed up to and merged from the account (spec 0162).
7. «Mine økter» shows the weapon type on a dry-fire row (omitted for a legacy
   entry with none).
8. A single unreadable weapon value never breaks the log: it degrades to *no
   weapon*, it does not throw.

## Rationale

- **A weapon *type*, not a named gun.** The app already owns a per-gun model
  (`Weapon` → `WeaponClass`, ADR-0014) with a `WeaponPicker`, used when recording
  a *scored* session. Dry-fire deliberately uses a **small fixed enum of the
  three pistol types** instead. It matches the request's own words («luftpistol»
  is a type), needs no registered guns to work, keeps the volume statistics
  stable when a shooter changes guns, and keeps the entry a pure, self-contained
  value type (as the discipline already is) rather than embedding a whole
  `Weapon`. The type is a standalone enum — not a reference to `WeaponCatalogue`
  — so the pure scoring domain gains no dependency on the weapons feature and no
  import cycle; a unit test guards that the three types stay in step with the
  catalogue's pistol classes (see Verification), which is the drift risk a
  duplicated set carries.
- **Both disciplines for every weapon.** The first design draft would have hidden
  Duell for Luftpistol on the belief that 10 m air pistol is precision-only. It
  is not: the catalogue itself models the national air-*duel* programs
  (`Sprintluft`, `Storluft`). Keeping both segments for all weapons is both
  correct and simpler — no control appears or disappears as the weapon changes,
  and no illegal (weapon, discipline) pair has to be prevented.
- **Nullable weapon, honest about the past.** The weapon is an *optional* field.
  Existing entries genuinely have no recorded weapon, so `null` (not a guessed
  backfill) is the truthful value; making it optional also keeps every existing
  `DryFireEntry(...)` call site compiling. The `dry_fire_entries` table gains a
  **nullable** `weapon` column, so pre-feature rows read back as `null`.
- **Degrade, don't throw, on an unknown weapon.** `DryFireDiscipline.fromWireName`
  throws on an unknown name because a discipline has no safe fallback. A weapon
  does: `null`. And it *must* degrade, because the list store is all-or-nothing —
  one throwing `fromJson` empties the entire persisted log (`PrefsJsonListStore`).
  So an unknown or non-string weapon value resolves to *no weapon* rather than
  discarding every bout the shooter ever logged.
- **Remember the last weapon, for free.** The sheet defaults its weapon to the
  most recent entry's weapon (falling back to Luftpistol), so a shooter who only
  dry-fires one pistol never re-picks it — mirroring how the app remembers the
  last place (spec 0102) — without adding a new store, since the log already
  persists.

## Design

### Domain (`lib/features/scoring/domain/`)

- `dry_fire_weapon.dart` — `enum DryFireWeapon { luftpistol, finpistol,
  grovpistol }`, each carrying a Norwegian `label` and a stable `wireName`
  (`'luftpistol'`, `'finpistol'`, `'grovpistol'`). `static DryFireWeapon?
  fromWireName(String? name)` returns `null` for a `null` **or unknown** name
  (the degrade-not-throw rule) — deliberately unlike `DryFireDiscipline`.
- `dry_fire_entry.dart` — add `final DryFireWeapon? weapon;`, an *optional* named
  parameter (defaults to `null`). `toJson` writes `'weapon': weapon?.wireName`
  (so a legacy entry writes `null`). `fromJson` reads it defensively:
  `switch (json['weapon']) { final String w => DryFireWeapon.fromWireName(w), _ =>
  null }` — a missing key, a JSON `null`, a non-string, or an unknown name all
  yield `null`, never a throw. `weapon` joins `==` / `hashCode`.

### Data (`lib/features/scoring/`)

- `data/dry_fire_store.dart` — unchanged; the whole entry round-trips through its
  `toJson` / `fromJson`.
- New migration `supabase/migrations/<ts>_dry_fire_entries_weapon.sql`:
  `alter table public.dry_fire_entries add column if not exists weapon text;`
  — **nullable**, no default, no RLS/grant change (the new column inherits the
  table's owner-only policies). Manual-apply per ADR-0017.
- `data/supabase_dry_fire_repository.dart` — the upsert row carries `'weapon':
  entry.weapon?.wireName`; the read maps `row['weapon']` with the same
  degrade-to-null switch as `fromJson`. The row↔entry mapping is extracted to
  `@visibleForTesting` static helpers so the null/legacy handling and the column
  contract are unit-testable without a live client.

### Presentation (`lib/features/scoring/presentation/`)

- `dry_fire_providers.dart` — `register(DryFireWeapon weapon, DryFireDiscipline
  discipline, int triggerPulls)`; the new entry carries the weapon.
- `dry_fire_card.dart` — the sheet gains a **Våpentype** row of `ChoiceChip`s
  (Luftpistol / Finpistol / Grovpistol) above the unchanged discipline
  `SegmentedButton`; `ChoiceChip`s wrap, so three Norwegian labels never overflow
  a narrow sheet. The weapon defaults to the most recent entry's weapon, else
  Luftpistol. The card **subtitle** becomes the glanceable grand total
  (`'{N} avtrekk'`, or the invite when empty) — the per-weapon breakdown lives on
  Statistikk (spec 0166), not on this compact tile.
- `my_sessions_screen.dart` — a dry-fire row's caption becomes
  `<date> · <weapon> · <discipline>`, with the weapon segment omitted when the
  entry has none; the semantics label matches.

## Verification

### Unit tests

- `dry_fire_weapon_test`: each value's `label` and `wireName` are the expected
  stable strings (a rename of a `wireName` is a storage break, so it is pinned);
  `fromWireName` maps all three round-trip, returns `null` for an unknown name
  and for `null`. A **drift guard**: an explicit map
  `{luftpistol: airPistol, finpistol: smallborePistol, grovpistol:
  centreFirePistol}` covers every `DryFireWeapon`, and its value set equals
  `WeaponCatalogue.all.where((c) => c.discipline == Discipline.pistol).toSet()`
  (keyed on the `WeaponClass` objects, not labels) — so adding/removing/renaming
  a pistol class without updating the dry-fire types fails here.
- `dry_fire_entry_test` (extend): an entry *with* a weapon round-trips losslessly
  and `toJson` writes the `wireName`; a legacy map with **no** `weapon` key
  parses with `weapon == null` and equals the same entry built without a weapon;
  a JSON `null`, a non-string, and an **unknown** `weapon` value each parse to
  `weapon == null` (never throw); two entries differing only in `weapon` are
  unequal (and `hashCode` differs), and a null-weapon vs a weapon entry are
  unequal.
- `dry_fire_store_test` (extend): a hand-written **old-format** blob (entries
  lacking the `weapon` key, via `setMockInitialValues`) loads with every
  `weapon == null` and loses nothing; an entry with a weapon persists and loads
  back equal.
- `dry_fire_repository_test` (extend): the extracted row-mapper turns a row with
  a known `weapon` into that weapon, a row with `weapon: null` **and** a row with
  no `weapon` key both into `null`, and an unknown value into `null`; the
  upsert-row builder emits key `weapon` = the `wireName` for a weapon entry and
  `null` for a legacy entry; the in-memory repository round-trips the weapon.
- `dry_fire_log_test` / `dry_fire_log_sync_test` (update): `register(weapon,
  discipline, pulls)` stores the weapon; the sync path carries it.

### Widget tests

- `dry_fire_card_test`: the sheet renders the Våpentype chips and the discipline
  segments (both present for every weapon); registering with a chosen weapon +
  discipline saves an entry carrying both; the card subtitle shows the grand
  total after a registration; the empty state still invites.
- `dry_fire_in_sessions_test`: a dry-fire row shows the weapon in its caption;
  a legacy entry (no weapon) omits it.

### System / manual

- **Migration + RLS (spec 0162 precedent):** apply
  `<ts>_dry_fire_entries_weapon.sql` to a local Supabase, upsert and list an
  entry carrying a weapon through `SupabaseDryFireRepository`, and confirm the
  existing owner-only RLS still confines it — the Supabase column round-trip is
  covered by the real-app backend harness, not a unit test.
- **Rollout order:** the migration must be applied to the hosted project
  **before** the weapon-aware client is deployed; otherwise `upload()` is
  rejected (missing column) and silently backs up nothing until it is applied
  (best-effort, so no crash and no data loss — local logging is unaffected and a
  later sync backfills). Called out in the PR body.
- Rendered on Hjem (register sheet) and «Mine økter», light and dark, signed off
  before merge.

## Open questions

- **Free pistol (fripistol).** A .22 free pistol (single-shot, set trigger) is a
  physically distinct gun whose dry-fire is a distinct skill, yet it folds into
  «Finpistol» here (it shares the .22 class). Out of scope for v1 by the
  per-type decision; a fourth type can be added later if the shooter wants to
  separate it. Recorded so a reviewer does not mistake the fold for an oversight.
- **Append-only constraint.** There is no path to *edit* an entry's weapon, so no
  two devices ever disagree on one id's weapon and the sync's remote-wins merge
  is safe. Before any future re-tag/backfill, the upsert must omit a `null`
  weapon (or the merge must prefer the non-null side) to avoid clobbering a tag.
