# Spec 0063 — Edit your own forum messages

- **Status:** Accepted
- **Related:** spec 0054 (forum), spec 0055/0056 (reactions, images).

## Context
You can delete your own forum thread or reply (and a moderator can delete
anyone's), but you cannot **fix a typo** — forum posts are currently immutable.
We let the **author edit** their own thread (title + body) and their own reply.

## Requirements
1. The **author** can edit their own thread's **title and body**, and their own
   reply's **body**. Editing is **author-only** — a moderator can delete others'
   messages (spec 0054) but does not edit them.
2. The edit is reachable from the message: an **edit** action on your own thread
   (in its top bar) and a **Rediger** option on your own reply (its long-press
   menu, alongside **Slett**).
3. An empty title (thread) or empty body with no image is not a valid edit.
4. Edits update **live** for everyone, like posting does.

## Rationale
**Add an UPDATE policy, author-only.** The forum tables ship with no UPDATE
policy (immutable). We add one on `forum_threads` and `forum_posts` that lets a
row's author update it (`author_id = auth.uid()`, with the same `with check` so
the author cannot be reassigned). Admins are intentionally not granted edit — the
moderation surface stays delete-only.

**Reuse the repository seam.** `ForumRepository` gains `editThread(id, title,
body)` and `editPost(id, body)`; the Supabase impl is a single `update().eq(id)`
(RLS enforces authorship); the in-memory fake mirrors the rule (only the author's
edit takes effect). Reads already stream live, so an edit re-emits with no extra
wiring.

## Design
- Migration `forum_edit` — UPDATE policies on both tables.
- `ForumRepository.editThread` / `editPost`; fake + Supabase.
- UI: an edit icon on your own thread's app bar opens a title+body dialog; your
  own reply's long-press menu offers **Rediger** (a body dialog) and **Slett**.

## Verification
### Unit tests (in-memory repository)
- The author edits their thread title/body and their reply body; a non-author's
  edit is a no-op.

### Widget tests
- Editing your own reply through the menu shows the new text.
- Others' replies offer no edit affordance.

## Open questions
- Showing an "(endret)" marker and an edit timestamp.
- An edit history / who-edited audit for moderators.
