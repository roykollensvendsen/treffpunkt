# Spec 0066 — Thread status (done / rejected …)

- **Status:** Accepted
- **Related:** spec 0054 (forum), spec 0063 (moderation is delete-only on others').

## Context
The forum is where bugs and ideas are reported, but a thread has no **state** —
you can't tell an open bug from a fixed one or a rejected idea. We add a small
**lifecycle status** a moderator can set, shown as a badge.

## Requirements
1. A thread has a status: **Åpen** (default), **Planlagt**, **Ferdig** or
   **Avvist**.
2. Only a **moderator** (app admin) can change it — consistent with moderation
   being a triage tool; a moderator changes status and deletes, but does not edit
   others' content (spec 0063).
3. A non-open status shows as a small coloured **badge** on the thread (in the
   list and on the thread screen). Changes are **live**.

## Rationale
**A status column plus an admin-only RPC.** `forum_threads.status` (a checked
text enum, default `open`). A moderator sets it through a SECURITY DEFINER
`set_thread_status(thread_id, status)` that verifies `is_app_admin` and updates
**only** the status column — so the existing author-only UPDATE policy (spec
0063) is untouched and a moderator still can't rewrite someone's text.

**Mirror the category enum.** `ForumThreadStatus(wire, label)` with a safe
`fromWire` default, exactly like `ForumCategory`, so an added status never
crashes an older client. The status rides along on `ForumThread` (in `==`, so a
status change re-renders) with no extra read.

## Design
- Migration: `forum_threads.status` + `set_thread_status` RPC (admin-only).
- `ForumThreadStatus` enum; `status` on `ForumThread`.
- `ForumRepository.setThreadStatus(id, status)` (Supabase RPC; fake admin-gated).
- UI: a `_ThreadStatusBadge` on the list card and the opening post; a moderator's
  flag menu in the thread app bar to pick the status.

## Verification
### Unit tests (in-memory repository)
- A moderator sets the status (rides along on `watchThreads`); a non-admin's call
  is a no-op.

### Widget tests
- A moderator sees the status menu; choosing **Ferdig** shows the badge. A
  non-moderator sees no status menu.

## Open questions
- Filtering the list by status (e.g. hide done/rejected).
- Letting the author mark their own thread done.
