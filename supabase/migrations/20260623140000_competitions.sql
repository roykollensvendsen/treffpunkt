-- Competitions & shared scoreboards — schema + RLS (spec 0010, increment 2).
--
-- Four owner/participant-scoped tables:
--   profiles               one row per signed-in user (display name + avatar), so
--                          a shared scoreboard can show names. Readable by any
--                          authenticated user; writable only to one's own row.
--   competitions           a contest that FIXES a program at creation. Owned by
--                          its creator; public or private.
--   competition_members    the participant list. Membership is created ONLY by
--                          the owner-auto-membership trigger and the
--                          accept_invitation RPC (never by a direct client
--                          insert).
--   competition_invitations the owner invites a person by email; the invitee
--                          accepts (a member row is then created).
--
-- RLS recursion: a competitions SELECT that checks membership and a
-- competition_members SELECT that checks the competition would mutually re-enter
-- each other's policies ("infinite recursion detected in policy"). The cycle is
-- broken with SECURITY DEFINER helper functions that read with RLS bypassed and
-- return only a boolean, so no policy re-enters a protected table's policies.
--
-- Apply with `supabase db push` or the SQL editor; this is NOT applied to any
-- hosted project automatically (ADR-0017).

-- ---------------------------------------------------------------- profiles ---
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  avatar_url   text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Any signed-in user may read any profile, so a scoreboard can show names.
-- Profiles hold only the already-public Google display name and avatar; they are
-- deliberately readable by every authenticated user, but never by `anon`.
create policy "Profiles are readable by any authenticated user"
  on public.profiles for select
  to authenticated
  using (true);

create policy "Profiles are insertable by their owner"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

