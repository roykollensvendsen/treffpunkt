-- Emoji reactions on competition chat messages — schema + RLS + Realtime
-- (spec 0052, the second chat increment).
--
-- One row per (message, user, emoji): a user may react to a message with several
-- distinct emojis, and reacting again with the same emoji removes it (a toggle,
-- done client-side as delete-or-insert).
--
-- RLS reuses the competition helpers, resolving a message to its competition via
-- a new SECURITY DEFINER helper so a reaction policy never re-enters the
-- messages / competitions policies:
--   read   — anyone who can read the message's competition;
--   insert — only your OWN reaction, and only for a competition you participate
--            in;
--   delete — your own reaction (remove it). No update.
--
-- Apply with `supabase db push` or the SQL editor; NOT applied to any hosted
-- project automatically (ADR-0017).

-- The competition a chat message belongs to. SECURITY DEFINER + stable +
-- empty search_path, like the other helpers, so it reads RLS-bypassed and a
-- policy that calls it does not recurse.
create function public.competition_of_message(mid uuid)
  returns uuid
  language sql
  security definer
  stable
  set search_path = ''
as $$
  select competition_id from public.competition_messages where id = mid;
$$;

revoke all on function public.competition_of_message(uuid) from public;
grant execute on function public.competition_of_message(uuid) to authenticated;

create table public.competition_message_reactions (
  message_id uuid not null
               references public.competition_messages (id) on delete cascade,
  user_id    uuid not null default auth.uid()
               references auth.users (id) on delete cascade,
  emoji      text not null,
  created_at timestamptz not null default now(),
  primary key (message_id, user_id, emoji)
);

create index competition_message_reactions_message_id_idx
  on public.competition_message_reactions (message_id);

alter table public.competition_message_reactions enable row level security;

create policy "Reactions are readable by anyone who can read the message"
  on public.competition_message_reactions for select
  to authenticated
  using (
    public.can_read_competition(
      public.competition_of_message(message_id), auth.uid()
    )
  );

create policy "Reactions are insertable by a participant for themselves"
  on public.competition_message_reactions for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and public.is_competition_participant(
      public.competition_of_message(message_id), auth.uid()
    )
  );

create policy "Reactions are deletable by their author"
  on public.competition_message_reactions for delete
  to authenticated
  using (auth.uid() = user_id);

grant select, insert, delete
  on public.competition_message_reactions to authenticated;

-- Live reactions via Realtime; RLS still limits delivery.
alter publication supabase_realtime
  add table public.competition_message_reactions;
