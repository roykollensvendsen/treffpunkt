# Spec 0094 — Varslingssenter: in-app notifications with deep links

- **Status:** Accepted
- **Related:** spec 0011/0032 (invitations), 0051 (competition chat), 0054
  (forum), 0060 (OS push — this table becomes its event source), 0093
  (detail layout)

## Context

Nothing tells the shooter that something happened: an invitation, a chat
message or a forum reply is only discovered by opening the right screen.
The domain owner asks for clearly visible in-app notifications that jump
straight to the message. OS push (spec 0060) is half-landed and needs a
server-side event source anyway — this spec provides it.

## Requirements

1. A **bell** in the front page's app bar shows a live **unread count**
   badge (hidden at zero, "9+" beyond nine).
2. Tapping the bell opens **Varsler**: the account's notifications, newest
   first, each with a title, a body snippet and a read/unread marker.
3. Notifications are created **server-side by triggers** for, at least:
   a competition **invitation** to me, a **chat message** in a competition
   I am a member of (not my own), and a **reply in a forum thread I
   started or have posted in** (not my own).
4. Tapping a notification **navigates directly** to its target — the
   competitions hub (invitation), the competition chat, or the forum
   thread — and marks it read; a "marker alle som lest" action clears the
   badge.
5. Read state lives **on the account** (cross-device), enforced by RLS:
   a user sees and updates only their own notifications.
6. The badge and list update **live** (Supabase realtime), and the reads
   are background-tolerant: offline or signed out, the app simply shows no
   notifications — never an error screen.
7. The same table is the event source spec 0060's push function reads, so
   enabling OS push later adds delivery, not a second pipeline.

## Rationale

Server-side fan-out (a `notifications` row per recipient, written by
database triggers) gives durable, cross-device read state and one pipeline
for both in-app and OS delivery — the client-derived alternative (local
"last seen" timestamps) was rejected by the owner because read state would
not follow the account and push would need a rebuild anyway.

## Design

- Migration `notifications`: `id uuid pk`, `user_id` (recipient),
  `kind` (`invitation` | `competition_message` | `forum_reply`),
  `title text`, `body text`, `competition_id uuid null`,
  `thread_id uuid null`, `created_at timestamptz`, `read_at timestamptz
  null`. RLS: select/update (read-marking) only where `user_id = auth.uid()`;
  inserts happen in trigger functions (`security definer`). Realtime on.
- Triggers: on `competition_invitations` insert → notify the invitee; on
  `competition_messages` insert → notify every member except the sender;
  on forum reply insert → notify the thread's earlier participants except
  the author.
- App: `NotificationsRepository` (list / markRead / markAllRead + realtime
  stream), `notificationsProvider` + unread-count provider;
  `NotificationsScreen` with the list; bell + badge on
  `ProgramPickerScreen`; deep navigation by `kind` + ids.

## Verification

### Unit tests
- Repository fake: list newest first; markRead/markAllRead update state.

### System tests
- The bell shows the unread count and opens Varsler; tapping an
  invitation-varsel opens the competitions hub, a chat-varsel the
  competition chat, a forum-varsel the thread — and each marks it read
  (badge decrements). "Marker alle som lest" zeroes the badge. Signed
  out / failed read → no bell badge and an empty, calm list.

## Open questions
- Whether reactions (spec 0055) should notify too — later increment.
