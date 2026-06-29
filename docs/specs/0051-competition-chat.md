# Spec 0051 — Competition chat

- **Status:** Accepted
- **Related:** spec 0010 (competitions + RLS), spec 0013 (Realtime scoreboard),
  ADR-0017 (manual migrations). First increment of the chat/forum work
  (pappa's "forum" wish); reactions, images and the bug/idea forum follow.

## Context
The people in a competition have no way to talk in the app — to agree a time,
compare notes, or congratulate each other. We want a **chat per competition**:
a shared back-channel for everyone in that competition, updating live.

This is the first slice of a bigger messaging feature (a community forum for bug
reports and feature ideas comes later); it deliberately reuses the Realtime
pattern already proven by the live scoreboard (spec 0013).

## Requirements
1. Each competition has a **chat**. Anyone who can read the competition can read
   its chat; only a **participant** (owner or member) may post.
2. A posted message appears for everyone in the chat **live**, without
   reopening (Supabase Realtime), oldest message first, with the author's name.
3. A user can **delete their own** message; the **competition owner** can delete
   **any** message in their competition (moderation). No editing.
4. The chat is reachable from the competition detail screen.
5. Posting an empty message is a no-op; a failed post surfaces a notice and does
   not lose the typed text silently.

## Rationale
**Mirror the scoreboard.** The live scoreboard (spec 0013) already streams a
table's changes through Supabase Realtime, gated by the same Row-Level Security
that protects reads. The chat is the same shape — a `competition_messages` table
on the `supabase_realtime` publication, read through `watchMessages` exactly as
results are read through `watchResults` — so there is little new machinery and
the security story is identical (a non-reader never receives a row).

**Reuse the competition repository + its test harness.** Chat lives on
`CompetitionRepository`, so it reuses the in-memory fake's shared store and
`asUser()` view — which makes a two-person chat trivial to unit-test against one
backend. The Supabase implementation attaches author profiles separately (no FK
to embed), like `resultsOf`/`membersOf`.

**Owner moderation, not a global admin yet.** The competition owner is the
natural moderator of their own competition's chat (`is_competition_owner`), so
no new admin role is needed for this increment. (A site-wide admin role arrives
with the community forum, where pappa asked for owner moderation across threads.)

## Design
### Data — `competition_messages` (new migration)
```
competition_messages(
  id uuid primary key,                       -- client-minted (plain insert)
  competition_id uuid -> competitions(id) on delete cascade,
  user_id uuid default auth.uid() -> auth.users(id) on delete cascade,
  body text not null,
  created_at timestamptz default now()
)
```
RLS (reusing the SECURITY DEFINER helpers from the competitions migration):
read `can_read_competition`; insert `auth.uid() = user_id AND
is_competition_participant`; delete `auth.uid() = user_id OR
is_competition_owner`. No update policy (messages are immutable). The table is
added to the `supabase_realtime` publication.

### Repository (`CompetitionRepository`)
- `postMessage(CompetitionMessage)` — insert (participant-only, RLS-enforced).
- `watchMessages(competitionId)` — a stream that emits the chat oldest-first and
  re-emits on any insert/delete (Realtime), authors' profiles attached.
- `deleteMessage(messageId)` — author or owner (RLS); anyone else is a no-op.

### Presentation
- `competitionChatProvider` (`StreamProvider.family`) over `watchMessages`.
- `CompetitionChatScreen`: a message list (own messages right-aligned, others
  left with the author's name) and a composer (text field + send). Long-press a
  message you may delete to remove it. Reached from a **Chat** button on the
  competition detail.

## Verification
### Unit tests (in-memory repository)
- Two participants post; both read the chat oldest-first, with author profiles
  attached.
- A non-participant cannot post (throws).
- The author deletes their own message; the owner deletes another's (moderation);
  a third party's delete is a silent no-op.
- `watchMessages` re-emits when a message is posted.

### System tests
- Sending a message shows it in the chat (and clears the empty state).
- An incoming message from another shooter appears with their name.
- Deleting your own message removes it.
- The competition detail's **Chat** button opens the chat screen.

## Open questions
- Reactions (emoji) and image attachments are the next increments; the message
  row gains an attachment reference and a reactions table then.
- Pagination: the chat reads the whole history for now; add windowing if a
  competition's chat grows large.
