-- Emoji reactions on forum threads and replies (spec 0055).
--
-- One polymorphic table for both: a reaction targets a thread or a post
-- (target_type), so a single table + one set of policies covers both — useful
-- for "voting" 👍 on a bug or feature idea. Reacting again with the same emoji
-- removes it (a client-side toggle).
--
-- The forum is readable by every signed-in user, so RLS is simple and needs no
-- helper:
--   read   — any authenticated user;
--   insert — only your own reaction (user_id = auth.uid());
--   delete — your own reaction.
--
-- target_id is polymorphic (no foreign key), so a deleted thread/post may leave
-- orphan reactions — harmless and sweepable later.
--
-- Apply with `supabase db push` or the SQL editor; NOT applied to any hosted
-- project automatically (ADR-0017).

create table public.forum_reactions (
  target_type text not null check (target_type in ('thread', 'post')),
  target_id   uuid not null,
  user_id     uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  emoji       text not null,
  created_at  timestamptz not null default now(),
  primary key (target_type, target_id, user_id, emoji)
);

create index forum_reactions_target_idx
  on public.forum_reactions (target_type, target_id);

alter table public.forum_reactions enable row level security;

create policy "Forum reactions are readable by any authenticated user"
  on public.forum_reactions for select to authenticated using (true);

create policy "Forum reactions are insertable by their author"
  on public.forum_reactions for insert to authenticated
  with check (auth.uid() = user_id);

create policy "Forum reactions are deletable by their author"
  on public.forum_reactions for delete to authenticated
  using (auth.uid() = user_id);

grant select, insert, delete on public.forum_reactions to authenticated;

alter publication supabase_realtime add table public.forum_reactions;
