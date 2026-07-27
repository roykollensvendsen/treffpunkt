<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
SPDX-License-Identifier: GPL-3.0-or-later
-->
# 0161 — Tørrtrening (tørravtrekk-logg)

- **Status:** Draft
- **Related:** spec 0009 (offline persistence / stores), spec 0025 (upload
  queue — precedent for the deferred sync increment), ADR-0016 (one JSON blob
  per prefs key)

## Summary

A shooter dry-fires — pulls the trigger on an unloaded weapon to train grip,
sight picture and trigger control — far more often than they shoot for score,
and today Treffpunkt records none of it. This adds a **Tørrtrening** card to
Hjem (the front page) where the shooter picks the target discipline
(**Presisjon** or **Duell**) and enters how many trigger pulls (avtrekk) they
took. Each registration is saved and the running totals persist across restarts,
so the volume of dry-fire practice is tracked over time.

Requested on the forum by a shooter (Roy's father): «kan vi på første siden få
inn en rubrikk for tørravtrekk … et valg for presisjon skive og et for duell
skive med rubrikk hvor vi kan skrive inn antall avtrekk vi tar».

## Requirements

1. Hjem shows a **Tørrtrening** card (front page, `ProgramPickerScreen`).
2. Registering asks for the discipline — **Presisjon** or **Duell** — and a
   whole number of trigger pulls greater than zero.
3. A registration is rejected (no entry saved) when the count is empty, zero,
   negative or non-numeric.
4. Each accepted registration is stored as one entry: a stable id, the moment it
   was recorded, the discipline, and the count.
5. The stored log survives an app restart (offline persistence, spec 0009).
6. The card shows the cumulative trigger-pull totals per discipline; with no
   entries yet it invites the first registration instead.

## Rationale

- **A logged entry, not a live counter.** Pappa's words — «skrive inn antall
  avtrekk vi tar» — describe entering a count for a completed bout, not tapping a
  live tally. Storing discrete entries (discipline + count + time) is what lets
  the practice be *followed over time*, which is the whole point of the app, and
  is the natural shape for the deferred sync/statistics increment.
- **Discipline as a label, not a drawn target (v1).** The choice is recorded as
  a type; the physical target face is *not* rendered. Showing the presisjon/duell
  face for aiming during dry-fire is a real enhancement but a much larger one
  (target painters, layout), and dry-fire has no shot to place — so v1 keeps the
  choice a plain label, decided with the requester.
- **Mirror the session stores exactly.** The feature reuses the established
  store shape (abstract interface + in-memory fake + `PrefsJsonListStore`-backed
  implementation, spec 0009 / spec 0025), so it is unit-testable with no real
  I/O and needs no new persistence machinery.
- **Pure domain.** The entry is a pure Dart value type; its id and timestamp are
  supplied by the presentation layer (as ids are for `SessionRecord`, ADR-0017),
  keeping the domain deterministic and Flutter-free.

## Design

### Domain (`lib/features/scoring/domain/`)

- `DryFireDiscipline` — an enum, `presisjon` and `duell`, each with a Norwegian
  `label` for display and a stable `wireName` for storage.
- `DryFireEntry` — `@immutable` value type: `id` (String), `recordedAt`
  (DateTime), `discipline` (DryFireDiscipline), `triggerPulls` (int). Round-trips
  through `toJson`/`fromJson`; `recordedAt` is stored as an ISO-8601 wire string
  (`core/time/wire_time.dart`), the discipline as its `wireName`. `fromJson`
  throws on a missing/invalid field or an unknown `wireName` (as
  `SessionRecord.fromJson` does via its casts); the store below turns any such
  unreadable list into an empty log, so a corrupt key never crashes the app.
- `DryFireTotals` — a small pure helper that folds a `List<DryFireEntry>` into
  the per-discipline and grand totals the card shows.

### Data (`lib/features/scoring/data/`)

- `DryFireStore` — `abstract interface` with `load()` → `List<DryFireEntry>` and
  `save(List<DryFireEntry>)`, exactly like `PendingUploadsStore`.
- `InMemoryDryFireStore` — the default binding and test fake.
- `SharedPreferencesDryFireStore` — delegates to
  `PrefsJsonListStore<DryFireEntry>` under key `dry_fire_log`.

### Presentation (`lib/features/scoring/presentation/`)

- `dryFireStoreProvider` — `Provider<DryFireStore>` defaulting to the in-memory
  store; `main()` overrides it with the prefs-backed store through
  `bootstrap.dart`, mirroring `sessionStoreProvider`.
- `DryFireLog` — an `AsyncNotifier<List<DryFireEntry>>` that loads the persisted
  list on build and exposes `register(discipline, triggerPulls)`, which appends
  a new entry (id from `sessionIdGeneratorProvider`, `recordedAt` = now),
  persists the list and updates state. Persistence is best-effort (a write
  failure never breaks the in-memory state), matching the upload queue.
- Card + entry sheet on Hjem: a `Tørrtrening` `Card` placed after the category
  grid and before the «Spander en kaffe» card. Its subtitle shows the totals
  (`Presisjon N · Duell M`) or, when empty, `Registrer tørravtrekk`. Tapping
  opens a bottom sheet with a Presisjon/Duell segmented choice, a numeric
  «Antall avtrekk» field and a «Registrer» button; a valid registration saves,
  closes the sheet and confirms via a SnackBar. Colours come from the theme
  (spec 0100); the leading icon is a neutral training glyph, not a target face.

### Deferred to a following increment (not in this PR)

- **Cross-device sync.** Uploading the log to Supabase so it follows the shooter
  across devices — a new table + RLS + a repository joined to the durable upload
  queue (spec 0025 is the precedent). Kept separate because it needs backend
  changes and live verification.
- **Statistics surface.** Dry-fire volume over time on the Statistikk screen
  (per week/discipline). The stored entries already carry everything this needs.

## Verification

### Unit tests

- `dry_fire_entry_test`: `toJson`/`fromJson` round-trips losslessly; an unknown
  discipline `wireName` and a malformed map each throw from `fromJson`.
- `dry_fire_totals_test`: folds a mixed list into correct per-discipline and
  grand totals; an empty list yields zeros.
- `dry_fire_store_test`: the in-memory and prefs-backed stores both save and
  load a list; the prefs store returns an empty list for a never-saved / corrupt
  key; entries persist across a fresh store over the same `SharedPreferences`
  (restart simulation).
- `dry_fire_log_test`: `register` appends an entry with the given discipline and
  count, persists it, and rejects a non-positive count; state exposes the
  entries newest-relevant totals.

### Widget tests

- `program_picker_screen_test`: the Tørrtrening card renders; empty state shows
  the invite copy; after a registration through the sheet the subtitle shows the
  updated totals; a zero/empty count leaves the log unchanged and shows a
  validation message.

### System / visual

- Rendered on Hjem, light and dark, signed off before merge.

## Open questions

- None blocking v1. The two decided with the requester — logged (not a live
  counter) and discipline-as-label (no drawn target) — are recorded under
  Rationale.
