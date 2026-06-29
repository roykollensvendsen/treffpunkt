# Spec 0054 — Community forum (bugs & ideas)

- **Status:** Accepted
- **Related:** spec 0051–0053 (competition chat, the messaging pattern this
  reuses), spec 0010 (RLS helpers), ADR-0017 (manual migrations). Pappa's
  original "forum" wish.

## Context
We want a shared place in the app to **report bugs, suggest features and discuss
ideas** — a community forum, not tied to a single competition. Any signed-in
user can start a thread, reply, and read everything; a maintainer can moderate.

## Requirements
1. Any signed-in user can read the forum, **start a thread** (with a category —
   **Bug / Ønske / Generelt** — a title and an opening message), and **reply**
   to a thread.
2. Threads list **newest first**, are **filterable by category**, and show the
   author's name; replies show oldest first with their author.
3. Threads and replies update **live** (Realtime).
4. A user can delete their **own** thread or reply. A **moderator** (an
   `app_admins` member) can delete **anyone's** (the maintainer is seeded as the
   first admin). No editing.
5. The forum is reachable from the program picker.

## Rationale
**The chat pattern, app-wide.** The forum is the competition chat without the
competition scope: tables on the Realtime publication, read through streams,
profiles attached on read. Because everyone may read, the RLS is simpler than
chat — `select` is `true` for authenticated; `insert` is author-only; `delete`
is author-or-admin.

**A tiny admin table + helper, seeded by email.** Moderation needs a notion of
"maintainer". `app_admins(user_id)` holds them; a SECURITY DEFINER
`is_app_admin` helper gates the delete policies without recursion. The first
admin is seeded in the migration by email lookup against `auth.users`, so it
works the moment it is applied; more are added with an `insert`.

**A separate `ForumRepository`.** The forum is its own feature
(`lib/features/forum/`), not bolted onto competitions, with its own in-memory
fake + `asUser()` harness for multi-user tests.

## Design
- Migration `forum`: `app_admins` (+ `is_app_admin`, seeded by maintainer
  email); `forum_threads(id, author_id, category check in (bug|idea|general),
  title, body, created_at)`; `forum_posts(id, thread_id, author_id, body,
  created_at)`; RLS (read = any authenticated, insert = author, delete =
  author-or-admin); both content tables on `supabase_realtime`.
- Domain `ForumCategory` (bug/idea/general with Norwegian labels), `ForumThread`,
  `ForumPost` (author name attached on read).
- `ForumRepository`: `watchThreads`, `createThread`, `deleteThread`,
  `watchPosts`, `postReply`, `deletePost`, `isAdmin`.
- Providers: `forumRepositoryProvider` (Supabase in `main()`),
  `forumThreadsProvider`, `forumPostsProvider(threadId)`, `forumIsAdminProvider`,
  `forumCurrentUserIdProvider`.
- UI: `ForumScreen` (filter chips + thread list + "Ny tråd" FAB),
  `NewThreadScreen` (title + category + body), `ForumThreadScreen` (opening post,
  replies, composer; delete-thread for author/admin, long-press a reply to
  delete). A Forum action in the program picker app bar.

## Verification
### Unit tests (in-memory repository)
- Threads list newest-first with author names; replies stream oldest-first with
  names; the author deletes own, an admin moderates anyone's, others cannot;
  `isAdmin` reflects the admin set.

### System tests
- The empty state; creating a thread shows it in the list; opening a thread
  shows its body and a posted reply appears; only the author or an admin sees
  the delete-thread action (and an admin's delete removes it). The picker opens
  the forum.

## Open questions
- **Emoji reactions and image attachments on forum posts** are the next
  increment, reusing the chat reaction/image infrastructure (spec 0052/0053).
- Per-thread reply counts, sorting, and pagination can follow.
