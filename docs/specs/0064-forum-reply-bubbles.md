# Spec 0064 — Chat-style reply bubbles in the forum

- **Status:** Accepted
- **Related:** spec 0054 (forum), spec 0051 (chat bubbles it mirrors).

## Context
Forum replies render as a flat, left-aligned list, so it is hard to see at a
glance which replies are **yours**. The competition chat already solves this:
your messages sit on the **right** in an accent bubble, others' on the **left**.
We bring the same treatment to forum replies.

## Requirements
1. A reply **you** wrote is **right-aligned** in an accent-coloured bubble; a
   reply by someone else is **left-aligned** in a neutral bubble — matching the
   chat.
2. Others' bubbles show the **author name**; your own omit it (it is you).
3. The existing reply behaviour is unchanged: long-press for **Rediger/Slett**
   (your own) or **Slett** (a moderator), the reaction bar, and images.
4. The opening post stays the full-width **topic card** at the top (it is the
   thread subject, not a chat turn).

## Rationale
**Reuse the chat bubble shape.** `_ReplyTile` wraps its content in an `Align`
(right for `mine`, else left) and a rounded `Container` coloured
`primaryContainer` (mine) or `surfaceContainerHighest` (others), constrained to a
readable max width — the same recipe as the chat `_MessageBubble`. The reaction
bar stays just below the bubble. No data or repository change.

## Verification
### Widget tests
- Your own reply is right-aligned; another shooter's is left-aligned.
- Editing/deleting and reactions still work on the restyled tile.

## Open questions
- Showing small avatars beside others' bubbles once profiles carry pictures.
