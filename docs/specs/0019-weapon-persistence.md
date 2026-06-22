# Spec 0019 — Personal weapon persistence

- **Status:** Accepted
- **Related:** ADR-0014 (weapon domain model), ADR-0016 (local store via
  `shared_preferences`), ADR-0003 (Riverpod), spec 0007 (weapon catalogue &
  picker), spec 0009 (offline session persistence — the pattern this mirrors)

## Context

The shooter builds up a small list of their own named guns and picks one per
session (spec 0007). Today that list lives only in memory in `WeaponsNotifier`,
so it vanishes the moment the app is closed — every relaunch starts with an
empty weapon list and the shooter has to re-add each gun. A whole session
already survives a restart (spec 0009); the weapons it is shot with must too.

This spec persists the personal weapons on-device, with no network, surviving a
real restart — reusing the exact pattern spec 0009 set for sessions: a store
behind a small interface (an in-memory fake for tests, a `shared_preferences`
implementation for the app), a pure-Dart JSON (de)serialization, and wiring
through `runTreffpunkt`. Nothing here touches the network, and no test does real
I/O.

## Requirements

1. A **pure-Dart, lossless** JSON (de)serialization of `List<Weapon>`: every
   field round-trips, the `Discipline` enum is stored by name, and the optional
   `make` / `model` / `notes` are `null` when absent. The round-trip rebuilds an
   equal list field-by-field, including weapons with and without the optional
   fields, and the empty list.
2. A **`WeaponStore`** interface in the weapons data layer — `save(List<Weapon>)`
   and `load()` — that the rest of the app depends on, mirroring `SessionStore`.
   `InMemoryWeaponStore` is the default binding and the test fake;
   `SharedPreferencesWeaponStore` persists the whole list as one JSON string
   under one key (ADR-0016). `load` returns an empty list when nothing was ever
   saved.
3. `WeaponsNotifier` **persists on every change**: each `add` and `remove`
   writes the whole list back through the store. Saving is best-effort and off
   the happy path (the in-memory list is the source of truth for the run); a
   failure is surfaced only in debug builds, never thrown into the UI.
4. **Loading at launch seeds the notifier synchronously.** The saved list is
   read once in `main()` (where `shared_preferences` is already awaited) and
   passed to `runTreffpunkt`, which seeds the notifier's initial state through an
   `initialWeaponsProvider` override. There is no async work in `build`, so the
   notifier stays synchronous and tests never touch real I/O. Omitting the store
   and the initial list keeps the in-memory default, so tests and the
   integration harness never reach real storage.
5. New code is pure Dart in the serialization (no Flutter imports) and passes
   `very_good_analysis` (strict); existing tests stay green.

## Rationale

The unit to persist is a flat list of immutable value types, so serialization
lives in a tiny pure-Dart helper, `WeaponsSnapshot`, with no Flutter or storage
import — exactly as `SessionSnapshot` does for a session. The JSON shape is a
plain array of weapon objects, identical to the single-weapon object already
embedded in a stored session, so the two stay consistent and the round-trip is a
fast, deterministic unit test.

Storage sits behind `WeaponStore`, mirroring `SessionStore`, so the feature is
testable with an in-memory fake and the real engine is swappable.
`shared_preferences` is the cross-platform key-value store already in the app
(ADR-0016); one JSON string under one key holds the whole list.

Loading follows the clean approach `shared_preferences` already invites: the
list is read once in `main()` — where prefs is awaited anyway — and handed to
`runTreffpunkt`, which seeds the notifier through a provider override. This keeps
`build` synchronous (no async-in-`build`, no loading spinner for a handful of
weapons) and means tests seed the same way, never touching real storage. Writing
on every `add` / `remove` keeps the saved list in step with the in-memory one
without the notifier ever having to load.

## Design

```
lib/features/weapons/
  data/
    weapons_snapshot.dart  WeaponsSnapshot.toJson / fromJson — pure-Dart, lossless
                           list (de)serialization (Discipline by name; optional
                           make/model/notes -> null).
    weapon_store.dart      WeaponStore interface (save / load);
                           InMemoryWeaponStore (default + test fake);
                           SharedPreferencesWeaponStore (one JSON string, one key).
    weapons_store.dart     + weaponStoreProvider (defaults to in-memory);
                           initialWeaponsProvider (seeds build, overridden at
                           launch); WeaponsNotifier seeds from it and persists on
                           every add/remove.
lib/
  bootstrap.dart           runTreffpunkt(..., {WeaponStore? weaponStore,
                           List<Weapon>? initialWeapons}) — overrides the two
                           providers when given; omitting them keeps the
                           in-memory default.
  main.dart                builds SharedPreferencesWeaponStore(prefs), loads the
                           saved list, passes both to runTreffpunkt.
```

JSON shape (the personal weapons):

```json
[
  { "id": "...", "name": "My Walther", "discipline": "pistol",
    "caliberLabel": ".22 LR", "classLabel": ".22 LR",
    "make": "Walther", "model": "GSP", "notes": null }
]
```

`make`, `model` and `notes` are `null` when absent; the whole document is `[]`
when the shooter has no weapons.

## Verification

### Unit tests

- `weapons_snapshot_test`: a weapon with every optional field set round-trips
  equal; a weapon with no make/model/notes round-trips equal with those fields
  `null`; a mixed list round-trips in order; the empty list round-trips to empty;
  the `Discipline` enum is stored by its name (`'pistol'`, `'rifle'`).
- `weapon_store_test`: the in-memory fake loads empty before any save, saves then
  loads an equal list, a later save overwrites the previous one, and saving an
  empty list clears the weapons; the `shared_preferences`-backed store, driven by
  `SharedPreferences.setMockInitialValues` (no real I/O), loads empty before any
  save, saves and loads an equal list (full and partial weapons), and overwrites
  on a later save.
- `weapons_store_test` (extended): `add` persists the new list to the store;
  adding two weapons persists the whole accumulated list in order (not just the
  latest), pinning that the full list is saved; a fresh notifier seeded from the
  store's loaded list (a simulated relaunch) shows the added weapon; `remove`
  persists the shortened list and a relaunch seeded from the store no longer
  shows the removed weapon; with a store whose `save` always fails, `add` does
  not throw, the in-memory list still reflects the new weapon, and draining the
  event queue surfaces no unhandled async error (the best-effort contract of
  requirement 3). The existing empty-start, add, remove and selected-weapon
  tests stay green.

## Open questions

- Editing a stored weapon in place (rather than remove + add) is a later UI
  affordance; this spec persists the list as add / remove already shape it.
- Syncing the personal weapons to the backend so they follow the shooter across
  devices belongs with the competition / sync increment (specs 0010–0015); this
  spec only stores them locally.
