-- Hold the notify function's URL + shared secret in a table the trigger reads
-- (spec 0060, Increment B).
--
-- The previous migration read them from `alter database ... set` GUCs, but those
-- cannot be set over the Supabase Management API (permission denied), so the
-- hosted setup could not configure them. A small RLS-locked table can be written
-- with a plain INSERT, so this supersedes the GUC approach.

create table if not exists public.app_settings (
  key        text primary key,
  value      text not null,
  updated_at timestamptz not null default now()
);

alter table public.app_settings enable row level security;
-- No policies: anon/authenticated clients get no access at all. The
-- SECURITY DEFINER trigger below reads it as the function owner (bypassing RLS),
-- and the service role bypasses RLS too.

create or replace function public.notify_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url    text := (
    select value from public.app_settings where key = 'notify_url'
  );
  v_secret text := (
    select value from public.app_settings where key = 'notify_secret'
  );
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
