# Spec 0126 — Slett din egen profil

- **Status:** Accepted
- **Related:** owner request in-session 2026-07-03 («La oss gjøre det
  mulig å slette sin egen profil»); specs 0003 (auth), 0096
  (destructive actions confirm first)

## Context

There was no way for a shooter to leave: an account and everything
synced to it lived forever. Erasure is both a reasonable expectation
and a legal right.

## Rationale

The schema was built for this from day one: every user-owned row
references `auth.users (id) on delete cascade`, so deleting the auth
user erases the profile, synced sessions and felt rounds, competitions
the user OWNS (including their members' results — the owner-cascade),
memberships, messages, results, forum threads and posts, reactions,
notifications, push subscriptions and training samples in one
statement. A SECURITY DEFINER RPC (`delete_own_account`) scoped to
`auth.uid()` is the entire server side — the client can delete exactly
one account: its own. The app then signs out and lands on the sign-in
gate. Data stored only on the device is NOT touched; the confirmation
says so honestly, and the owner keeps the on-device backup/export path
(spec 0106) to save anything first.

## Requirements

1. Innstillinger's account section has a «Slett profilen min» action.
2. It confirms first (spec 0096) with the consequences spelled out:
   everything synced is erased, competitions you own disappear for
   their members too, forum posts you wrote are removed, the action is
   final; on-device data stays on the device.
3. Confirming calls the RPC (which deletes only `auth.uid()`'s
   account) and signs out; the app returns to the sign-in gate.
4. The RPC refuses unauthenticated callers and is not grantable to
   `anon`.

## Verification

- Widget: the tile shows; cancelling deletes nothing; confirming calls
  the repository's `deleteAccount` once and the auth state ends signed
  out.
- Migration applied to hosted; the function exists with execute
  granted to `authenticated` only.
