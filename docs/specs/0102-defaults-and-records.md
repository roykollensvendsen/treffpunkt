# Spec 0102 — Default place and personal-record baselines

- **Status:** Accepted
- **Related:** specs 0101 («Ny pers!»), 0092 (felt setup), 0008 (session
  metadata), 0072 (settings), 0030/0099 (local preference stores)

## Context

Two things reset to zero when someone starts using the app. The place
field of the setup step starts empty every time, though most shooters
train at the same range week after week. And the «Ny pers!» celebration
(spec 0101) only knows the sessions recorded in the app — a shooter with
years behind them gets a hollow "personal best" for a result far below
what they have actually shot.

## Rationale

Both are *starting values* the shooter should be able to set once. The
default place is a plain preference: pre-fill, never lock — typing and
«Bruk min posisjon» behave exactly as before. The record baseline slots
into the spec-0101 rule with no new comparison logic: a manual baseline
is simply one more *prior result* for its exercise, so the banner fires
only when the shooter beats the best of baseline **and** recorded
sessions. That also answers "updates when you beat it" without mutating
anything: the *effective* record shown anywhere is computed as the best
of the baseline and the session history, so a session that beats the
baseline becomes the new record the moment it is saved — and if that
session is later deleted, the record honestly falls back. Both values
are device-local (`shared_preferences`), like the theme and the felt
group; syncing them to the account can come later.

## Requirements

1. **Default place** (Innstillinger → Skyting → «Standard sted»): an
   editable text preference, persisted locally; clearing it removes it.
   The session-setup form (ring *and* felt, spec 0092) starts with the
   place field pre-filled from it when set. Typing over it, or leaving
   it, works as before; «Bruk min posisjon» still only fills an *empty*
   field, so the default is never silently overwritten.
2. **Personal-record baselines**: per exercise — every catalogue program,
   and the felt course per group — the shooter can set a manual baseline
   record (`points` + `innertreff`), edit it and remove it. Persisted
   locally as one map.
3. **«Rekorder» screen**: reachable from Innstillinger (Skyting section)
   and from the Statistikk app bar. Lists every exercise with its
   **effective record** — the lexicographic best (spec 0101) of the
   baseline and all recorded sessions of that exercise (ring per
   program; felt per group, local + synced merged) — or «Ingen rekord
   ennå». Editing a row edits the *baseline* only.
4. **The banner beats the baseline too** (spec 0101 amendment): the
   prior results the «Ny pers!» comparison runs against now include the
   exercise's baseline when one is set. In particular the *first*
   recorded session of an exercise celebrates iff it beats the baseline.
5. **Domain rule** (pure Dart): `bestResult(results)` returns the
   lexicographically greatest (points, inner) result, or null for an
   empty list.

## Verification

Unit:

- `personal_best_test`: `bestResult` of an empty list is null; picks the
  most points; breaks point ties on inner.
- `default_place_store_test` / `personal_records_store_test`: in-memory
  and `shared_preferences` round-trips; absent → null/empty; clearing
  removes; unknown JSON shapes load as empty.

Widget:

- `session_setup_screen_test`: with a default place set, the place field
  starts pre-filled and the built metadata carries it; without one it
  starts empty.
- `settings_screen_test`: the Skyting section shows the saved place,
  edits persist through the store, and «Personlige rekorder» opens the
  records screen.
- `personal_records_screen_test`: lists catalogue programs and both felt
  groups; a saved baseline shows as the record; a *better session* wins
  over the baseline (the computed "updates when beaten"); editing saves
  and removing clears the baseline.
- `series_screen_test`: with a baseline above the session result no
  banner shows even with no session history; with a baseline below, the
  first-ever session celebrates.
- `felt_record_screen_test`: a same-group baseline above the round hides
  the banner; the other group's baseline is ignored.
