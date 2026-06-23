<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0029 — Surface cloud-sync failures

- **Status:** Accepted
- **Related:** ADR-0017 (personal session sync), spec 0024 (personal session
  sync), spec 0025 (upload queue), spec 0026 (My sessions list)

## Context

Personal session sync is deliberately **best-effort** (ADR-0017): a completed
session is saved locally first, and the Supabase read/write never blocks
recording or crashes the app. To honour that, `SessionRepository.list()`
originally **swallowed every error and returned `const []`**, and
`SupabaseSessionRepository.upload()` swallowed too.

That made a real failure indistinguishable from an empty account. When the
hosted `sessions` table had not been created yet (the migration is applied by
hand, ADR-0017 / spec 0024), the read returned `404`, was swallowed to `[]`, and
"Mine økter" showed the friendly empty state — *"Ingen lagrede økter ennå"* —
exactly as if the shooter had simply never saved a session. The only way to tell
the difference was to open the browser network panel and read the `404`. A
maintainer (and a shooter) deserves a visible signal instead.

This spec keeps sync best-effort but makes a **read** failure **observable**: the
read surfaces the error so the screen can show a small, non-blocking notice while
still rendering every local session. The **upload** stays silent — it must never
block the recording flow, and a not-yet-synced session is already shown by its
existing *"Ikke synkronisert"* badge (spec 0026).

## Requirements

1. **The read distinguishes failure from empty.** `SessionRepository.list()`
   returns `const []` for a **successful** read of an empty account, and
   **throws** `SessionSyncException` when the read fails — a missing table,
   denied permission, a dropped connection, or the bounded timeout elapsing.
   `SupabaseSessionRepository.list()` wraps whatever it caught in a
   `SessionSyncException` (still printing it in debug) instead of returning `[]`.
   `InMemorySessionRepository.list()` never throws.
2. **The upload stays silent.** `upload()` is unchanged: it swallows transport
   errors (ADR-0017) so a completion is never blocked, and a session that has not
   uploaded keeps its *"Ikke synkronisert"* badge (spec 0026).
3. **The synced provider propagates the failure.** `syncedSessionsProvider` no
   longer swallows: it bounds the read with the existing timeout (which now
   **throws** on elapse) and lets the error become the provider's error state.
4. **The screen surfaces it without hiding local sessions.** "Mine økter" reads
   the synced value defensively (`.value ?? const []`) so a failed read can never
   hide the local sessions, and reads `hasError` to show a **dismissible,
   non-blocking banner** above the list: *"Kunne ikke hente økter fra skyen —
   viser lokale."* A successful (even empty) read shows **no** banner.
5. **Best-effort intent preserved.** Recording, completion and the local list are
   unaffected by a cloud failure; the banner only *explains* why synced rows may
   be missing.

## Rationale

A silent best-effort read is the right default for *uploads* (never block the
shooter) but the wrong default for a *read whose emptiness is meaningful*: an
empty list and a failed list look identical to the user, so a misconfiguration
(the unapplied migration) hides in plain sight. Throwing a typed
`SessionSyncException` is the smallest change that lets one call site — the
screen — tell the two apart, while every other caller and the in-memory fake are
unaffected. Keeping the banner non-blocking and dismissible, layered **above** an
always-rendered local list, preserves the offline-first guarantee (spec 0026):
the cloud is an enhancement, and its absence is now explained rather than
silent.

## Verification

### Unit / widget tests

- **`my_sessions_screen_test.dart`** (extended):
  - *shows a sync-error banner when the cloud read fails, and still lists the
    local sessions* — a repository whose `list()` throws `SessionSyncException`
    renders `syncErrorBannerKey` **and** the local pending card, not the empty
    state.
  - *the sync-error banner can be dismissed* — tapping `syncErrorDismissKey`
    removes the banner; the local session card remains.
  - *shows no sync-error banner when the cloud read succeeds* — an in-memory
    repository (successful read) renders the session with **no**
    `syncErrorBannerKey`.
- **`my_sessions_real_flow_test.dart`** (unchanged, still green): an
  `_OfflineSessionRepository` whose `list()` returns `const []` (a successful
  empty read) shows the completed session pending, with **no** banner — confirming
  an empty read is not treated as a failure.

### Manual (real backend)

- With the hosted `sessions` table **absent**, open "Mine økter": the banner
  shows and the network panel confirms `GET /rest/v1/sessions` → `404`.
- Apply `supabase/migrations/<ts>_sessions.sql` to the hosted project (see
  `docs/dev/deploy.md` → *Database migrations*); reopen "Mine økter": the read
  returns `200`, the banner is gone, and synced sessions appear.
