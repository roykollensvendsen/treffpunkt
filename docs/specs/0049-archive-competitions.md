# Spec 0049 — Archive old competitions

- **Status:** Accepted
- **Related:** spec 0010 (competitions + RLS), spec 0011 (list/detail), spec
  0034 (owner delete), ADR-0017 (manual migrations)

## Context
A shooter's competition list grows over time and old, finished competitions
clutter it. Deleting is not always an option: you can only delete a competition
you **own** (spec 0034), so a competition created by *someone else* that you
joined stays in your list forever with no way to tidy it away.

We want each user to be able to **archive** any competition in their list —
owned or joined — so it moves out of the active view, while staying intact for
everyone else and remaining restorable. Archiving is the answer for the
competitions you cannot delete because they are not yours.

## Requirements
1. A signed-in user can **archive** any competition that appears in their list
   (one they own *or* one they joined), and **restore** (un-archive) it later.
2. Archiving is **per user**: it only hides the competition from *that* user's
   active list. It never deletes the competition and never affects what any
   other participant (including the owner) sees.
3. A non-owner can archive a competition they joined even though they cannot
   delete it.
4. The competition list shows **active** competitions by default; archived ones
   move to a separate, secondary **"Arkiverte"** section (shown only when the
   user has archived at least one).
5. Archiving and restoring are reachable from the list (a per-card action) and
   from the competition detail screen, and take effect without reopening the
   screen.
6. Archiving a competition does not change its membership, results, scoreboard
   or join link — opening an archived competition still shows everything; only
   its place in *your* list changes.
7. When an owner deletes a competition (spec 0034), every user's archive record
   for it is cleaned up automatically (no orphan rows).

## Rationale
**A per-user archive table, not a column.** Archiving is personal state, so it
cannot live on the shared `competitions` row (that is one row for everyone). It
mirrors the existing `competition_members` shape: a `(competition_id, user_id)`
table, one row per (user, archived competition). Row-Level Security then needs
only the trivial `auth.uid() = user_id` rule — a user reads, sets and clears
**only their own** archive rows — with no SECURITY DEFINER helper and no policy
recursion (the table is never consulted by another table's policy).

**Hide, don't delete.** The request is to tidy the list, not to leave the
competition. The user stays a member and on the scoreboard; archiving is purely
a view filter. (Leaving a competition — deleting your own membership — already
exists at the data layer and is a separate concern.)

**Client-side partition.** `listMine()` already returns every competition the
user owns or joined. Rather than change that query, the screen reads the small
set of archived ids separately and splits the list into active vs archived. This
keeps the existing membership query untouched and the archived ids cheap to
invalidate after an archive/restore.

## Design
### Data — `competition_archives` (new migration)
```
competition_archives(
  competition_id uuid  -> competitions(id) on delete cascade,
  user_id        uuid  default auth.uid() -> auth.users(id) on delete cascade,
  archived_at    timestamptz default now(),
  primary key (competition_id, user_id)
)
```
RLS (`to authenticated`): select/insert/delete all gated on
`auth.uid() = user_id`; the insert check additionally requires
`can_read_competition(competition_id, auth.uid())` (the existing SECURITY
DEFINER helper) so a user can only archive a competition they can actually see.
The `on delete cascade` from `competitions` satisfies requirement 7. Grants:
`select, insert, delete` to `authenticated`; nothing to `anon`.

### Repository (`CompetitionRepository`)
- `Future<Set<String>> archivedCompetitionIds()` — the competition ids the
  caller has archived (their own rows only).
- `Future<void> archiveCompetition(String competitionId)` — idempotent insert of
  the caller's archive row.
- `Future<void> unarchiveCompetition(String competitionId)` — delete the
  caller's archive row.

The in-memory fake stores `Map<userId, Set<competitionId>>` in a holder shared
across `asUser()` views (like `_members`), so a cross-user test can prove one
user archiving does not affect another. The Supabase implementation upserts with
`ignoreDuplicates` (idempotent) and deletes by `competition_id` (RLS scopes it
to the caller's row).

### Presentation
- `archivedCompetitionIdsProvider` (`FutureProvider<Set<String>>`), invalidated
  after archive/restore.
- The list partitions `myCompetitionsProvider` by the archived set: active under
  "Mine konkurranser", archived under an "Arkiverte" header (only when
  non-empty). Each active card carries an **archive** icon
  (`archiveCompetitionKey(id)`); each archived card a **restore** icon
  (`unarchiveCompetitionKey(id)`). Archiving shows a snackbar with **Angre**.
- The detail screen shows an **Arkiver** / **Gjenopprett** button available to
  every viewer (owner and non-owner alike), beside the owner-only delete.

## Verification
### Unit tests
- `archiveCompetition` then `archivedCompetitionIds` returns the id; it is
  idempotent (archiving twice keeps one); `unarchiveCompetition` clears it.
- Archiving is per-user: with a shared store via `asUser()`, one user archiving
  a competition leaves the other user's `archivedCompetitionIds` empty, and both
  still see it in `listMine()` (archive never drops membership).
- A non-owner who joined can archive and restore the competition.
- `archivedCompetitionIdsProvider` reflects the repository.

### System tests
- The screen lists a competition under "Mine konkurranser"; tapping its archive
  icon moves it to the "Arkiverte" section (and out of the active list) without
  reopening; the restore icon moves it back.
- The "Arkiverte" section is absent when nothing is archived.
- A joined (non-owned) competition can be archived from the detail screen.

## Open questions
- A future enhancement could auto-suggest archiving competitions with no recent
  activity, or bulk-archive. Out of scope here.
