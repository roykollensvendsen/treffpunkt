<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0033 — Delete a session

- **Status:** Accepted
- **Related:** spec 0024 (personal session sync), spec 0025 (upload queue),
  spec 0026 (My sessions list), spec 0029 (sync-failure notice), ADR-0017

## Context

A shooter can record and sync sessions but has no way to remove one — a mistaken
or test session stays on the list forever. A session shown in **"Mine økter"**
lives in up to two places: the durable upload queue (`PendingUploadsStore`,
surfaced live by `uploadQueueProvider`) and the cloud `sessions` table.
`MySessionEntry.synced` says which. Deleting must remove it from wherever it
lives. The `sessions` table already has an owner-only delete policy and grant
(`20260623120000_sessions.sql`), so no migration is needed.

## Requirements

1. **Delete from the list.** Each session card has a **Slett** action.
2. **Confirm first.** Deletion is irreversible, so it asks for confirmation
   ("Slett økt? Kan ikke angres.") before doing anything.
3. **Remove everywhere.** A synced session is deleted from the account; a session
   still in the queue is removed from the queue and its durable store. A session
   that is both is removed from both.
4. **Works offline for local sessions.** A pending (not-yet-synced) session
   deletes with no network. A synced delete that fails (offline) leaves the
   session in place and shows a non-blocking message.
5. **The list updates.** After a successful delete the card disappears.

## Design

- **Repository.** Add `deleteById(String id)` to `SessionRepository`
  (`lib/features/scoring/data/session_repository.dart`):
  `InMemorySessionRepository` removes the id from `_byId`;
  `SupabaseSessionRepository` runs `from('sessions').delete().eq('id', id)` and —
  unlike the silent best-effort `upload` — **throws** `SessionSyncException` on
  failure, because the user is waiting on a deliberate action.
- **Queue.** Add `deleteById(String id)` to `UploadQueueNotifier`
  (`upload_queue.dart`), run on the existing serial `_run` chain: drop the id from
  `state` and `_persist(state)` (which rewrites the durable store), so no new
  `PendingUploadsStore` method is needed and it never races a flush.
- **UI.** In `my_sessions_screen.dart`, `_SessionCard` becomes a `ConsumerWidget`
  with a trailing overflow menu (**Slett**). On confirm: delete from the cloud
  when `entry.synced`, then from the queue, then invalidate
  `syncedSessionsProvider` + `storedPendingProvider`. A failure shows a snackbar.

## Rationale

Routing the queue removal through the notifier's serial chain reuses the
guarantee that no operation interleaves a flush (spec 0025), so a delete can never
race an in-flight upload. Skipping the cloud call for a pending-only session keeps
the offline-first promise (ADR-0013): a local session is deletable with no
network. The cloud delete throws (the read already does, spec 0029) so a failed
delete is visible rather than silently leaving the row to reappear.

## Verification

### Unit (`upload_queue_test.dart`)
- *the queue drops a deleted id and re-persists the remainder* — enqueue two,
  `deleteById` one, the state and the persisted store hold only the other.

### Widget (`my_sessions_screen_test.dart`)
- *deleting a pending session removes its card with no cloud call* — Slett →
  confirm; the card is gone and the (offline) repository was never asked to
  delete.
- *deleting a synced session calls the cloud delete and the row disappears* —
  Slett → confirm; the repository deleted the id and, on the synced re-read, the
  card is gone.
- *cancelling the confirmation keeps the session.*

### Manual (local Supabase, delete policy already in place)
Delete a synced session in the real app and confirm it does not return on the
next "Mine økter" open (the cloud row is gone, owner-only RLS).

## Known limitations / next increment

No multi-select or undo; deletion is one card at a time. The in-progress
("Fortsett økt") recording is discarded separately and is not part of this list.
