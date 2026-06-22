# Spec 0007 — Weapon catalogue, personal weapons and picker

- **Status:** Accepted
- **Related:** ADR-0012 (session model), ADR-0014 (weapon domain model),
  ADR-0003 (Riverpod), spec 0004 (program & series), spec 0006 (series screen)

## Context

A recorded session must say which weapon it was shot with: a leaderboard for
*grovpistol* must not mix in *finpistol* scores, and a shooter wants their own
named guns to pick from, not a calibre typed out each time. ADR-0012 already
decided the shape — a **seeded reference catalogue** of weapon classes plus the
shooter's **personal weapons** that reference a class — and that a weapon may
only be chosen for a program whose permitted classes include the weapon's class.
This spec builds that model, an in-memory store for the shooter's weapons, and a
reusable picker widget; persistence and the wiring into the session-setup flow
land in later increments (0008/0009).

## Requirements

1. A seeded **catalogue of weapon classes** — the standard NSF/ISSF classes
   (discipline + calibre) — whose labels are exactly the strings already used in
   `ProgramDefinition.weaponClasses`, so a weapon can be matched to the programs
   it is permitted for. It covers every class referenced by the seeded programs.
2. A **personal weapon** value type: a shooter-given name plus the chosen class's
   discipline / calibre / label, optional make / model / notes, and a stable id.
   It is pure Dart, immutable, with value equality.
3. A weapon is **permitted for** a program when the program has no class
   restriction (`weaponClasses.isEmpty`) or its `weaponClasses` contain the
   weapon's class label.
4. A **personal-weapons store** (Riverpod `Notifier<List<Weapon>>`) with add and
   remove, plus a `selectedWeaponProvider` holding the `Weapon?` chosen for the
   current session. In-memory for now.
5. A reusable **`WeaponPicker`** widget: given a program (or its weapon classes)
   it lists the shooter's permitted weapons, lets them add a new weapon from a
   catalogue class, and reports the selection (a callback and `selectedWeapon`).
6. The `Session` aggregate carries an **optional** `weapon`, set at
   `Session.start` and preserved across `sealSeries`. No other session behaviour
   changes.
7. Pure-Dart domain (no Flutter imports); passes `very_good_analysis`; testable
   headlessly.

## Rationale

Mirroring `ProgramCatalogue` — an `abstract final class WeaponCatalogue` with a
const list — keeps the two seeded catalogues structurally identical and lets a
weapon class be matched to a program by a shared **label string** rather than a
brittle cross-reference. The label is the single source of truth for the match
(`program.weaponClasses.contains(weapon.classLabel)`); calibre and discipline
ride along for display and future filtering. Personal weapons are a separate
value type because a shooter owns several guns of one class (two .22 pistols),
each with its own name — so identity is a per-weapon id, not the class. The store
is a plain `Notifier<List<Weapon>>`: persistence is a later increment, and an
in-memory list keeps this spec to the model + picker. The picker takes a program
and filters with the same `isPermittedFor` rule the domain exposes, so the UI
cannot offer a weapon the model would reject. Extending `Session` with one
optional field (rather than a required one) keeps every existing session valid
and every existing test green; ADR-0012 already reserved the slot.

## Design

```
lib/features/weapons/
  domain/
    weapon_class.dart      WeaponClass (discipline, caliberLabel, label) +
                           value equality
    weapon_catalogue.dart  abstract final class WeaponCatalogue: const classes
                           (air rifle/pistol 4.5 mm, .22 LR pistol/rifle,
                           centre-fire pistol) + `all`
    weapon.dart            Weapon (id, name, classLabel, discipline,
                           caliberLabel, make?, model?, notes?) value type;
                           Weapon.fromClass(...); isPermittedFor(program)
  data/
    weapons_store.dart     WeaponsNotifier (Notifier<List<Weapon>>: add/remove),
                           weaponsProvider, selectedWeaponProvider (Weapon?)
  presentation/
    weapon_picker.dart     WeaponPicker: lists permitted weapons for a program,
                           add-from-class dialog, reports the selection
```

`WeaponClass` and `Weapon` are pure value types. `Weapon.isPermittedFor` is the
one rule (requirement 3). The store and `selectedWeaponProvider` are thin
Riverpod wrappers; `WeaponPicker` watches the store, filters by `isPermittedFor`,
and writes `selectedWeaponProvider` (and calls an optional `onSelected`).

`Session` gains `final Weapon? weapon;` — added to `Session._`, to
`Session.start(...)` as a named optional `{Weapon? weapon}`, and carried through
`sealSeries` (`weapon: weapon`).

## Verification

### Unit tests

- `weapon_catalogue_test`: every seeded class label appears in some seeded
  program's `weaponClasses`, and every non-empty `weaponClasses` string used by
  `ProgramCatalogue` is covered by a catalogue class (the two catalogues agree);
  `all` is non-empty and its labels are unique.
- `weapon_test`: `Weapon.fromClass` copies the class's discipline / calibre /
  label and keeps the given name and id, and carries `make` / `model` / `notes`
  through; two weapons with the same fields are equal (and unequal when a field
  differs, including when only `make` or only `notes` differs, since they
  participate in equality / `hashCode`); `isPermittedFor` is true for a program
  listing the class, true for an unrestricted program (`weaponClasses.isEmpty`),
  and false for a program listing only other classes.
- `weapons_store_test`: the store starts empty; `add` appends; `remove` drops by
  id; `selectedWeaponProvider` defaults to `null`, holds an assigned weapon, and
  `clear()` resets it back to `null`.
- `session_weapon_test`: `Session.start(program, weapon: w)` exposes `w`;
  `sealSeries` preserves it; `Session.start(program)` leaves `weapon` `null`.

### Widget tests

- `weapon_picker_test`: given two stored weapons of which one is permitted for
  the program, the picker lists only the permitted one; tapping it reports the
  selection (callback fires and `selectedWeaponProvider` updates); the add
  control opens the add flow and a weapon added from a permitted class shows up
  and is selectable; the add-class list is filtered by **discipline as well as
  label**, so an air-rifle program offers the air-rifle class but not the
  air-pistol class that shares the `'Air 4.5 mm'` label; and saving the add
  dialog with an empty name is a no-op (the dialog stays open and no weapon is
  added).

### System tests

- None in this spec; wiring the picker into the session-setup flow (and a
  system test for it) lands with spec 0008.

## Open questions

- The exact NSF class names / calibres and any missing classes (e.g. junior /
  veteran reductions) need confirming with the father — see the checkbox below;
  the seeded labels mirror those `ProgramCatalogue` already uses.
- Persistence of personal weapons and the per-session selection wiring are spec
  0008 / 0009.

## Still to confirm with the father / a live NSF rulebook

- [ ] The authoritative NSF weapon-class **names and calibres** (the seeded
      labels mirror the strings `ProgramCatalogue` already uses; the NSF list is
      not web-accessible). Confirm: `Air 4.5 mm`, `.22 LR`,
      `Centre-fire 7.62–9.65 mm`, and whether rifle classes need their own
      calibre labels distinct from the pistol ones.
- [ ] Any classes the catalogue is still missing (e.g. 50 m / 300 m rifle
      calibres, women / junior / veteran class reductions).