create policy "Profiles are updatable by their owner"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ------------------------------------------------------------ competitions ---
create table public.competitions (
  id         uuid primary key,
  owner_id   uuid not null default auth.uid()
               references auth.users (id) on delete cascade,
  name       text not null,
  program    text not null,
  is_public  boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.competitions enable row level security;

-- ------------------------------------------------------ competition_members --
create table public.competition_members (
  competition_id uuid not null
                   references public.competitions (id) on delete cascade,
  user_id        uuid not null default auth.uid()
                   references auth.users (id) on delete cascade,
  joined_at      timestamptz not null default now(),
  primary key (competition_id, user_id)
);

alter table public.competition_members enable row level security;

-- -------------------------------------------------- competition_invitations --
create table public.competition_invitations (
  competition_id uuid not null
                   references public.competitions (id) on delete cascade,
  invited_email  text not null,
  invited_by     uuid not null default auth.uid()
                   references auth.users (id) on delete cascade,
  status         text not null default 'pending',
  created_at     timestamptz not null default now(),
  primary key (competition_id, invited_email)
);

alter table public.competition_invitations enable row level security;

-- ----------------------------------------------- SECURITY DEFINER helpers ----
-- These read with RLS bypassed and return only a boolean, so a policy that calls
-- them never re-enters a protected table's policies (the recursion fix). They are
-- side-effect-free (`stable`) and `set search_path = ''`, so every reference is
-- schema-qualified and they cannot be hijacked by a mutable search path.

create function public.is_competition_owner(cid uuid, uid uuid)
  returns boolean
  language sql
  security definer
  stable
  set search_path = ''
as $$
  select exists (
    select 1 from public.competitions c
    where c.id = cid and c.owner_id = uid
  );
$$;

create function public.is_competition_participant(cid uuid, uid uuid)
  returns boolean
  language sql
  security definer
  stable
  set search_path = ''
as $$
  select exists (
    select 1 from public.competitions c
    where c.id = cid and c.owner_id = uid
  ) or exists (
    select 1 from public.competition_members m
    where m.competition_id = cid and m.user_id = uid
  );
$$;

create function public.can_read_competition(cid uuid, uid uuid)
  returns boolean
  language sql
  security definer
  stable
  set search_path = ''
as $$
  select exists (
    select 1 from public.competitions c
    where c.id = cid and (c.is_public or c.owner_id = uid)
  ) or public.is_competition_participant(cid, uid);
$$;

revoke all on function public.is_competition_owner(uuid, uuid) from public;
revoke all on function public.is_competition_participant(uuid, uuid) from public;
revoke all on function public.can_read_competition(uuid, uuid) from public;
grant execute on function public.is_competition_owner(uuid, uuid) to authenticated;
grant execute on function public.is_competition_participant(uuid, uuid)
  to authenticated;
grant execute on function public.can_read_competition(uuid, uuid) to authenticated;

-- ---------------------------------------------------- competitions policies --
-- Read a competition you own, are a member of, or that is public. The check runs
-- in can_read_competition (SECURITY DEFINER), so it does NOT recurse into the
-- competition_members policies.
create policy "Competitions are readable by owner, members, or when public"
  on public.competitions for select
  to authenticated
  using (public.can_read_competition(id, auth.uid()));

create policy "Competitions are insertable by their owner"
  on public.competitions for insert
  to authenticated
  with check (auth.uid() = owner_id);

create policy "Competitions are updatable by their owner"
  on public.competitions for update
  to authenticated
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create policy "Competitions are deletable by their owner"
  on public.competitions for delete
  to authenticated
  using (auth.uid() = owner_id);

-- --------------------------------------------- competition_members policies --
-- See the member list of any competition you can read.
create policy "Members are readable by anyone who can read the competition"
  on public.competition_members for select
  to authenticated
  using (public.can_read_competition(competition_id, auth.uid()));

-- Leave a competition: delete only your own membership. (There is deliberately
-- NO insert policy — membership is created only by the owner-auto-membership
-- trigger and the accept_invitation RPC, both SECURITY DEFINER.)
create policy "Members may delete only their own membership"
  on public.competition_members for delete
  to authenticated
  using (auth.uid() = user_id);

-- ----------------------------------------- competition_invitations policies --
-- The owner manages invitations for their competition; the invitee may see (and
-- decline) invitations addressed to their own email.
create policy "Invitations are readable by the owner or the invitee"
  on public.competition_invitations for select
  to authenticated
  using (
    public.is_competition_owner(competition_id, auth.uid())
    or lower(invited_email) = lower(auth.jwt() ->> 'email')
  );

create policy "Invitations are insertable by the competition owner"
  on public.competition_invitations for insert
  to authenticated
  with check (
    public.is_competition_owner(competition_id, auth.uid())
    and auth.uid() = invited_by
  );

create policy "Invitations are deletable by the owner or the invitee"
  on public.competition_invitations for delete
  to authenticated
  using (
    public.is_competition_owner(competition_id, auth.uid())
    or lower(invited_email) = lower(auth.jwt() ->> 'email')
  );

-- ------------------------------------------------ owner auto-membership ------
-- On creating a competition, add the owner as a member so they appear on the
-- scoreboard uniformly. SECURITY DEFINER so the insert bypasses the (absent)
-- members insert policy.
create function public.add_owner_as_member()
  returns trigger
  language plpgsql
  security definer
  set search_path = ''
as $$
begin
  insert into public.competition_members (competition_id, user_id)
    values (new.id, new.owner_id)
    on conflict (competition_id, user_id) do nothing;
  return new;
end;
$$;

create trigger competitions_add_owner_as_member
  after insert on public.competitions
  for each row execute function public.add_owner_as_member();

-- --------------------------------------------------- accept_invitation RPC ---
-- The only path for an invitee to become a member: verify a pending invitation
-- for the caller's email, add the caller's membership (idempotent), mark the
-- invitation accepted, and return the competition id so the client can navigate.
create function public.accept_invitation(cid uuid)
  returns uuid
  language plpgsql
  security definer
  set search_path = ''
as $$
declare
  caller_email text := lower(auth.jwt() ->> 'email');
begin
  if not exists (
    select 1 from public.competition_invitations i
    where i.competition_id = cid
      and lower(i.invited_email) = caller_email
      and i.status = 'pending'
  ) then
    raise exception 'no pending invitation for this competition'
      using errcode = 'no_data_found';
  end if;

  insert into public.competition_members (competition_id, user_id)
    values (cid, auth.uid())
    on conflict (competition_id, user_id) do nothing;

  update public.competition_invitations
    set status = 'accepted'
    where competition_id = cid
      and lower(invited_email) = caller_email;

  return cid;
end;
$$;

revoke all on function public.accept_invitation(uuid) from public;
grant execute on function public.accept_invitation(uuid) to authenticated;

-- --------------------------------------------------------------- grants ------
-- RLS still confines every request to the policies above. `anon` is intentionally
-- granted nothing. Members has no insert grant: membership is created only by the
-- SECURITY DEFINER trigger/RPC, which run as the function owner.
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.competitions to authenticated;
grant select, delete on public.competition_members to authenticated;
grant select, insert, delete on public.competition_invitations to authenticated;
