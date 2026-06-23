<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# ADR-0019: Competitions data model, invitations and RLS

- **Status:** Accepted
- **Date:** 2026-06-23

## Context

Increment 2 adds competitions with shared scoreboards (spec 0010). Unlike
`sessions` (owner-only, ADR-0017), competition data is **shared** — participants
must read each other's competition and member list — which makes the Row-Level
Security materially harder and security-critical. We need a schema, an
invite/join model, and policies that share exactly what they should and nothing
more.

## Decision

- **Four tables:** `profiles` (one per user, the already-public Google name /
  avatar so a scoreboard can show names), `competitions` (fixes a `program` at
  creation; `is_public` default false), `competition_members` (the participant
  list, composite PK), `competition_invitations` (owner invites by email).
- **Explicit invitations, by email.** The owner invites a person by email; the
  invitee accepts. Rejected: join codes (less control over who is in a private
  competition) and a per-user invite-object with accept/decline workflow beyond
  a simple status (more surface than needed now).
- **Membership is created only by `SECURITY DEFINER` paths** — an
  owner-auto-membership trigger and an `accept_invitation` RPC — never by a
  direct client insert. This is what lets "you were invited" authorise joining
  without a policy that would let anyone self-join.
- **RLS recursion is broken with `SECURITY DEFINER` helpers.** A `competitions`
  policy that checks membership and a `competition_members` policy that checks
  the competition would mutually re-enter each other (`infinite recursion
  detected in policy`). Three helpers (`is_competition_owner`,
  `is_competition_participant`, `can_read_competition`) read with RLS bypassed
  and return a boolean, so policies reference them, never the protected tables.
- **Profiles are readable by any authenticated user**, writable only to self;
  `anon` is granted nothing on any table.
- **Results are deferred to spec 0012.** The completed-session→competition write
  path does not exist yet; rather than land dead schema or broaden the live
  owner-only `sessions` SELECT policy now, results (a **separate**
  `competition_results` table, not a `competition_id` on `sessions`) ship in
  0012 with their writer and RLS.
- **The Dart seam mirrors `sessions`** (ADR-0017): a `CompetitionRepository`
  interface, an in-memory default/fake, one `supabase_flutter` file excluded
  from tests, provider override in `runTreffpunkt`. Divergence: the background
  profile upsert is silent (never breaks sign-in) while foreground create /
  invite / accept and all reads surface `CompetitionSyncException`.

## Consequences

- Participants can read a competition and its members; non-invitees see nothing
  of a private one; nobody can add a third party or edit another's competition.
- The personal-sessions policy stays frozen and load-bearing until 0012.
- The `SECURITY DEFINER` helpers are a small, audited trusted surface; each is
  `stable`, `set search_path = ''`, and granted only to `authenticated`.
- Verified on local Supabase with two users, including the explicit
  no-recursion and no-leak checks (spec 0010 Verification).

## Alternatives considered

- **`competition_id` on `sessions` for results (now):** rejected — it forces
  broadening the live owner-only `sessions` SELECT policy with no code
  exercising it, risking cross-user exposure of personal sessions.
- **Membership policy with a self-subquery / cross-table subquery:** rejected —
  recurses; the `SECURITY DEFINER` helpers are the standard fix.
- **Join codes instead of invitations:** rejected at the maintainer's request —
  explicit per-person invites give the owner control over a private roster.
