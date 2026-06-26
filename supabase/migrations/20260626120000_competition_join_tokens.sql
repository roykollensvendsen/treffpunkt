-- Share a competition join link (spec 0048, ADR-0025).
--
-- A per-competition join token in its own table, owner-only under RLS: the owner
-- reads it to build a shareable link and no one else can — kept off the
-- world-readable competitions row so a *private* competition's link stays private.
-- join_competition(cid, token) is a SECURITY DEFINER that verifies the token and
-- adds the caller as a member (the same trusted-surface pattern as
-- accept_invitation); regenerate_join_token(cid) issues a fresh token,
-- invalidating old links. Membership still has no client insert grant.
--
-- Apply with `supabase db push` or the SQL editor; NOT applied to any hosted
-- project automatically (ADR-0017).

create table public.competition_join_tokens (
  competition_id uuid primary key
                   references public.competitions (id) on delete cascade,
  token          uuid not null default gen_random_uuid()
);

alter table public.competition_join_tokens enable row level security;

-- Owner-only read: the owner reads the token to build the share link; nobody else
-- can. No insert/update/delete grant — rows are managed by the trigger below and
-- regenerate_join_token (both SECURITY DEFINER).
create policy "Join tokens are readable by the competition owner"
  on public.competition_join_tokens for select
  to authenticated
  using (public.is_competition_owner(competition_id, auth.uid()));

-- One token row per competition: backfill the existing ones, and create one for
-- each new competition (alongside the owner-auto-membership trigger).
insert into public.competition_join_tokens (competition_id)
  select id from public.competitions
  on conflict (competition_id) do nothing;

create function public.add_join_token()
  returns trigger
  language plpgsql
  security definer
  set search_path = ''
as $$
begin
  insert into public.competition_join_tokens (competition_id)
    values (new.id)
    on conflict (competition_id) do nothing;
  return new;
end;
$$;

create trigger competitions_add_join_token
  after insert on public.competitions
  for each row execute function public.add_join_token();

-- Join via a shared link: verify the token matches the competition's current
-- token, then add the caller as a member (idempotent). Mirrors accept_invitation.
create function public.join_competition(cid uuid, join_token uuid)
  returns void
  language plpgsql
  security definer
  set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.competition_join_tokens t
    where t.competition_id = cid and t.token = join_token
  ) then
    raise exception 'invalid or expired join link'
      using errcode = 'no_data_found';
  end if;

  insert into public.competition_members (competition_id, user_id)
    values (cid, auth.uid())
    on conflict (competition_id, user_id) do nothing;
end;
$$;

-- Owner regenerates the token, invalidating old links; returns the new token.
create function public.regenerate_join_token(cid uuid)
  returns uuid
  language plpgsql
  security definer
  set search_path = ''
as $$
declare
  new_token uuid;
begin
  if not public.is_competition_owner(cid, auth.uid()) then
    raise exception 'only the competition owner may regenerate the link'
      using errcode = 'insufficient_privilege';
  end if;

  update public.competition_join_tokens
    set token = gen_random_uuid()
    where competition_id = cid
    returning token into new_token;

  if new_token is null then
    raise exception 'unknown competition'
      using errcode = 'no_data_found';
  end if;

  return new_token;
end;
$$;

grant select on public.competition_join_tokens to authenticated;

revoke all on function public.join_competition(uuid, uuid) from public;
grant execute on function public.join_competition(uuid, uuid) to authenticated;
revoke all on function public.regenerate_join_token(uuid) from public;
grant execute on function public.regenerate_join_token(uuid) to authenticated;
