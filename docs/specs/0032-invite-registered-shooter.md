<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0032 — Invite a registered shooter from a list

- **Status:** Accepted
- **Related:** spec 0010 (competitions data & RLS — profiles + invitations),
  spec 0011 (create / invite / join UI — the invite-by-email control this
  extends), ADR-0019 (competitions data model), ADR-0020 (invite-by-user-id RPC)

## Context

Today a competition owner can only invite people by **typing an email address**
(spec 0011). But every shooter who has signed in already has a public profile
(`profiles`, readable by any authenticated user — spec 0010). The owner should be
able to **see the registered shooters and pick one to invite**, without knowing
or typing their address.

The obstacle is deliberate: `profiles` holds only `id`, `display_name` and
`avatar_url` — **never an email** — while invitations are keyed by
`invited_email`. So "pick a profile → invite" must turn a chosen *user* into an
email-keyed invitation **without ever exposing emails to the client**.

## Requirements

1. **See registered shooters.** The owner's detail screen lists the registered
   shooters (display name + avatar), **excluding themselves and current
   members**, each with an *Inviter* action.
2. **Invite by picking.** Tapping *Inviter* invites that shooter. It reuses the
   existing invitation + accept flow, so the invitee sees the invitation under
   *Invitasjoner* and accepts exactly as for an email invite.
3. **No email exposure.** The client never receives any shooter's email. The
   chosen shooter's email is resolved **server-side** and used only to write the
   invitation.
4. **Owner only.** Only the competition owner may invite; the server rejects a
   non-owner regardless of the client.
5. **Idempotent.** Inviting a shooter who is already invited is a harmless no-op.
6. **Email invite stays.** The type-an-email control remains, for people who have
   not registered yet.

## Design

- **New SECURITY DEFINER RPC** `invite_user_to_competition(cid, target_user_id)`
  (`supabase/migrations/<ts>_invite_registered_shooter.sql`): verifies the caller
  owns the competition (`is_competition_owner`), looks up the target's email from
  `auth.users` server-side, and inserts the invitation
  (`on conflict do nothing`). No schema change to any table — it reuses
  `competition_invitations` and the existing `accept_invitation` RPC. See
  ADR-0020.
- **Repository seam** (`CompetitionRepository`): `listShooters()` returns the
  registered profiles (name + avatar only); `inviteUser(competitionId, userId)`
  invites a chosen shooter. The Supabase impl reads `profiles` and calls the RPC;
  the in-memory fake mirrors the observable behaviour (it resolves the email from
  the user's own profile sync, then reuses its `invite` path), so widget/unit
  tests exercise the same flow.
- **UI** (`CompetitionDetailScreen`, owner section): a *Velg skytter* list driven
  by `shootersProvider`, each shooter a tile with an *Inviter* button, filtered to
  exclude self and current members (`competitionMembersProvider`). A shooter with
  no display name shows a neutral fallback label — never their email.

## Rationale

Resolving the email inside a `SECURITY DEFINER` RPC keeps the privacy property
that justified leaving email out of `profiles` in the first place (spec 0010): a
world-readable profile directory must not become an email directory. Routing the
invite through the **existing** email-keyed invitation means no second invitation
mechanism, no migration of the invitations table, and the accept path is
unchanged. Owner enforcement lives in the function (not just the UI), matching the
`accept_invitation` / owner-membership pattern already audited in ADR-0019.

## Verification

### Unit / widget (in-memory fake, `competition_repository_test.dart`,
`competitions_screen_test.dart`)
- *`listShooters` returns the registered shooters* (the profiles synced via
  `upsertOwnProfile`).
- *`inviteUser` creates an invitation the target then sees* — invite user B;
  acting as B, `listMyInvitations` shows it and `acceptInvitation` joins B.
- *the picker hides yourself and current members*, and shows the rest.
- *picking a shooter invites them* — tapping *Inviter* reaches the store so the
  invitee has a pending invitation.
- *the email field still works* (spec 0011 behaviour unchanged).

### RLS (local Supabase, `psql`, two users)
- owner → `invite_user_to_competition` writes an invitation carrying the target's
  email; the target then has a pending invitation and can accept.
- a **non-owner** calling the RPC is rejected.
- an unknown / email-less target raises.
- `profiles` remains readable by any authenticated user (re-confirm spec 0010).

### Manual (hosted, after `supabase db push`)
Two accounts: A opens a competition, sees B in the shooter list, taps *Inviter*;
B sees the invitation, accepts, and both appear as members. B (non-owner) does not
get an invite control. No email is ever shown in the list.

## Known limitations / next increment

The list shows all registered shooters (no search/paging yet — fine at club
scale); large directories and an owner-facing "already invited" marker can follow.
Cross-competition ranking (0014) and browsing published results (0015) are
unchanged by this spec.
