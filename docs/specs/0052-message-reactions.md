# Spec 0052 — Emoji reactions on chat messages

- **Status:** Accepted
- **Related:** spec 0051 (competition chat). Second chat increment; image
  attachments (0053) and the forum follow.

## Context
A chat is friendlier when you can react quickly without writing a reply. We add
**emoji reactions** to competition chat messages: tap an emoji to react, tap
again to take it back, and see everyone's reactions live.

## Requirements
1. A participant can react to **another shooter's** chat message with an emoji
   from a small palette, and **toggle** it off by reacting with the same emoji
   again. You cannot react to **your own** message (no add-reaction affordance,
   and existing chips on your own message are display-only).
2. A message shows its reactions as **emoji + count** chips; a chip the viewer
   contributed is highlighted. Tapping a chip toggles the viewer's reaction.
3. Reactions update **live** for everyone (Realtime), like the messages.
4. Only a **participant** may react (same boundary as posting). Reactions a user
   cannot read are never delivered (Row-Level Security).

## Rationale
**A `(message, user, emoji)` table, toggled client-side.** One row per distinct
reaction keyed by `(message_id, user_id, emoji)` makes "react / un-react" a
delete-or-insert and naturally caps a user to one of each emoji per message. RLS
resolves a reaction to its competition through a SECURITY DEFINER
`competition_of_message` helper (so a reaction policy never re-enters the
messages/competitions policies), then reuses `can_read_competition` /
`is_competition_participant`.

**Reactions ride along with the message.** `watchMessages` attaches each
message's reactions, and the chat stream re-emits on any reaction change (a
second Realtime subscription on the reactions table). `CompetitionMessage` gains
a `reactions` list with **deep equality**, so a reaction-only change makes the
message compare unequal and the chat rebuilds.

## Design
- Migration `competition_message_reactions(message_id, user_id, emoji,
  created_at, pk(message_id,user_id,emoji))` + the `competition_of_message`
  helper; RLS read/insert/delete as above; added to `supabase_realtime`.
- `MessageReaction(messageId, userId, emoji)`; `CompetitionMessage.reactions`.
- Repository `toggleReaction(messageId, emoji)` (delete-or-insert);
  `watchMessages` attaches reactions and re-emits on reaction changes.
- UI: under each bubble, reaction chips (emoji + count, highlighted when mine)
  and an **add-reaction** button opening a fixed emoji palette
  (`chatReactionPalette`).

## Verification
### Unit tests (in-memory repository)
- Two participants react with the same emoji → two reactions on the message;
  one toggles theirs off → the other's remains; reactions are returned with the
  message.
- A non-participant cannot react (throws).

### System tests
- Opening the palette and picking an emoji adds a reaction chip ("👍 1");
  tapping the chip again removes it.

## Open questions
- The palette is a fixed set for now; a full emoji keyboard could come later.
