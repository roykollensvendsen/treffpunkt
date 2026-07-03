-- SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
--
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Spec 0109: notifications can be removed. The recipient may delete their
-- own notifications (one, or all of them); nothing else changes.

create policy "Notifications are deletable by their recipient"
  on public.notifications for delete to authenticated
  using (auth.uid() = user_id);

grant delete on public.notifications to authenticated;
