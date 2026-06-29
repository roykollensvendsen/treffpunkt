-- Competition chat — schema + RLS + Realtime (spec 0051).
--
-- One row per chat message in a competition. The chat is the shared back-channel
-- for the people in a competition (owner + members) to talk before/after a
-- match.
--
-- RLS (reusing the SECURITY DEFINER helpers from 20260623140000_competitions.sql
-- so no policy re-enters the competitions / members policies):
--   read   — anyone who can read the competition (can_read_competition);
--   insert — only your OWN message, and only for a competition you participate
--            in (is_competition_participant);
--   delete — the author, OR the competition owner (is_competition_owner), so an
--            owner can moderate their competition's chat. There is deliberately
--            NO update policy: a message is immutable once posted.
--
-- The id is client-minted (a uuid), like competition_results — a plain insert,
-- so it never trips an UPDATE WITH CHECK.
--
-- Apply with `supabase db push` or the SQL editor; NOT applied to any hosted
-- project automatically (ADR-0017).

create table public.competition_messages (
  id             uuid primary key,
  competition_id uuid not null
                   references public.competitions (id) on delete cascade,
  user_id        uuid not null default auth.uid()
                   references auth.users (id) on delete cascade,
  body           text not null,
  created_at     timestamptz not null default now()
);

create index competition_messages_competition_id_created_at_idx
  on public.competition_messages (competition_id, created_at);

alter table public.competition_messages enable row level security;

-- Read: anyone who can read the competition sees its chat.
create policy "Messages are readable by anyone who can read the competition"
  on public.competition_messages for select
  to authenticated
  using (public.can_read_competition(competition_id, auth.uid()));

-- Insert: only your own message, and only for a competition you participate in.
create policy "Messages are insertable by a participant for themselves"
  on public.competition_messages for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and public.is_competition_participant(competition_id, auth.uid())
  );

-- Delete: the author, or the competition owner (moderation).
create policy "Messages are deletable by the author or the competition owner"
  on public.competition_messages for delete
  to authenticated
  using (
    auth.uid() = user_id
    or public.is_competition_owner(competition_id, auth.uid())
  );

grant select, insert, delete on public.competition_messages to authenticated;

-- Live chat via Realtime: deliver inserts/deletes to subscribers. RLS still
-- applies, so only rows a subscriber may read are delivered.
alter publication supabase_realtime add table public.competition_messages;
