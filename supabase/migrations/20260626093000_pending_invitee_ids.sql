-- List a competition's pending invitees as user ids (spec 0032, ADR-0020).
--
-- The owner-facing complement to invite_user_to_competition: it returns the user
-- ids of registered shooters who currently have a *pending* invitation to the
-- competition, so the invite picker can mark them "Invitert" across sessions —
-- not just within the visit that sent the invite.
--
-- Invitations are email-keyed and emails are private (kept out of profiles,
-- spec 0010), so this SECURITY DEFINER RPC resolves invited_email ->
-- auth.users.id server-side and returns only ids — never an email. Email-only
-- invitees who have no account are not returned (they are not in the picker
-- either). Owner-only: a non-owner gets an empty set, mirroring the RLS the
-- owner-facing picker relies on.
--
-- Apply with `supabase db push` or the SQL editor; NOT applied to any hosted
-- project automatically (ADR-0017).

create function public.pending_invitee_ids(cid uuid)
  returns table (user_id uuid)
  language sql
  security definer
  stable
  set search_path = ''
as $$
  select u.id
    from public.competition_invitations ci
    join auth.users u on lower(u.email) = ci.invited_email
    where ci.competition_id = cid
      and ci.status = 'pending'
      and public.is_competition_owner(cid, auth.uid());
$$;

revoke all on function public.pending_invitee_ids(uuid) from public;
grant execute on function public.pending_invitee_ids(uuid) to authenticated;
