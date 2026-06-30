-- Let the author edit their own competition chat message (spec 0070).
--
-- The chat table shipped immutable (a deliberate "no UPDATE policy" — see
-- 20260629160000_competition_messages.sql). Add an author-only UPDATE policy:
-- a message's author may update it, and the `with check` keeps user_id pinned
-- to them so authorship cannot be reassigned. Unlike delete, the competition
-- owner is intentionally not granted edit — moderation stays delete-only, and
-- only the author rewrites their own words (mirrors the forum, spec 0063).

create policy "Messages are editable by their author"
  on public.competition_messages for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
