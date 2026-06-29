# Spec 0059 — See who reacted

- **Status:** Accepted
- **Related:** spec 0052 (chat reactions), spec 0055 (forum reactions).

## Context
A reaction chip shows an **emoji and a count** but not **who** reacted. In a
small competition or forum thread, knowing who gave the 👍 is half the point. We
let a viewer **hold (long-press) a reaction chip** to see the names of everyone
who reacted with that emoji — in both the competition chat and the forum.

## Requirements
1. Holding a reaction chip opens a sheet listing the **display names** of the
   users who reacted with that emoji, with a header of the emoji and the count.
2. Works the same way on a competition chat message, a forum thread's opening
   post, and a forum reply.
3. A reactor with no known display name is shown with a neutral fallback
   ("Ukjent skytter" in chat, "Ukjent" in the forum), never a blank row.

## Rationale
**Names ride along with the reaction, like author names already do.** The
repositories already attach a profile/display name to messages, threads and
replies; we extend the same pattern to each reaction. `MessageReaction` and
`ForumReaction` gain an optional `userName`, attached by the repository from the
existing `profiles` table — so **no migration** is needed. `userName` is
**excluded from equality** (it is display metadata): toggling still matches on
`(messageId, userId, emoji)` / `(userId, emoji)`, and a name-only change never
spuriously rebuilds.

**A shared sheet, reused by both surfaces.** A single
`showReactors(context, emoji, names)` (in `lib/core/presentation/`) renders the
bottom sheet, so the chat and the forum present the reactor list identically.

## Design
- `MessageReaction.userName` + `withUserName(...)`; `ForumReaction.userName` +
  `withUserName(...)` — both excluded from `==`/`hashCode`.
- Repositories attach the name: the in-memory fakes from their profile/name
  maps; the Supabase repositories with one extra `profiles` lookup keyed by the
  reactors' user ids (`_displayNamesFor` / `_namesFor`).
- `showReactors(...)` in `lib/core/presentation/reactors_sheet.dart` (keyed
  `reactorsSheetKey` for tests).
- UI: the chat `_ReactionChip` and the forum reaction chip gain an
  `onLongPress` that calls `showReactors` with the names for that emoji.

## Verification
### Unit tests (in-memory repositories)
- A chat reaction carries the reactor's display name (two users react → each
  reaction's `userName` matches their profile).
- A forum reaction carries the reactor's display name.

### System tests
- Holding a chat reaction chip opens the reactors sheet showing the reactor's
  name.
- Holding a forum reaction chip opens the reactors sheet showing the reactor's
  name.

## Open questions
- Showing the reactor avatars (not just names) once profiles carry a picture.
