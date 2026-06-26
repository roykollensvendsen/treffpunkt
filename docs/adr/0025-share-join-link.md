<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# ADR-0025: Join a competition by a shared token link, delivered by the OS share sheet

- **Status:** Accepted
- **Date:** 2026-06-26

## Context

Inviting by **typing an email** (spec 0011) writes an email-keyed invitation the
recipient only sees once they sign in with that exact address — there is no
notification. Actually e-mailing them a link would mean operating email
infrastructure: a provider account, a verified sending domain (SPF/DKIM/DMARC for
deliverability), an Edge Function, a database webhook, a stored secret, and an
anti-abuse story — a lot of moving parts, cost, and a deliverability tail, for a
club-scale app that is otherwise just static web + Supabase.

The owner, meanwhile, already has the perfect delivery mechanism on their own
device: the **OS share sheet**. On Android/iOS (and in the web app via the **Web
Share API**) it lists Messenger, SMS, e-mail, WhatsApp, Signal, … — the owner
picks the channel and recipient. We send nothing; they route it.

## Decision

Replace the type-an-email invite with a **shared join link**.

1. Each competition has a **join token** (a random `uuid`) in a separate
   `competition_join_tokens` table, **owner-only** under RLS — so only the owner
   can read it (to build the link), and a leaked link is **regenerable**
   (invalidating old links).
2. The owner's **Del** action shares a link
   `…/?join=<competition_id>&token=<token>` through the OS share sheet
   (`share_plus`; Web Share API on the web, with a copy-link fallback where it is
   unavailable, e.g. desktop browsers).
3. Opening the link signs the recipient in if needed, then calls a
   `SECURITY DEFINER` RPC **`join_competition(cid, token)`** that verifies the
   token and adds the caller to `competition_members` (`on conflict do nothing`).
   A **`regenerate_join_token(cid)`** RPC (owner-only) issues a fresh token.
4. The link is **not tied to a specific email** — anyone holding it (and signed
   in) joins directly. This is the deliberate trade-off versus the targeted email
   invite; the regenerable token bounds it, and targeted in-app invites stay
   (below).
5. **Targeted invites stay.** "Pick a registered shooter" (ADR-0020,
   `inviteUser`) is unchanged — it remains the targeted, in-app path that yields a
   pending invitation the shooter accepts. Only the *typed-email* control is
   removed.

## Consequences

- **No email infrastructure.** No provider, domain, DNS, Edge Function, webhook,
  secret, or deliverability tail to own. Nothing leaves the device server-side at
  share time — consistent with the app's privacy posture.
- **Cross-platform for free.** The share sheet works in the web app on mobile
  (Web Share API) and in any future native build (`share_plus` intents); desktop
  browsers fall back to copy-link.
- **Two membership paths now coexist:** targeted invite + accept (pick-a-shooter,
  ADR-0020) and token join-by-link. Both insert into `competition_members`
  idempotently; a link-join shows as *Deltar* (a member), never *Invitert* (no
  pending row) — consistent with spec 0032.
- **The token rides in the URL.** It is a competition join secret (not personal
  data), like a Discord/Doodle invite link; it can appear in history/referrer
  logs, so it is **regenerable** and never carries anything personal. The owner
  read of the token is owner-only RLS; the join/regenerate writes live in small,
  schema-qualified `SECURITY DEFINER` RPCs granted only to `authenticated`,
  matching the existing competition trusted surface (ADR-0019/0020).
- **Hosted apply is manual** (ADR-0017): the maintainer runs `supabase db push`
  for the new table + RPCs.

## Alternatives considered

- **Send the invite e-mail ourselves** (Edge Function + Resend/Postmark + DB
  webhook): rejected for this increment — real infrastructure, a sending-domain
  and deliverability burden, a stored secret, and an abuse vector, to do what the
  user's own share sheet does for free. Still an option later for *automatic*
  notifications.
- **Supabase Auth `inviteUserByEmail`:** rejected — auth-scoped, creates an auth
  user as a side effect, and its generic template carries no competition context.
- **A world-joinable public competition (no token):** rejected as the mechanism —
  it would not cover private competitions; a per-competition token covers both and
  keeps private ones private.
- **Per-invitation tokens** (one link per recipient): rejected for now — more
  machinery than the "one regenerable link you share in the club chat" model the
  owner asked for; revisit if per-recipient revocation is ever needed.
