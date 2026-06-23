# Spec 0026 — My sessions list of saved sessions

- **Status:** Accepted
- **Related:** spec 0024 (personal session sync), spec 0025 (upload queue), spec
  0023 (per-series results), spec 0009 (offline session persistence), ADR-0017
  (personal session sync), ADR-0013 (offline-first recording and deferred sync)

## Context

A shooter who has recorded sessions has, until now, no way to look back at them.
Spec 0024 uploads a completed session to the shooter's account and spec 0025
keeps the not-yet-uploaded ones in a durable on-device queue — but neither is
shown anywhere. The data is collected and safe, yet invisible: the shooter
cannot review last week's results, confirm a session actually synced, or open an
old scorecard.

This spec adds the **read-back** the previous two specs explicitly deferred (see
spec 0025, *Open questions*: "A 'My sessions' history read back from the server,
and surfacing a pending/uploaded indicator in the UI — later increments"). A
signed-in shooter opens a **"Mine økter"** screen and sees every saved session,
most recent first: the ones already synced to the account **and** the ones still
waiting in the upload queue, each marked clearly when it is **not synced yet**.
Tapping one opens its full read-only scorecard — the same per-stage and
per-series (skive) breakdown shown when the session was first completed (spec
0023).

## Requirements

1. **List the synced sessions.** `SessionRepository` gains
   `Future<List<SessionRecord>> list()`. `InMemorySessionRepository.list()`
   returns its uploaded records. `SupabaseSessionRepository.list()` reads
   `sessions` ordered by `captured_at` descending and maps each row back to a
   `SessionRecord` (reusing the column names / `fromJson` shape). It is
   **best-effort exactly like `upload`**: it catches every error and returns
   `const []`, never throwing, so a missing table or a dropped connection cannot
   crash the screen. The Supabase implementation stays the only file importing
   `supabase_flutter` and stays excluded from automated tests (ADR-0017).
2. **Combine synced and pending.** A `mySessionsProvider` (a `FutureProvider`)
   loads the synced records (`sessionRepositoryProvider.list()`) and the pending
   records, and unions them **deduplicated by `id`** — a record present in both
   counts as **synced** (the server copy wins; the pending one is a duplicate
   awaiting removal). The **pending** records are themselves the **union of two
   views of the same outbox**, deduplicated by `id`: the **live upload queue**
   (`uploadQueueProvider`'s in-memory state, spec 0025) **and** the **persisted
   store** (`pendingUploadsStoreProvider.load()`), the single shared, durable
   source the enqueue **always** writes (the live copy wins a tie, keeping the
   freshest in-memory record). Reading the store too is **best-effort** — an
   unreadable store contributes no pending records rather than throwing. Each
   entry is tagged **synced** or **pending**. The list is sorted
   **most-recent-first by `capturedAt`**, with records that have no `capturedAt`
   sorted last. The view-model is a small, pure, testable list of
   `MySessionEntry { record, synced }`.
3. **The "My sessions" screen.** `MySessionsScreen` (a `ConsumerWidget`) shows an
   app bar titled **"Mine økter"** and watches `mySessionsProvider`:
   - **Data**: a list of cards, one per entry, each showing the program name, the
     date/time and place when present, the score `total / maxTotal` (appending
     `· N×X` when `innerTens > 0`), and the weapon name when present. A **pending**
     entry carries a clear **"Ikke synkronisert"** badge; a synced entry does
     not. Rows and badges carry findable `Key`s for tests.
   - **Empty**: a friendly empty state — an icon, the line **"Ingen lagrede
     økter ennå"**, the hint **"Fullfør en økt for å se den her."**, and a
     **"Velg program"** button (a findable `Key`) that returns to the program
     picker (`Navigator.maybePop`, since the screen is pushed from it), so a
     first-time shooter is told what to do next.
   - **Loading / error**: a progress indicator while loading; a graceful message
     on error (the provider itself is best-effort, so an error is unlikely).
   - All visible text is Norwegian and the rows carry `Semantics` labels
     consistent with the rest of the app.
4. **The detail view.** Tapping an entry opens a **read-only scorecard** rebuilt
   from the stored `payload`: `SessionSnapshot.fromJson(record.payload).session`
   → `ScoringService.scoreSession` → the **same** scorecard layout as the live
   completion screen (per-stage rows + per-series/skive rows, spec 0023). The
   shared scorecard is a **public** `SessionScorecard` widget extracted from
   `series_screen.dart`, used by **both** the live completion screen and this
   detail view, with the live screen's behaviour and test keys unchanged. If
   `SessionSnapshot.fromJson` throws (e.g. a stored session naming a program no
   longer resolvable), the detail view shows a graceful **"Kan ikke vise denne
   økta"** message instead of crashing.
5. **The entry point.** `ProgramPickerScreen` gains a **"Mine økter"** app-bar
   action (a history icon) placed **before** the sign-out button, that pushes
   `MySessionsScreen`.

## Rationale

The two sources are unioned **deduplicated by id, synced winning**, because the
queue and the server overlap by design: a record is enqueued the instant a
session completes (spec 0025) and only removed from the queue once it uploads, so
during the window between completion and a successful flush the same `id` is in
both places. Counting it once — as synced when the server already has it — is the
honest picture; the leftover pending copy is just awaiting its removal and must
not show as a second, "not synced" row. Keying on the stable client-generated
`id` (ADR-0017) is exactly the dedup key the upload pipeline already uses.

Sorting **most-recent-first by `capturedAt`** matches how a shooter thinks about
their log — newest at the top — and `capturedAt` is the queryable column spec
0024 stores for precisely this. Records without a `capturedAt` (a session shot
with no metadata) sort **last** rather than being dropped, so nothing recorded is
ever hidden.

The detail view **re-scores from the `payload`** rather than trusting the stored
`total`, reusing the same `SessionSnapshot` → `ScoringService` path the live
recording uses, so a scorecard opened from history is computed by the current
scoring tables and is identical to the one shown at completion. Extracting the
existing scorecard into a **public** `SessionScorecard` (instead of duplicating
its layout) keeps a single source of truth for the per-stage / per-series
rendering (spec 0023) — the live screen and the history detail can never drift
apart. `SessionSnapshot.fromJson` already **throws a `FormatException` on an
unknown program**; catching it and showing **"Kan ikke vise denne økta"** keeps a
stale record from crashing the screen, consistent with the best-effort spirit of
specs 0024/0025.

Making the merge a **pure view-model** (`MySessionEntry` list) keeps the
synced/pending/dedup/sort logic unit-testable without a widget or a real
backend, mirroring how the rest of the domain is kept testable in isolation.

**Keeping the list current.** The pending half reads the **live** upload queue
(`uploadQueueProvider`'s in-memory state), so the instant a completed session is
enqueued (spec 0025) the queue state changes, `mySessionsProvider` recomputes,
and the new row appears **with no reopen** — fixing a defect where a session
finished after the screen was first shown stayed invisible because the cached
one-shot read was never refreshed. The synced half is refreshed by
`ref.invalidate(mySessionsProvider)` **before** the picker pushes the screen,
so a session that has synced since the list was last viewed shows on the next
open. The empty state's **"Velg program"** button is a plain
`Navigator.maybePop` back to the picker, the screen's only entry point.

**Robust pending source — the live queue *unioned with* the durable store.** The
pending half is the **union** of the live `uploadQueueProvider` state **and** the
persisted `PendingUploadsStore`, deduplicated by `id`. The live half gives the
immediacy above; the store half guarantees **correctness regardless of how the
queue notifier resolves**. A completed session is enqueued from inside
`SeriesScreen`'s **nested `ProviderScope`** (spec 0004 wiring): the enqueue both
mutates the queue's in-memory state *and* persists the record to the shared
store *before* it flushes. The store is therefore the single shared, durable
source the enqueue **always** writes. Were the nested scope ever to resolve a
*different* `uploadQueueProvider` instance than this root provider watches, the
live state alone could miss the just-finished row — but the store copy still
surfaces it. Reading both keeps the list correct without giving up the live
half's no-reopen immediacy, and the store read is best-effort (an unreadable
store simply contributes nothing), so the provider still never needs to throw.
This is a belt-and-suspenders guard: the live-only read is already correct when
the root queue is built eagerly at app start (`TreffpunktApp` watches it), and
the high-fidelity flow test confirms the real picker → setup → series → history
path shows the finished session; the store union makes that independent of any
future scope/instance change.

## Design

```
lib/features/scoring/
  data/
    session_repository.dart        + list() on the interface;
                                   InMemorySessionRepository.list() -> uploads.
    supabase_session_repository.dart
                                   + list(): select ordered by captured_at desc,
                                   mapped to SessionRecord; best-effort -> const []
                                   (the only supabase-importing file; test-excluded).
  presentation/
    my_sessions_providers.dart     MySessionEntry { record, synced };
                                   mySessionsProvider (FutureProvider): union of
                                   list() (synced) + pending, deduped by id
                                   (synced wins), tagged, sorted recent-first
                                   (null capturedAt last). The pending half is the
                                   union of watch(uploadQueueProvider) (live) and
                                   pendingUploadsStoreProvider.load() (durable),
                                   deduped by id (live wins), best-effort.
                                   mergeMySessions(...) is a pure helper so the
                                   merge is unit-testable.
    my_sessions_screen.dart        MySessionsScreen (ConsumerWidget): "Mine økter"
                                   app bar; cards (program, date/place, score,
                                   weapon, "Ikke synkronisert" badge on pending);
                                   friendly empty state (hint + "Velg program"
                                   button), loading / error states; tap -> detail.
    series_screen.dart             _SessionScorecard -> public SessionScorecard
                                   (read-only scorecard reused by both screens);
                                   live screen behaviour and keys unchanged.
    program_picker_screen.dart     + "Mine økter" history app-bar action (before
                                   the sign-out button) that invalidates
                                   mySessionsProvider then pushes MySessionsScreen.
```

The detail view resolves the program from `ProgramCatalogue` via
`SessionSnapshot.fromJson(record.payload)`, scores it with `ScoringService` and
renders `SessionScorecard`. The `fromJson` `FormatException` (an unknown program
name) is caught and replaced with the **"Kan ikke vise denne økta"** message.

## Verification

### Unit tests

- `session_repository_test` (extended): `InMemorySessionRepository.list()`
  returns the uploaded records (and an empty list before any upload).
- `my_sessions_providers_test` (the pure merge + the union):
  - synced-only records become synced entries; pending-only records become
    pending entries; with neither, the list is empty;
  - a record present in **both** sources appears **once**, tagged **synced**
    (the dedup tiebreak), asserted by `id`;
  - entries are sorted **most-recent-first by `capturedAt`**, with a
    `capturedAt`-less record sorted **last**;
  - `mySessionsProvider` surfaces a record that is in the **persisted store but
    not in the live queue's in-memory state**, tagged pending — the guard that
    the pending half is the store *union*, not the live queue alone.

### Widget tests

- `my_sessions_screen_test` (fake repository + in-memory pending store, no real
  Supabase):
  - renders one row per entry showing program / score / weapon, with the
    **"Ikke synkronisert"** badge present **only** on the pending entries;
  - a session **enqueued onto the live upload queue after the list is first
    shown** appears (with its pending badge) **without the screen being
    reopened** — the regression guard for the stale one-shot-read defect;
  - shows the **"Ingen lagrede økter ennå"** empty state with its hint and the
    **"Velg program"** button when there are none;
  - tapping a row opens the detail scorecard, which shows the per-stage and
    per-series (skive) breakdown for **that** session (assert a per-series row
    from the payload);
  - a record whose payload names a program **not resolvable** by
    `ProgramCatalogue` shows the **"Kan ikke vise denne økta"** message instead
    of crashing.
- `my_sessions_real_flow_test` (the **high-fidelity completion flow**): mounts
  the whole app the way `main()` does (`runTreffpunkt`, signed in, in-memory
  fakes), then drives the **real UI** — picker → `SessionSetupScreen` →
  `SeriesScreen` (its nested `ProviderScope`) — to **complete a whole session**,
  navigates back and opens **"Mine økter"** via the picker's history button, and
  asserts the finished session's row (program, score) shows with the **"Ikke
  synkronisert"** badge. This pins the real nested-scope completion → history
  path, the case the earlier single-`ProviderContainer` test could not reach.
- `series_screen_test` (unchanged): the extracted public `SessionScorecard`
  keeps the live completion screen green — completing a program still reaches the
  same scorecard with the same keys and per-series rows.
- `program_picker_screen_test`: opening the empty **"Mine økter"** history and
  tapping its **"Velg program"** button pops back to the `ProgramPickerScreen`.

### System tests

- The existing `integration_test` flow is unchanged: adding a "Mine økter"
  app-bar action to the picker does not alter the recording flow, and the screen
  uses the in-memory defaults, so no test touches real storage or Supabase.

## Open questions

- Pull-to-refresh and live updates **as a session uploads in the background**:
  the pending half is now live (it watches the upload queue, so a just-completed
  session appears at once), and the synced half re-reads each time the screen is
  opened (`ref.invalidate(mySessionsProvider)`); a record moving from pending to
  synced *while the screen stays open* is still only reflected on the next open.
- Deleting a session from the list, and filtering by program or competition —
  later increments (competition identity arrives with spec 0012).
