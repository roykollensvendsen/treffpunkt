<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0013 — Live scoreboard (Realtime) + ranking

- **Status:** Accepted
- **Related:** spec 0012 (shoot for a competition — the scoreboard this makes
  live), spec 0010 (RLS helpers reused), ADR-0019, ADR-0003 (Riverpod)

## Context

Spec 0012 gave a competition a scoreboard, but it was a plain read: you had to
reopen the screen to see new results, and it listed **every** result row rather
than ranking shooters. This spec turns it into a real leaderboard:

- **Live via Supabase Realtime** — the board updates the moment any participant
  submits, with no reopen.
- **Best-per-shooter ranking** — one row per shooter, their best result, ordered
  best first.

Decided default: **best** result counts (highest total, then most inner tens,
then the earlier shot) — conventional for a competition; changeable later.

## Requirements

1. **Realtime updates.** The competition detail subscribes to its
   `competition_results` and re-reads the scoreboard on every change. The table
   is added to the `supabase_realtime` publication (a migration); RLS still
   applies — a subscriber only receives changes to rows it may SELECT
   (`can_read_competition`), so no new policy is needed.
2. **Realtime behind the seam.** `CompetitionRepository.watchResults(id) →
   Stream<List<CompetitionResult>>` — the Supabase impl is backed by a channel
   (`onPostgresChanges` filtered by `competition_id`, re-reading `resultsOf` on
   each change and on subscribe); the in-memory fake by a broadcast controller
   that re-emits after each `submitResult`. So the feature is testable without a
   real backend, and the channel is cleaned up on cancel (`removeChannel`).
3. **Ranking.** A pure `rankBestPerShooter(results)` keeps each shooter's best
   (max total, then inner tens, then earliest) and sorts best first; the screen
   ranks by index. `resultsOf` / `watchResults` keep returning **all** results —
   ranking is a view transform.
4. **UI.** The detail watches `competitionScoreboardProvider` (a
   `StreamProvider.family`), applies `rankBestPerShooter`, and renders the ranked
   list with the existing loading/error/empty states; "Skyt nå" invalidates it on
   return so a just-shot result shows immediately even if Realtime lags.

## Design

- **Migration:** `supabase/migrations/<ts>_competition_results_realtime.sql` —
  `alter publication supabase_realtime add table public.competition_results;`.
- **Seam:** `watchResults` on the interface + InMemory (broadcast
  `StreamController`, emit on a new `submitResult`) + Supabase (channel; re-read
  on change; `StreamController` whose `onCancel` removes the channel).
- **Ranking:** `lib/features/competitions/domain/scoreboard.dart`
  (`rankBestPerShooter`, pure).
- **Provider/UI:** `competitionScoreboardProvider` replaces the spec-0012
  `competitionResultsProvider`; the detail ranks the emitted list.

## Rationale

Putting Realtime behind `watchResults` (like the auth stream behind
`authStateChangesProvider`) keeps the subscription's lifecycle in the data layer
and the UI a plain `StreamProvider` consumer — and lets the in-memory fake drive
a live-update widget test. Re-reading `resultsOf` on each change (rather than
patching the list from the change payload) is robust: it re-sorts, re-joins
profiles, and is RLS-consistent; club result volumes make the extra read
negligible. Keeping ranking a pure function leaves `resultsOf` unchanged and the
ranking independently testable.

## Verification

### Unit / widget tests
- `scoreboard_test.dart`: `rankBestPerShooter` keeps one row per shooter (best),
  ranks best first, breaks ties by inner tens then earlier shot, and treats a
  user-less result as its own row.
- `competition_repository_test.dart`: `watchResults` emits the initial board then
  re-emits after a `submitResult`.
- `competitions_screen_test.dart`: the detail scoreboard updates **live** when a
  result is submitted to the store (no reopen); the board is ranked best first;
  "Skyt nå" still routes.

### Real backend (local Supabase)
The table is confirmed in `pg_publication_tables` for `supabase_realtime`. The
real app is driven to a competition's scoreboard; a result inserted via REST
appears on the board **live** without reopening, proving the channel +
RLS-scoped re-read.

### Held hosted migration
Per ADR-0017, the publication migration is **not** applied to hosted
automatically; the maintainer runs `supabase db push`.

## Known limitations / next increment

Ranking is best-per-shooter only (no last-vs-best toggle, no per-shooter history).
Cross-competition ranking / a public top-score list is spec 0014; browsing own &
published results is 0015.
