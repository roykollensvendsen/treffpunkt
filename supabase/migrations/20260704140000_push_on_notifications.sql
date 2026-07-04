-- One push per in-app notification (spec 0136). The notify function used to
-- listen to the source tables; now the notifications table IS the push
-- source — recipients, dedup and wording are decided once by the spec-0094
-- fan-out, so OS pushes and in-app varsler can never disagree, and every
-- kind (mentions included) pushes. New forum threads keep their own trigger:
-- moderator alerts have no notifications-row equivalent.

create trigger notifications_notify
  after insert on public.notifications
  for each row execute function public.notify_push();

drop trigger if exists competition_messages_notify on public.competition_messages;
drop trigger if exists competition_invitations_notify on public.competition_invitations;
drop trigger if exists forum_posts_notify on public.forum_posts;
