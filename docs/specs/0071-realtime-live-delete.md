# Spec 0071 — Live delete/edit over filtered Realtime

- **Status:** Accepted.
- **Related:** 0051 (competition chat), 0054 (forum), 0063/0070 (edit),
  `20260701120000_realtime_replica_identity_full.sql`.

## Context
Deleting (or editing) a chat message did not update the screen live — the
message only disappeared after restarting the app. Posting a **new** message
appeared immediately, so Realtime was connected; only DELETE/UPDATE went missing.

The competition-chat subscription filters Supabase **Postgres Changes** by
`competition_id`; the forum-reply subscription filters by `thread_id`. Supabase
applies that filter to each change event's row. With a table's **default replica
identity** (the primary key only), a DELETE event's row carries just `id` — the
filter column is absent, so Realtime cannot match the filter and drops the event
before it reaches the client. INSERTs are unaffected because the new row carries
every column.

## Requirements
1. Deleting a message/reply is reflected **live** for everyone watching, without
   a reload.
2. Editing (spec 0063/0070) likewise arrives live.
3. No change to which rows a client receives (the `competition_id` / `thread_id`
   filters stay; this only makes the filter evaluable for DELETE/UPDATE).

## Rationale
**`REPLICA IDENTITY FULL` on the filtered tables.** It makes Postgres log the
**whole old row** in UPDATE/DELETE WAL records, so the filter column is present
and the event matches. This is the standard fix for "filtered Realtime drops
DELETE events". Only `competition_messages` and `forum_posts` need it — they are
the tables whose subscriptions filter by a non-primary-key column. The reaction
tables subscribe **without** a filter, so their deletes already arrive; they keep
the default identity to avoid the small extra WAL cost.

**Not client-side filtering.** Dropping the server filter and matching by
`competition_id` in the app would also work, but it streams every competition's
traffic to every client; keeping the server filter and making it evaluable is
cheaper and the smaller change.

## Design
- `supabase/migrations/20260701120000_realtime_replica_identity_full.sql`:
  `alter table … replica identity full` on `competition_messages` and
  `forum_posts`. **Must be applied to the hosted database.**
- No app code changes: the existing subscriptions already listen for
  `PostgresChangeEvent.all`; they simply start receiving the DELETE/UPDATE events
  the filter was silently discarding.

## Verification
- **Manual (hosted):** with two sessions in one competition, deleting a message
  in one removes it from the other **without** a reload; editing updates it live.
  Same for a forum reply.
- **DB:** `relreplident` is `f` (full) for `competition_messages` and
  `forum_posts` after the migration.

## Out of scope
- Reaction tables (no filter; already live).
- Any change to the delete/edit permissions (RLS unchanged).
