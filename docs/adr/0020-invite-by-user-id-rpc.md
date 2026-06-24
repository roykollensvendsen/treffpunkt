<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# ADR-0020: Invite a registered shooter by user-id via a SECURITY DEFINER RPC

- **Status:** Accepted
- **Date:** 2026-06-24

## Context

Owners want to invite people by **picking a registered shooter from a list**
rather than typing an email (spec 0032). The profile directory (`profiles`) is
readable by any authenticated user, but by design holds **no email** (ADR-0019,
spec 0010) — a world-readable directory must not leak emails. Invitations, though,
are keyed by `invited_email` and delivered by matching the invitee's JWT email
(`accept_invitation`). So the client can name a *user* but cannot produce the
email the invitation needs.

## Decision

Add a `SECURITY DEFINER` RPC `invite_user_to_competition(cid uuid,
target_user_id uuid)` that:

1. verifies the caller owns the competition via `public.is_competition_owner(cid,
   auth.uid())`, raising `insufficient_privilege` otherwise;
2. resolves the target's email from `auth.users` **server-side** (the client never
   sees it), raising `no_data_found` for an unknown / email-less user;
3. inserts `(competition_id, invited_email, invited_by)` into
   `competition_invitations` with `on conflict do nothing`.

It is `set search_path = ''`, `revoke all … from public`, `grant execute … to
authenticated`. No table or column changes: the existing email-keyed invitation
and the unchanged `accept_invitation` flow do the delivery. The client gains
`listShooters()` (read `profiles`) and `inviteUser(competitionId, userId)` (call
the RPC). The type-an-email control stays for not-yet-registered people.

## Consequences

- The privacy property holds: emails never reach the client; the profile
  directory stays a name/avatar directory, not an email directory.
- One invitation mechanism, one accept path — no second workflow, no invitations
  schema migration.
- Owner enforcement lives in the function, not just the UI — consistent with the
  `accept_invitation` / owner-auto-membership pattern (ADR-0019). The RPC joins
  the same small, audited `SECURITY DEFINER` trusted surface (`stable`-style
  helpers excepted, this one writes), each schema-qualified under an empty
  search path and granted only to `authenticated`.
- Like the other competition migrations, it is **not** auto-applied to hosted
  (ADR-0017); the maintainer runs `supabase db push`.

## Alternatives considered

- **Add `email` to `profiles`:** rejected — makes the world-readable directory an
  email directory (harvesting), the exact thing ADR-0019 avoided.
- **Add `invited_user_id` to `competition_invitations`:** rejected — restructures
  the invitation PK and the accept-by-email matching for no user-visible gain over
  resolving the email in the RPC.
- **Expose emails to the owner client and invite by email from the picker:**
  rejected — leaks every shooter's email to every owner.
