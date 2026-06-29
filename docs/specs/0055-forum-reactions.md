# Spec 0055 — Emoji reactions in the forum

- **Status:** Accepted
- **Related:** spec 0054 (forum), spec 0052 (chat reactions — same shape).

## Context
Reacting with an emoji is the natural way to **vote on a bug or feature idea**
without writing a reply. We add emoji reactions to forum **threads** (the
opening bug/idea) and **replies**, updating live.

## Requirements
1. Any signed-in user can react to a thread or a reply with an emoji from a
   palette, and **toggle** it off by reacting again with the same emoji.
2. A thread/reply shows its reactions as **emoji + count** chips; the viewer's
   own are highlighted; tapping a chip toggles.
3. Reactions update **live** (Realtime).

## Rationale
**One polymorphic table for both targets.** `forum_reactions(target_type,
target_id, user_id, emoji)` covers threads and replies in a single table and one
set of policies. Because the forum is readable by every signed-in user, RLS is
trivial — read = authenticated, insert/delete = your own row — with no helper.
`target_id` is polymorphic (no FK), so a deleted thread/reply may leave orphan
reactions: harmless and sweepable later.

**Reactions ride along with their target.** `watchThreads`/`watchPosts` attach
each item's reactions and re-emit on any reaction change (a second Realtime
subscription on `forum_reactions`). `ForumThread`/`ForumPost` gain a `reactions`
list with deep equality, so a reaction-only change rebuilds the view. The thread
screen reads the **live** thread from `forumThreadsProvider` (not the static one
it navigated with) so the opening post's reactions update too.

## Design
- Migration `forum_reactions` (+ index, RLS, Realtime).
- `ForumReaction(userId, emoji)`; `reactions` on `ForumThread`/`ForumPost`.
- `ForumRepository.toggleReaction(targetType, targetId, emoji)` (delete-or-
  insert); reads attach reactions; the Supabase `_live` helper now watches
  several tables so the thread/reply streams also re-read on reaction changes.
- UI: a `_ForumReactionBar` (chips + add-reaction palette) under the opening post
  and each reply, reusing the chat reaction look.

## Verification
### Unit tests (in-memory repository)
- Two users react to a thread with the same emoji → two reactions; one toggles
  off → the other remains. A reaction on a reply rides along on `watchPosts`.

### System tests
- Opening a thread, adding a 👍 to the opening post shows a "👍 1" chip; tapping
  it again removes it.

## Open questions
- Reaction counts on the thread **list** cards (for at-a-glance voting) and image
  attachments on forum posts are the next steps.
