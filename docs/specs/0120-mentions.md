# Spec 0120 — @-tagging i meldinger (mentions)

- **Status:** Accepted
- **Related:** forum thread «La oss tagge brukere og Robot Hood i
  meldinger. Robot Hood kun i tråder» (planned by the owner; design
  confirmed on the thread); specs 0063 (forum), 0061 (competition
  chat), 0094 (notification center), 0112/0119 (Robot Hood)

## Context

There is no way to direct a message at someone. The owners asked to
tag users in all messages — forum posts and competition chat — and to
tag **Robot Hood** in forum threads only («i konkurranser vil vi ikke
tagge deg»). A tagged user should be notified; a tagged Robot Hood
should read the thread and answer there.

## Rationale

- **Wire format `@[Navn]`**: display names contain spaces, so the
  picker inserts a bracket-delimited marker. Old clients show the raw
  `@[Navn]` — readable, never broken. The name (not the id) is the
  token, so the body stays human-readable everywhere (exports, SQL,
  push payloads); the server resolves names to accounts at insert
  time, matching case-insensitively against `profiles.display_name`.
- **Server-side fan-out**: notifications are already written by
  SECURITY DEFINER triggers (spec 0094) — mentions reuse that pipeline
  with a new `mention` kind. The existing reply/message fan-outs
  exclude mentioned users so nobody is notified twice for one message;
  the mention row (which names you) wins. Unknown kinds already fall
  back gracefully in deployed clients.
- **Composer**: typing `@` at the start of a word opens a name picker
  (a bottom sheet — robust across platforms); picking inserts the
  marker. Candidates are the people in the room: thread participants
  (plus **Robot Hood**) in the forum, members and owner (minus
  yourself, no Robot Hood) in a competition chat.
- **Robot Hood summon**: a forum post tagging `@[Robot Hood]` is an
  instruction to the automation: read the thread and answer there.
  This extends the approved robot post kinds with **answers when
  summoned**. The robot is not a row in `profiles`, so no notification
  fan-out happens — the owner's session watch picks the post up.

## Requirements

1. Message bodies render `@[Navn]` as a highlighted `@Navn`; the raw
   marker is never shown in the app.
2. Typing `@` (start of word) in the forum reply, the new-thread body
   or the competition chat composer opens a picker; picking a name
   inserts `@[Navn] `. Forum pickers list thread participants and
   Robot Hood; competition pickers list members/owner except yourself,
   without Robot Hood.
3. A mentioned user gets one `mention` notification (title names the
   sender and where; body is the message excerpt) that navigates to
   the thread or chat; they are excluded from the generic reply/
   message fan-out for that message. Mentioning yourself notifies
   nobody.
4. `@[Robot Hood]` in a forum post or thread body summons the robot:
   it reads the thread and answers there (`Robot: `-prefixed, spec
   0112/0119). No account is notified.

## Verification

- Unit: the span renderer turns `@[Navn]` into a highlighted `@Navn`
  and leaves plain text alone; `AppNotification.fromJson` reads the
  `mention` kind.
- Widget: typing `@` in the forum reply shows the picker with the
  participants and Robot Hood; picking inserts the marker; the sent
  body renders highlighted. The competition picker offers members but
  never Robot Hood.
- Migration applied to hosted; a test insert with a mention produces
  exactly one mention row for the named user and no duplicate
  reply-fanout row.
