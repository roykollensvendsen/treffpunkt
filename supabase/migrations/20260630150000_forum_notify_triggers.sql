-- Notify the app admins about new forum activity (spec 0060).
--
-- Reuses the generic public.notify_push() trigger (it posts the inserted row,
-- with its table name, to the notify Edge Function). The function notifies the
-- admins — minus the author — about a new thread (a bug/idea) or reply.
-- No-op until the notify settings are configured, like the other triggers.

create trigger forum_threads_notify
  after insert on public.forum_threads
  for each row execute function public.notify_push();

create trigger forum_posts_notify
  after insert on public.forum_posts
  for each row execute function public.notify_push();
