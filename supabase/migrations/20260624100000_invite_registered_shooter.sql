-- Invite a registered shooter by user-id (spec 0032, ADR-0020).
--
-- The owner picks a shooter from the profile directory (readable by any
-- authenticated user, but holding no email — spec 0010). Invitations are keyed
-- by email, so this SECURITY DEFINER RPC turns a chosen *user* into an
-- email-keyed invitation WITHOUT ever exposing emails to the client: it resolves
-- the target's email from auth.users server-side and writes the same invitation
-- row a typed-email invite would. Delivery/accept is the unchanged
-- accept_invitation flow.
--
-- Apply with `supabase db push` or the SQL editor; NOT applied to any hosted
-- project automatically (ADR-0017).

create function public.invite_user_to_competition(
  cid uuid,
  target_user_id uuid
)
  returns void
  language plpgsql
  security definer
  set search_path = ''
as $$
declare
  target_email text;
begin
  -- Owner only — enforced here, not just in the UI (mirrors accept_invitation).
  if not public.is_competition_owner(cid, auth.uid()) then
    raise exception 'only the competition owner may invite'
      using errcode = 'insufficient_privilege';
  end if;

  -- Resolve the target's email server-side; the client never sees it.
  select u.email into target_email
    from auth.users u
    where u.id = target_user_id;

  if target_email is null then
    raise exception 'unknown user, or user has no email'
      using errcode = 'no_data_found';
  end if;

  -- Reuse the existing email-keyed invitation; idempotent on (competition, email).
  insert into public.competition_invitations
      (competition_id, invited_email, invited_by)
    values (cid, lower(target_email), auth.uid())
    on conflict (competition_id, invited_email) do nothing;
end;
$$;

revoke all on function public.invite_user_to_competition(uuid, uuid) from public;
grant execute on function public.invite_user_to_competition(uuid, uuid)
  to authenticated;
