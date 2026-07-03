# Spec 0109 — Remove notifications

- **Status:** Accepted
- **Related:** spec 0094 (notification center); user-reported gap

## Context

The notification center could only mark notifications read — never
remove them. The list (and the table behind it) grew without bound, and
the user reported that notifications cannot be removed.

## Rationale

Removal is the recipient's call, so it follows the app's destructive
conventions: swipe a single notification away (the platform gesture for
dismissing exactly one), and a «Fjern alle» action guarded by a
confirmation (spec 0096) for the whole list. The backend needs one new
RLS delete policy scoped to the recipient — the same shape as the
existing read/update policies. The swiped row leaves the visible list
immediately (a `Dismissible` must be gone the frame its swipe ends,
while the provider still holds the previous value during its reload).

## Requirements

1. Swiping a notification (end to start) deletes it — from the list at
   once, from the account behind it.
2. A «Fjern alle» app-bar action (shown when the list is non-empty)
   deletes every notification after a confirmation dialog; cancelling
   deletes nothing.
3. `NotificationsRepository` gains `delete(id)` and `deleteAll()`,
   best-effort like the other mutations.
4. Migration: a delete RLS policy on `public.notifications` scoped to
   `auth.uid() = user_id`, plus the grant. Applied to the hosted
   project.

## Verification

- `notifications_screen_test`: swiping a tile removes it from the list
  and the repository while the rest stay; «Fjern alle» deletes nothing
  until confirmed, then empties the repository and shows the empty
  state.
- Existing bell/badge/navigation tests unchanged.
