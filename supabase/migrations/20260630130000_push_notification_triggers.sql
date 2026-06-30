-- Fire the `notify` Edge Function on new messages and invitations (spec 0060,
-- Increment B).
--
-- Safe to apply before anything is configured: the trigger reads the function
-- URL and shared secret from database settings (`app.notify_url` /
-- `app.notify_secret`) and is a no-op while the URL is unset. Configure with:
--
--   alter database postgres set app.notify_url    = 'https://<ref>.functions.supabase.co/notify';
--   alter database postgres set app.notify_secret = '<same NOTIFY_SECRET as the function>';
--
-- See docs/dev/deploy.md.

create extension if not exists pg_net with schema extensions;

-- Service-role-only helper: map an invited email to its user id, so the sender
-- can find that user's push subscriptions. profiles has no email, so this reads
-- auth.users. Locked down — never callable by clients.
create or replace function public.user_id_for_email(p_email text)
returns uuid
language sql
security definer
set search_path = ''
as $$
  select id from auth.users where lower(email) = lower(p_email) limit 1;
$$;

revoke all on function public.user_id_for_email(text) from public, anon, authenticated;
grant execute on function public.user_id_for_email(text) to service_role;

-- Posts the inserted row to the notify function. Asynchronous (pg_net queues
-- the request), so it never slows the insert.
create or replace function public.notify_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url    text := current_setting('app.notify_url', true);
  v_secret text := current_setting('app.notify_secret', true);
begin
  if v_url is null or v_url = '' then
    return null; -- not configured yet; no-op
  end if;
  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-notify-secret', coalesce(v_secret, '')
    ),
    body := jsonb_build_object(
      'type', tg_op,
      'table', tg_table_name,
      'record', to_jsonb(new)
    )
  );
  return null;
end;
$$;

create trigger competition_messages_notify
  after insert on public.competition_messages
  for each row execute function public.notify_push();

create trigger competition_invitations_notify
  after insert on public.competition_invitations
  for each row execute function public.notify_push();
