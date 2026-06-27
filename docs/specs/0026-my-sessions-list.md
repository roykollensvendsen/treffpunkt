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
2. **Combine synced and pending — without ever blocking on the cloud.** The
   merge is the **union of three sources, deduplicated by `id`**, but the local
   sources are read **synchronously** so a slow or unavailable cloud read can
   never hide a session the shooter has on the device:
   - The **pending** (local) records are the **union of two views of the same
     outbox**, deduplicated by `id`: the **live upload queue**
     (`uploadQueueProvider`'s in-memory state, spec 0025) — watched
     synchronously so the just-completed session is there **instantly, with no
     await** — **and** the **persisted store**, exposed by a
     `storedPendingProvider` (`FutureProvider` over
     `pendingUploadsStoreProvider.load()`), the single shared, durable source
     the enqueue **always** writes (the live copy wins a tie, keeping the
     freshest in-memory record).
   - The **synced** records come from a `syncedSessionsProvider`
     (`FutureProvider` over `sessionRepositoryProvider.list()`), loaded in the
     background as a **pure enhancement**: it is **bounded by an 8 s timeout**
     (a hung hosted read resolves to `const []` rather than spinning forever)
     and any error is swallowed to `const []`.
   The screen folds the two background sources in **only once they resolve**
   (`.value ?? const []`), so a slow, hanging or erroring cloud read — and an
   unreadable store — can never hold up or hide the local sessions; they only
   ever **add** rows when ready. A record present in both pending and synced
   counts as **synced** (the server copy wins; the pending one is a duplicate
   awaiting removal). The list is sorted **most-recent-first by `capturedAt`**,
   with records that have no `capturedAt` sorted last. The merge stays a small,
   pure, testable list of `MySessionEntry { record, synced }` via
   `mergeMySessions(...)`.
3. **The "My sessions" screen.** `MySessionsScreen` (a `ConsumerWidget`) shows an
   app bar titled **"Mine økter"** and builds the list **synchronously** from
   the live queue, folding in `storedPendingProvider` and `syncedSessionsProvider`
   as they resolve (so there is no whole-screen loading spinner gated on the
   network):
   - **Data**: a list of cards, one per entry, each showing the program name, the
     date/time and place when present, the score `total / maxTotal` (appending
     `· N Ⓧ`, a ringed X, when `innerTens > 0`), and the weapon name when
     present. A **pending**
     entry carries a clear **"Ikke synkronisert"** badge; a synced entry does
     not. Rows and badges carry findable `Key`s for tests.
   - **Empty**: a friendly empty state — an icon, the line **"Ingen lagrede
     økter ennå"**, the hint **"Fullfør en økt for å se den her."**, and a
     **"Velg program"** button (a findable `Key`) that returns to the program
     picker (`Navigator.maybePop`, since the screen is pushed from it), so a
     first-time shooter is told what to do next.
   - **No network gate**: because the local sources are read synchronously and
     the background sources are best-effort, there is **no whole-screen loading
     spinner or error state** waiting on the cloud. When every source is empty
     the friendly empty state shows; the synced read failing or hanging simply
     means no synced rows are added, never a spinner or an error message.
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

**Local sessions never wait on the cloud — the screen builds synchronously.**
The whole list used to be one `mySessionsProvider` `FutureProvider` that
**awaited `sessionRepositoryProvider.list()` before** computing the local
pending sessions. In the real app that repository is `SupabaseSessionRepository`,
whose `list()` hits hosted Supabase; if that read is slow or hangs — a paused
free-tier project, offline, a missing table that stalls — the whole future
stayed in `AsyncLoading`, the screen showed a spinner, and the user's
just-completed **local** session never appeared. (The tests used
`InMemorySessionRepository.list()`, which returns instantly, so the bug was
invisible.) The fix is to never let the network gate the local list:
`MySessionsScreen` builds **synchronously** from the **live** upload queue
(`watch(uploadQueueProvider)`, where the just-completed session lands the instant
it is enqueued, spec 0025) and folds in the two background reads only once they
resolve (`.value ?? const []`). So the local pending rows render with no await,
and a slow, hanging or erroring cloud read can never hide them — it only adds
synced rows when ready.

**Bounded, best-effort cloud read.** `syncedSessionsProvider` wraps
`sessionRepositoryProvider.list()` with an **8 s timeout** (a hang resolves to
`const []`) and swallows any error to `const []`, so it can neither spin forever
nor throw. It is refreshed by `ref.invalidate(syncedSessionsProvider)` **before**
the picker pushes the screen, so a session that has synced since the list was
last viewed shows on the next open. The empty state's **"Velg program"** button
is a plain `Navigator.maybePop` back to the picker, the screen's only entry
point.

**Robust pending source — the live queue *unioned with* the durable store.** The
pending half is the **union** of the live `uploadQueueProvider` state **and** the
persisted `PendingUploadsStore` (exposed by `storedPendingProvider`,
`ref.invalidate`d alongside the synced read), deduplicated by `id`. The live half
gives the no-reopen immediacy; the store half guarantees **correctness regardless
of how the queue notifier resolves**. A completed session is enqueued from inside
`SeriesScreen`'s **nested `ProviderScope`** (spec 0004 wiring): the enqueue both
mutates the queue's in-memory state *and* persists the record to the shared
store *before* it flushes. The store is therefore the single shared, durable
source the enqueue **always** writes. Were the nested scope ever to resolve a
*different* `uploadQueueProvider` instance than the screen watches, the live
state alone could miss the just-finished row — but the store copy still surfaces
it. Reading both keeps the list correct without giving up the live half's
immediacy, and the store read is best-effort (an unreadable store simply
contributes nothing), so the list still never needs to throw. This is a
belt-and-suspenders guard: the live-only read is already correct when the root
queue is built eagerly at app start (`TreffpunktApp` watches it), and the
high-fidelity flow test confirms the real picker → setup → series → history path
shows the finished session; the store union makes that independent of any future
scope/instance change.

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
                                   mergeMySessions(synced, pending): pure union,
                                   deduped by id (synced wins), tagged, sorted
                                   recent-first (null capturedAt last).
                                   syncedSessionsProvider (FutureProvider):
                                   list() bounded by an 8 s timeout -> const [],
                                   error-swallowed -> const []; background-only.
                                   storedPendingProvider (FutureProvider):
                                   pendingUploadsStoreProvider.load(),
                                   best-effort -> const []; the durable fallback.
    my_sessions_screen.dart        MySessionsScreen (ConsumerWidget): "Mine økter"
                                   app bar; builds the list SYNCHRONOUSLY from
                                   watch(uploadQueueProvider) (live pending),
                                   folding in storedPendingProvider and
                                   syncedSessionsProvider via .value ?? const [].
                                   Pending = union of stored + live (live wins);
                                   no whole-screen loading/error gate on the
                                   network. Cards (program, date/place, score,
                                   weapon, "Ikke synkronisert" badge on pending);
                                   friendly empty state (hint + "Velg program"
                                   button); tap -> detail.
    series_screen.dart             _SessionScorecard -> public SessionScorecard
                                   (read-only scorecard reused by both screens);
                                   live screen behaviour and keys unchanged.
    program_picker_screen.dart     + "Mine økter" history app-bar action (before
                                   the sign-out button) that invalidates
                                   syncedSessionsProvider + storedPendingProvider
                                   then pushes MySessionsScreen.
```

The detail view resolves the program from `ProgramCatalogue` via
`SessionSnapshot.fromJson(record.payload)`, scores it with `ScoringService` and
renders `SessionScorecard`. The `fromJson` `FormatException` (an unknown program
name) is caught and replaced with the **"Kan ikke vise denne økta"** message.

## Verification

### Unit tests

- `session_repository_test` (extended): `InMemorySessionRepository.list()`
  returns the uploaded records (and an empty list before any upload).
- `my_sessions_providers_test` (the pure merge + the background reads):
  - synced-only records become synced entries; pending-only records become
    pending entries; with neither, the list is empty;
  - a record present in **both** sources appears **once**, tagged **synced**
    (the dedup tiebreak), asserted by `id`;
  - entries are sorted **most-recent-first by `capturedAt`**, with a
    `capturedAt`-less record sorted **last**;
  - `storedPendingProvider` surfaces a record that is in the **persisted
    store**, the durable fallback the screen folds in alongside the live queue;
  - `syncedSessionsProvider` **resolves to an empty list when the cloud read
    hangs** (driven under a fake clock past the 8 s timeout), proving it never
    spins forever and so can never gate the local list.

### Widget tests

- `my_sessions_screen_test` (fake repository + in-memory pending store, no real
  Supabase):
  - renders one row per entry showing program / score / weapon, with the
    **"Ikke synkronisert"** badge present **only** on the pending entries;
  - a session **enqueued onto the live upload queue after the list is first
    shown** appears (with its pending badge) **without the screen being
    reopened** — the regression guard for the stale one-shot-read defect;
  - **a local pending session shows even while the cloud read hangs** — the
    repository's `list()` never completes, yet the session already on the live
    queue renders promptly with its **"Ikke synkronisert"** badge, asserting the
    cloud read does not gate the local list (the deployed-app regression);
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
  opened (`ref.invalidate(syncedSessionsProvider)`); a record moving from pending
  to synced *while the screen stays open* is still only reflected on the next
  open. Likewise, a synced read that timed out (or failed) only retries on the
  next open, not while the screen stays mounted.
- Deleting a session from the list, and filtering by program or competition —
  later increments (competition identity arrives with spec 0012).
