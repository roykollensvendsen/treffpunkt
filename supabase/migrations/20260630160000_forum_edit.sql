-- Let the author edit their own forum thread / reply (spec 0063).
--
-- The forum tables shipped immutable (no UPDATE policy). Add an author-only
-- UPDATE policy to each: a row's author may update it, and the `with check`
-- keeps author_id pinned to them so authorship cannot be reassigned. Admins are
-- intentionally not granted edit — moderation stays delete-only (spec 0054).

create policy "Threads are editable by their author"
  on public.forum_threads for update
  using (auth.uid() = author_id)
  with check (auth.uid() = author_id);

create policy "Posts are editable by their author"
  on public.forum_posts for update
  using (auth.uid() = author_id)
  with check (auth.uid() = author_id);
