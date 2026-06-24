<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0012 — Shoot for a competition + scoreboard

- **Status:** Accepted
- **Related:** spec 0010 (competitions data & RLS — the helpers reused here),
  spec 0011 (competitions UI), spec 0024 (personal session sync), spec 0025
  (upload queue — reused for durable submission), ADR-0019

## Context

Competitions can be created, joined and seen (specs 0010–0011), but they do
nothing yet. This spec makes them *score*: a shooter **shoots for a competition**
(the program is locked by the competition), and on completion the result is
submitted to a **scoreboard** every participant can read.

The flow is **"Skyt nå" from a competition** (the user's choice), so the result's
program always matches the competition's — no needs-attention state. Results land
in a **separate `competition_results` table** (the deferred 0010 decision), so the
live owner-only `sessions` policy is untouched. A basic scoreboard read ships here
to make it verifiable; a Realtime list and best/last-per-shooter ranking are
spec 0013.

## Requirements

1. **`competition_results` table + RLS.** One row per submitted result, keyed by
   the **session id** (so a re-submit is a no-op). Read by anyone who can read the
   competition (`can_read_competition`); insert only your **own** result for a
   competition you **participate in** (`auth.uid() = user_id AND
   is_competition_participant(...)`); **no update** (immutable); delete your own
   (retract). Reuses the spec-0010 `SECURITY DEFINER` helpers, so no policy
   recurses. `authenticated`-only; `anon` gets nothing.
2. **Idempotent submission under RLS.** `submitResult` uses `INSERT ... ON
   CONFLICT DO NOTHING` (`upsert(..., ignoreDuplicates: true)`). With no UPDATE
   path, only the INSERT check runs — RLS-safe (unlike the `ON CONFLICT DO
   UPDATE` that the create flow had to avoid), and a queued retry is a
   server-side no-op.
3. **Shoot for the competition.** A "Skyt nå" action on the competition detail
   launches the competition's fixed program (`ProgramCatalogue.byName`), carrying
   the competition id. On completion the result is submitted; the session is also
   saved to "Mine økter" as usual. Shown to participants; disabled with "Ukjent
   program" if the program no longer resolves.
4. **Durable submission via the one upload queue.** The completed `SessionRecord`
   carries the `competitionId` (in the queued JSON only — not a `sessions`
   column). The upload queue, after uploading the session, also submits the
   result; a record is dropped only when **both** succeed. Both are idempotent,
   so a partial failure re-runs safely, reusing the queue's offline/retry/sign-in
   machinery.
5. **Scoreboard.** A "Resultater" section on the detail shows the results, best
   first (highest total, then most inner tens), with each submitter's name; a
   loading/error/empty state like the members section.

## Design

- **Schema:** `supabase/migrations/20260623160000_competition_results.sql`.
- **Domain:** `CompetitionResult` (`fromSessionRecord`, `fromJson`,
  `toInsertJson` omitting `user_id`, `withProfile` / `withUser`).
- **Repository:** `submitResult` (idempotent) + `resultsOf` (two-step profile
  read like `membersOf`, tolerating missing profiles) on the interface +
  `InMemory` (`putIfAbsent` mirrors DO NOTHING) + Supabase; `competitionResults
  Provider` family.
- **Flow:** `SessionRecord.competitionId`; `currentCompetitionIdProvider`
  overridden in `SeriesScreen`; `SessionSetupScreen` / `SeriesScreen` forward the
  id; `_enqueueCompletedSession` stamps it; the upload queue's per-record upload
  submits the result.
- **Trade-off (flagged):** the upload queue (in `features/scoring`) now reads the
  `competitionRepositoryProvider` (in `features/competitions`) — a deliberate
  scoring → competitions dependency, justified because the queue is the durability
  orchestrator and both repos are testable interface seams.

## Rationale

Keying the result on the session id makes "submit" idempotent for free, which is
exactly what the durable queue needs; `ON CONFLICT DO NOTHING` then makes that
idempotency RLS-safe (the one shape that doesn't run an UPDATE check). Reusing the
single upload queue — rather than a parallel results queue — gives offline
durability and retry without new machinery, at the cost of one cross-feature
provider read. The participation-gated insert (not merely readable) keeps a public
competition's scoreboard from being posted to by a non-member, consistent with the
owner-auto-membership model.

## Verification

### Unit / widget tests
- `competition_domain_test.dart`: `CompetitionResult.fromSessionRecord` /
  `fromJson` / `toInsertJson` (omits `user_id`) / `withProfile` / `withUser`.
- `competition_repository_test.dart`: `submitResult` idempotent (first wins),
  `resultsOf` sorted best-first with profiles.
- `upload_queue_test.dart`: a record with a `competitionId` submits **both** and
  ends empty; a failing submit keeps it queued then drains on heal; a personal
  session never calls `submitResult`.
- `competitions_screen_test.dart`: the detail scoreboard is sorted with names;
  "Skyt nå" opens the setup for the competition's program.

### Manual RLS (local Supabase, two users)
Verified during authoring: idempotent insert accepted and a re-submit adds no
row; impersonation (`user_id` = another) and a non-participant insert rejected; a
member reads the scoreboard, a non-member reads nothing; no recursion.

### Real backend (driven app)
A signed-in user shoots a competition's program from "Skyt nå"; the result
auto-submits and appears on the scoreboard; the row is in `competition_results`
with the owner's `user_id`.

### Held hosted migration
Per ADR-0017, the migration is **not** applied to hosted automatically; the
maintainer runs `supabase db push`.

## Known limitations / next increment

The scoreboard is a plain read (no Realtime; refreshed on open / on return from a
shoot) — Realtime + best/last-per-shooter ranking is spec 0013. A shooter who
shoots the program twice gets two rows. Submission reaches the scoreboard only
after the queue flushes (online + signed in), like personal sessions.
