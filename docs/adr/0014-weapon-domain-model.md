# ADR-0014: The weapon domain model

- **Status:** Accepted
- **Date:** 2026-06-22

## Context
ADR-0012 decided that a recorded session names the weapon it was shot with, and
that the weapon's class/calibre must be one the chosen program permits — this is
what mechanically keeps *grovpistol* and *finpistol* leaderboards apart. It also
sketched the shape: a **seeded reference catalogue** of weapon classes plus the
shooter's **personal weapons** referencing it (the same definitions-vs-recordings
split as programs). Spec 0007 builds that. Two questions need pinning down: how a
weapon is tied to the programs it may be used for, and what a "personal weapon"
is as a value.

The programs already declare their permitted classes as a `List<String>` of
labels (`'.22 LR'`, `'Air 4.5 mm'`, `'Centre-fire 7.62–9.65 mm'`) in
`ProgramDefinition.weaponClasses`. So the link already exists — as a string.

## Decision
Model weapons as two small **pure-Dart** value types, mirroring the program side:

- **`WeaponClass`** — a seeded reference class: a discipline, a calibre label and
  a **`label`** string. The label is exactly the string the programs already use
  in `weaponClasses`. `WeaponCatalogue` is an `abstract final class` holding the
  seeded classes as a `const` list and an `all` list — structurally identical to
  `ProgramCatalogue`.
- **`Weapon`** — a personal weapon: a stable **id**, a shooter-given **name**,
  the class's discipline / calibre / **`classLabel`**, and optional make / model
  / notes. Immutable, with value equality. `Weapon.fromClass` builds one from a
  `WeaponClass` plus a name and id.

The **permitted-for** rule lives on the weapon as a single method:
`program.weaponClasses.isEmpty || program.weaponClasses.contains(classLabel)`.

The match is by **label string**, not by an object reference or an enum. The
class carries discipline and calibre for display and future filtering, but the
authoritative key shared with programs is the label.

The shooter's weapons live in a Riverpod `Notifier<List<Weapon>>` (in-memory for
now) with add/remove, and a separate `selectedWeaponProvider` holds the `Weapon?`
chosen for the current session. Persistence is a later increment.

## Consequences
- A weapon and a program agree through one string, so adding a program that
  references an existing class needs no weapon-side change, and the picker can
  filter with the exact rule the model enforces — the UI cannot offer a weapon
  the domain would reject.
- Personal weapons are identified by a per-weapon id, so a shooter can own
  several guns of one class, each with its own name — class is not identity.
- Because the link is a bare string, a typo in a program's `weaponClasses` or a
  catalogue label silently breaks the match; spec 0007's catalogue test guards
  this by asserting the two catalogues agree (every program label is covered and
  every seeded class label is used).
- The exact NSF class names/calibres still need the father (spec 0007 carries the
  checkbox); the seeded labels mirror what `ProgramCatalogue` already uses, so
  the model is correct even if a label is later renamed (rename in both lists).
- `Session` gains one optional field; every existing session and test stays
  valid.

## Alternatives considered
- **Match by an enum or a shared `WeaponClass` object reference instead of a
  label string:** rejected — the programs already key off label strings, so an
  enum would mean a second source of truth to keep in sync, and a const object
  reference can't be shared cleanly across the two const catalogues. A single
  label string with a catalogue-agreement test is simpler.
- **Fold the class into the weapon (no separate catalogue):** rejected — the
  shooter picks from a curated, seeded list of standard classes; a free-form
  calibre per weapon would let invalid classes in and break the program match.
- **Make `Session.weapon` required:** rejected — it would invalidate every
  existing session and test, and the session-setup wiring (where a weapon is
  actually chosen) is a later spec; ADR-0012 reserved an optional slot.
