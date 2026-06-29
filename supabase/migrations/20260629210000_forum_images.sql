-- Image attachments on forum threads and replies (spec 0056).
--
-- A thread (its opening post) and any reply may carry one image. The bytes live
-- in a PRIVATE `forum-images` bucket; the row keeps the object path in
-- `image_path` and the app shows it via a short-lived signed URL.
--
-- The forum is readable and writable by every signed-in user, so the Storage
-- RLS is simple: read and insert for any authenticated user, scoped to the
-- bucket. (No client delete policy — an orphaned image is harmless.)
--
-- Apply with `supabase db push` or the SQL editor; NOT applied to any hosted
-- project automatically (ADR-0017).

insert into storage.buckets (id, name, public)
  values ('forum-images', 'forum-images', false)
  on conflict (id) do nothing;

create policy "Forum images are readable by any authenticated user"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'forum-images');

create policy "Forum images are insertable by any authenticated user"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'forum-images');

alter table public.forum_threads add column image_path text;
alter table public.forum_posts add column image_path text;
