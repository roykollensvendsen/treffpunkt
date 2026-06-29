-- Image attachments on competition chat messages — private bucket + storage RLS
-- + a message column (spec 0053, the third chat increment).
--
-- A chat message may carry one image. The bytes live in a PRIVATE Storage
-- bucket `chat-images`, under `<competition_id>/<file>`; the message row keeps
-- the object path in `image_path` and the app shows it via a short-lived signed
-- URL (the bucket is private, so a leaked URL expires).
--
-- Storage Row-Level Security reuses the competition helpers, reading the
-- competition id from the object's first path segment:
--   read   — anyone who can read that competition;
--   insert — a participant of that competition.
-- (No client delete policy: an orphaned image when a message is deleted is
-- harmless and can be swept later; deletes are simply not granted.)
--
-- Apply with `supabase db push` or the SQL editor; NOT applied to any hosted
-- project automatically (ADR-0017).

-- The private bucket (id == name).
insert into storage.buckets (id, name, public)
  values ('chat-images', 'chat-images', false)
  on conflict (id) do nothing;

-- Read an image if you can read the competition its path points at.
create policy "Chat images are readable by anyone who can read the competition"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'chat-images'
    and public.can_read_competition(
      ((storage.foldername(name))[1])::uuid, auth.uid()
    )
  );

-- Upload an image only into a competition you participate in.
create policy "Chat images are insertable by a participant"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'chat-images'
    and public.is_competition_participant(
      ((storage.foldername(name))[1])::uuid, auth.uid()
    )
  );

-- The message's optional image (the object path within the bucket).
alter table public.competition_messages
  add column image_path text;
