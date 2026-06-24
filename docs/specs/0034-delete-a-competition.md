<!--
SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen

SPDX-License-Identifier: GPL-3.0-or-later
-->

# Spec 0034 — Delete a competition (owner only)

- **Status:** Accepted
- **Related:** spec 0010 (competitions data & RLS), spec 0011 (create / invite /
  join), spec 0013 (scoreboard), ADR-0019

## Context

An owner can create a competition but cannot remove one — a test or mistaken
competition lingers on every participant's hub. The backend already supports the
delete safely: `competitions` has the policy "Competitions are deletable by their
owner", and `competition_members`, `competition_invitations` and
`competition_results` all reference the competition `on delete cascade`. So
deleting the one row removes the members, invitations and results with it. **No
migration is needed.**

## Requirements

1. **Owner-only.** Only the competition's owner sees a **Slett konkurranse**
   action; a non-owner never does (and the RLS rejects it regardless).
2. **Confirm first.** Deletion is irreversible and removes everyone's results, so
   it asks for confirmation that names what is lost.
3. **Cascade.** Deleting the competition removes its members, invitations and
   results (the database cascade does this).
4. **Return to the hub.** After a successful delete the detail screen pops back
   to the hub and the deleted competition is gone from the list.
5. **Failure is visible.** A failed delete keeps the screen and shows a message.

## Design

- **Repository.** Add `deleteCompetition(String competitionId)` to
  `CompetitionRepository`: `InMemoryCompetitionRepository` mirrors the cascade —
  remove from `_competitions`, `_members`, `_results` and `removeWhere` on
  `_invitations`; `SupabaseCompetitionRepository` runs
  `from('competitions').delete().eq('id', id)` in the standard try/catch →
  `CompetitionSyncException`.
- **UI.** In `CompetitionDetailScreen`'s existing `if (isOwner) …` block
  (`competitions_screen.dart`), add a destructive **Slett konkurranse** button. On
  confirm via an `AlertDialog`: `deleteCompetition(id)` →
  `ref.invalidate(myCompetitionsProvider)` → `Navigator.pop()`; a failure shows a
  snackbar and stays.

## Rationale

The delete is a thin call over the existing owner-delete policy and the schema
cascade (ADR-0019), so no new server surface is introduced and a non-owner cannot
delete even if the button were forced. Owner-gating the control matches how the
invite controls are already gated (`isOwner = uid == competition.ownerId`), and
the confirmation that spells out the lost results respects that the action is
irreversible.

## Verification

### Unit (`competition_repository_test.dart`)
- *deleteCompetition removes the competition and its members, invitations and
  results* — seed a competition with a member, an invitation and a result; after
  delete, `listMine`, `membersOf`, `resultsOf` are empty and the invitee's
  `listMyInvitations` is empty.

### Widget (`competitions_screen_test.dart`)
- *the owner deletes their competition and returns to the hub* — from the detail
  screen, Slett → confirm pops back and `competitionCard(id)` is gone.
- *a non-owner sees no delete button* (extends the existing non-owner test).
- *cancelling the confirmation keeps the competition.*

### Manual (local Supabase, delete policy + cascade already in place)
As the owner, delete a competition with results and confirm the row and its
results/members/invitations are gone; a non-owner has no button and the RLS
rejects a forced delete.

## Known limitations / next increment

No "leave a competition" for a non-owner member yet (the
`competition_members` self-delete policy exists; the UI is a later increment). No
soft-delete or undo.
