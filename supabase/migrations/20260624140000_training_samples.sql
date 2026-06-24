-- Consented training-image collection (spec 0041 / ADR-0023).
--
-- One row per contributed scan, owned by the signed-in shooter. The JPEG lives
-- in the private `training-images` Storage bucket under `<uid>/<id>.jpg`; the
-- row's `image_path` points at it and `label` (jsonb) is the self-describing
-- annotation (geometry + image-pixel calibration + per-hole coordinates).
--
-- Owner-only Row-Level Security on both the table and the bucket: a shooter can
-- only ever insert/select/delete their own rows and their own objects (the
-- object's first path segment must equal their uid). `anon` is never granted —
-- only signed-in shooters contribute, so every object has an owner and erasure
-- is possible.
--
-- Apply with `supabase db push`; NOT applied to any hosted project
-- automatically (ADR-0002).

-- 1. Private bucket for the JPEGs. public=false => no anonymous URL access;
-- every read goes through an authenticated, RLS-checked request.
insert into storage.buckets (id, name, public)
values ('training-images', 'training-images', false)
on conflict (id) do nothing;

-- 2. Storage RLS: an authenticated user may write/read/delete only objects
-- whose first folder segment is their own uid (the `<uid>/<id>.jpg` layout).
create policy "Training images are insertable by their owner"
  on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'training-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Training images are selectable by their owner"
  on storage.objects
  for select to authenticated
  using (
    bucket_id = 'training-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Training images are deletable by their owner"
  on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'training-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- 3. The annotation table.
create table public.training_samples (
  id          uuid primary key,
  user_id     uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  image_path  text not null,
  program     text not null,
  label       jsonb not null,
  app_version text,
  created_at  timestamptz not null default now()
);

alter table public.training_samples enable row level security;

create policy "Training samples are selectable by their owner"
  on public.training_samples
  for select
  using (auth.uid() = user_id);

create policy "Training samples are insertable by their owner"
  on public.training_samples
  for insert
  with check (auth.uid() = user_id);

-- Delete is granted now so the self-serve "slett mine bidrag" fast-follow is a
-- pure client change. A sample is otherwise immutable (re-contributing mints a
-- fresh id), so there is no update policy.
create policy "Training samples are deletable by their owner"
  on public.training_samples
  for delete
  using (auth.uid() = user_id);

grant select, insert, delete on public.training_samples to authenticated;

-- Note: deleting an account cascades the rows above, but NOT the Storage
-- objects (they are not reached by the table FK). When erasing a user, also
-- purge their `training-images/<uid>/` prefix (see docs/dev/deploy.md).
