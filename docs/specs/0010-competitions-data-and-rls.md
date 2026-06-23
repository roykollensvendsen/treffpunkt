<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0010 — Competitions: data model & Row-Level Security

- **Status:** Accepted
- **Related:** ADR-0019 (competitions data model), ADR-0017 (personal session
  sync — the seam/RLS pattern this mirrors), ADR-0013 (offline-first), spec 0024
  (personal session sync), spec 0029 (surfacing sync failures)

## Context

Increment 1 is complete and personal session sync is live: a signed-in shooter's
completed sessions upload to their own account (owner-only). The next milestone
is the app's core promise — **competitions with shared scoreboards** (ROADMAP
increment 2, specs 0010–0015).

This spec lays the **data foundation** only: the Postgres schema, the
Row-Level Security, the pure-Dart domain model and the `CompetitionRepository`
seam — with **no UI** (the create/invite/accept screens are spec 0011). It
mirrors how spec 0024 shipped the `sessions` foundation before any screen.

Two decisions were taken with the maintainer:

- **Explicit invitations.** The owner invites a person **by email**; the invitee
  accepts to become a member. (Not a join code.)
- **Results are deferred to spec 0012.** Routing a completed session to a
  competition needs a write path that does not exist yet; building the results
  table now would land dead schema and, worse, would require **broadening the
  live owner-only `sessions` RLS policy** — the single riskiest change in the
  increment. 0010 therefore ships profiles + competitions + members +
  invitations only, and the live `sessions` policy is **not touched**.

## Requirements

1. **Four tables, RLS-enabled, `authenticated`-only** (never `anon`):
   `profiles`, `competitions`, `competition_members`, `competition_invitations`,
   in the DDL style of the `sessions` migration.
2. **Profiles.** One row per user (`id` = `auth.users.id`) holding the
   already-public Google `display_name` / `avatar_url`, so a scoreboard can show
   names. Readable by **any authenticated** user; writable only to one's own
   row. The app upserts its own profile on sign-in, best-effort.
3. **Competitions fix a program.** A competition has a client-generated `id`
   (idempotent upsert), an `owner_id` defaulting to `auth.uid()`, a `name`, a
   fixed `program` name (resolved via `ProgramCatalogue.byName`) and `is_public`
   (default `false`). Readable by owner / member / public; writable only by the
   owner.
4. **Membership.** `competition_members` is the participant list, keyed by
   `(competition_id, user_id)`. Readable by anyone who can read the competition;
   a user may **leave** (delete own row). There is **no client insert** —
   membership is created only by the owner-auto-membership trigger and the
   `accept_invitation` RPC.
5. **Invitations.** The owner invites by `invited_email` (stored lower-cased);
   the owner manages invitations for their competition and the invitee may see
   and decline invitations addressed to their email
   (`lower(invited_email) = lower(auth.jwt() ->> 'email')`).
6. **No RLS recursion.** Cross-table visibility checks go through
   `SECURITY DEFINER` helpers that read with RLS bypassed and return a boolean,
   so no policy re-enters another policy (`infinite recursion detected in policy`
   must never occur).
7. **The Dart seam.** Pure-Dart `Competition`, `CompetitionMember`,
   `CompetitionInvitation`, `Profile`; a `CompetitionRepository` interface with
   `InMemoryCompetitionRepository` (default + fake) and
   `SupabaseCompetitionRepository` (the only new `supabase_flutter` file,
   excluded from tests), wired through `runTreffpunkt` / `main` like
   `sessionRepository`. A failed background profile upsert never breaks sign-in;
   foreground operations the user waits on (create / invite / accept) and all
   reads surface failure as `CompetitionSyncException`.

## Design

### Schema (`supabase/migrations/<ts>_competitions.sql`)
Four tables as above. `competitions.id` and a composite member/invitation PK
(no surrogate ids). RLS recursion is broken with three `SECURITY DEFINER` SQL
helpers — `is_competition_owner`, `is_competition_participant`,
`can_read_competition` — each `stable`, `set search_path = ''`, `execute`
granted to `authenticated` only. Membership is created by:

- an **owner-auto-membership trigger** (`SECURITY DEFINER`) on `competitions`
  insert, so the owner appears on the scoreboard and no client insert grant is
  needed; and
- the **`accept_invitation(cid)` RPC** (`SECURITY DEFINER`): verify a pending
  invitation for the caller's email, add the caller's membership
  (`on conflict do nothing`), mark the invitation accepted, return `cid`. The
  only path for an invitee to join.

### Threat model (no leak)
A private competition is invisible to non-invitees (the competition SELECT and
the member-list SELECT are both gated by `can_read_competition`); a user can
invite / rename / delete only their own competition; **nobody can add a third
party** (membership only via the trigger or the caller's own `accept_invitation`,
and every direct member/invitation insert checks `auth.uid()`); the invitee sees
only invitations to their email; profiles hold only already-public data; `anon`
is granted nothing.

### Dart seam (`lib/features/competitions/`)
`CompetitionRepository`: `upsertOwnProfile` (silent), `createCompetition`,
`listMine`, `invite`, `listMyInvitations`, `acceptInvitation`, `membersOf`.
`InMemoryCompetitionRepository` is scoped to a `currentUserId`/`currentEmail`
(and offers `asUser()` to drive a multi-user flow against one store) so it
mirrors the RLS visibility. The on-sign-in upsert is a small root-watched
notifier (`profileSyncProvider`), `fireImmediately` so an already-signed-in user
is covered.

## Rationale

Reusing the established seam (interface + in-memory + one Supabase file +
provider override) keeps every layer testable without a real backend and the
Supabase file the single audited integration point, exactly like `sessions`.
Modelling membership creation behind `SECURITY DEFINER` (trigger + RPC) rather
than a client insert is what makes "knowing you were invited authorises joining"
expressible without a policy that could let anyone self-join, and the same
definer pattern is the only clean way to avoid mutually-recursive policies.
Deferring results keeps the load-bearing personal-sessions policy frozen until
the write path that needs the broadened read actually exists (spec 0012), where
the recommendation is a **separate `competition_results` table** rather than a
`competition_id` on `sessions`.

## Verification

### Unit / provider tests (never import Supabase)
- `competition_domain_test.dart`: json round-trips; `Profile.fromAppUser`;
  `toInsertJson` omits owner/inviter; embedded-competition parsing.
- `competition_repository_test.dart` (InMemory): create is idempotent and
  auto-adds the owner; `listMine` = owned + joined (excludes others');
  `invite` → `listMyInvitations` for the invited email (case-insensitive), and
  the inviter is not the invitee; `acceptInvitation` joins the caller and is
  consumed (a second accept fails); `membersOf` attaches profiles.
- `competition_providers_test.dart`: on sign-in the profile is upserted once; a
  failing upsert does not break sign-in.

### Manual RLS (local Supabase + `psql`, two users)
With the migration applied to a **local** project, acting as two real users
(`set role authenticated` + `request.jwt.claims`): the owner creates a private
competition (auto-added as a member); a stranger sees nothing of it; the owner
invites the stranger by email; the invitee sees the invitation, accepts via the
RPC, becomes a member and can then read the competition and its members; the
invitee cannot invite / rename / delete it or add a third user; making it public
exposes it to any authenticated user; **no `infinite recursion detected in
policy`** on any SELECT; profiles readable by any authenticated, writable only to
self; `anon` sees nothing. (All confirmed during authoring.)

### Held hosted migration
Per ADR-0017 the migration is **not** applied to hosted automatically; the
maintainer runs `supabase db push` (see `docs/dev/deploy.md`).

## Known limitations / next increment

No UI yet (spec 0011). Results/scoreboards land in spec 0012 (a separate
`competition_results` table + its RLS + the writer — the deferred decision) and
spec 0013 (the per-competition list via Realtime). Invitations are by email and
permanent until accepted/declined; rotation/expiry and owner-removes-member are
not modelled here.
