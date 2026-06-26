<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0048 — Share a competition join link

- **Status:** Accepted
- **Related:** spec 0011 (competitions create/invite/join — the typed-email invite
  this replaces), spec 0032 (pick-a-registered-shooter — the targeted path that
  stays), ADR-0025 (the decision + trade-offs), ADR-0019 (competitions data
  model), ADR-0017 (migrations applied manually)

## Context

Inviting by **typing an email** only writes an invitation the recipient sees once
they sign in with that address — no notification — and actually e-mailing them
would mean operating email infrastructure (provider, sending domain, Edge
Function, deliverability). The owner already has the ideal delivery channel on
their device: the **OS share sheet** (Messenger, SMS, e-mail, … — and the **Web
Share API** in the web app). So we replace the typed-email control with a
**shared, token-gated join link**. See ADR-0025.

## Requirements

1. **Share a link.** The owner's detail screen has a **Del** action that shares a
   link to the competition via the OS share sheet (Web Share API on the web; a
   **Kopier lenke** fallback where sharing is unavailable, e.g. desktop browsers).
2. **Join by link.** Opening the link signs the recipient in if needed, then joins
   them as a member and shows the competition. Idempotent — already a member is a
   no-op. Works for someone **not yet registered** (they sign in first, then join).
3. **Token-gated.** Joining requires the competition's **current** token, so a
   private competition is not world-joinable. The token is **owner-only**: only
   the owner can read it (to build the link).
4. **Regenerable.** The owner can issue a fresh token, invalidating old links.
5. **Anyone with the link.** The link is not tied to a specific email; whoever
   holds it (and is signed in) joins. (The recorded trade-off, ADR-0025.)
6. **Targeted invites stay.** "Pick a registered shooter" (spec 0032) is
   unchanged; only the **typed-email** field is removed.
7. **Nothing personal in the URL.** The link carries only the competition id and
   the (non-personal, regenerable) token — never an email or name.

## Design

- **Schema** (`supabase/migrations/<ts>_competition_join_tokens.sql`): a
  `competition_join_tokens(competition_id uuid primary key references
  competitions on delete cascade, token uuid not null default
  gen_random_uuid())` table, populated for each competition (a trigger on
  `competitions` insert, mirroring owner-auto-membership). **RLS: owner-only
  select** — so the owner reads the token to build the link and no one else can.
  The token is deliberately *not* a column on `competitions` (which is
  world-readable for public competitions), keeping it off every general read.
- **RPCs** (`SECURITY DEFINER`, `set search_path = ''`, `revoke … from public`,
  `grant execute … to authenticated`):
  - `join_competition(cid uuid, token uuid)` — verifies the token matches the
    competition's current token, then inserts `(competition_id, auth.uid())` into
    `competition_members` `on conflict do nothing`; raises on a token mismatch.
  - `regenerate_join_token(cid uuid) returns uuid` — owner-only
    (`is_competition_owner`); sets and returns a new token.
- **Repository seam** (`CompetitionRepository`): `joinToken(competitionId)` (owner
  read), `joinByLink(competitionId, token)` (the RPC), `regenerateJoinToken(
  competitionId)`. The Supabase impl reads the token table / calls the RPCs; the
  in-memory fake mirrors the owner-gated token + token-checked join.
- **Deep link** (web): `parseJoinIntent(Uri.base)` (via `joinIntentProvider`,
  overridable in tests) reads `?join=<cid>&token=<t>` at startup. A
  `JoinLinkHandler` in the **signed-in** branch of the auth gate joins once and
  opens the competitions hub; a bad/stale token shows a notice. A signed-out
  opener signs in first — Google sign-in passes `redirectTo: Uri.base` on the web
  so the link survives the OAuth round-trip, then `JoinLinkHandler` runs on
  return. (A plain sign-in redirects to the same app URL as before.)
- **Share** (`share_plus`): **Del** builds the link from `joinToken` and shares
  `«Bli med i <navn> på Treffpunkt: <lenke>»`; web uses the Web Share API, with a
  clipboard **Kopier lenke** fallback. A **Lag ny lenke** action calls
  `regenerateJoinToken`.
- **UI** (`CompetitionDetailScreen`, owner section): the typed-email
  `_InviteRow` is replaced by the **Del** / **Kopier lenke** controls;
  pick-a-registered-shooter is unchanged.

## Rationale

The owner's share sheet delivers through any channel with zero infrastructure,
cross-platform, and nothing leaves the device at share time — far cheaper and more
private than running email (ADR-0025). A per-competition, owner-only, regenerable
token covers both public and private competitions and bounds the "anyone with the
link" model. Keeping the token off the world-readable `competitions` row (a
separate owner-only table) is what makes a *private* competition's link actually
private. Targeted in-app invites stay for naming a specific shooter.

## Verification

### Unit / widget (in-memory fake)
- *`joinByLink` adds the caller as a member when the token matches*; a **wrong
  token** raises and adds no one; an **already-member** call is a no-op.
- *`joinToken` is owner-only* — the owner reads it; a non-owner does not.
- *`regenerateJoinToken` changes the token* — a link built on the old token then
  fails to join.
- *the deep-link handler* joins and opens the competition when signed in, and
  defers to sign-in (preserving the params) when signed out.
- *the detail screen shows **Del** / **Kopier lenke** (owner) and no typed-email
  field*; pick-a-shooter still works (spec 0032 unchanged).

### RLS (local Supabase, `psql`, two users)
- the owner can `select` their `competition_join_tokens` row; a **non-owner**
  cannot.
- `join_competition` with the right token adds the caller; a **wrong/old** token
  is rejected; a second call is a no-op.
- `regenerate_join_token` is owner-only and invalidates the previous token.

### Manual (hosted, after `supabase db push`)
Owner taps **Del**, shares the link (the share sheet lists the real channels);
opening it on a second account (incl. a brand-new sign-in) joins that account and
shows the competition. Regenerating the link makes the old one stop working.

### Gates
`dart format`, `analyze --fatal-infos`, full `flutter test`, `reuse lint`,
`mkdocs --strict`.

## Known limitations / next increment

- The token rides in the URL (history/referrer logs) — acceptable for a
  regenerable, non-personal invite secret (ADR-0025); not for anything personal.
- One link per competition (anyone with it joins). Per-recipient links / revocation
  and **automatic** e-mail notifications (the Edge Function path) are deferred to a
  later increment if needed.
- Deep links use a query string (`?join=…`) so they survive GitHub Pages + Flutter
  web routing; a prettier path-based link can follow with a router change.
- The signed-out deep-link join relies on Google sign-in redirecting back to the
  full URL (`redirectTo: Uri.base`). The Supabase **Redirect URLs** allow-list
  must therefore permit the app URL **with a query string** (a wildcard like
  `…/treffpunkt/**`); a plain sign-in is unaffected. A signed-*in* opener joins
  with no redirect at all.
- The handler opens the **hub** (where the joined competition appears), not the
  competition detail directly — it avoids a fetch-by-id; a direct-to-detail jump
  can follow.
