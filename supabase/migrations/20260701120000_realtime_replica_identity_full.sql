-- Deliver live deletes (and edits) over *filtered* Realtime subscriptions
-- (spec 0071).
--
-- The competition-chat subscription filters Postgres Changes by competition_id,
-- and the forum-reply subscription by thread_id. With the default replica
-- identity (primary key only), a DELETE event's record carries just the `id`,
-- so the filter column (competition_id / thread_id) is absent — Realtime cannot
-- match the filter and drops the event before it reaches the client. The result
-- is that a deleted message/reply only disappears after the app is reloaded
-- (INSERTs are unaffected: the new row carries every column, so the filter
-- matches). REPLICA IDENTITY FULL logs the whole old row in UPDATE/DELETE WAL
-- records, so the filtered subscription matches and the change arrives live.
--
-- Only the two tables whose subscriptions filter by a non-primary-key column
-- need this; the reaction tables subscribe without a filter and are unaffected.

alter table public.competition_messages replica identity full;
alter table public.forum_posts replica identity full;
