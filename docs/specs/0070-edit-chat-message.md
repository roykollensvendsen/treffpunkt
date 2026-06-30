# Spec 0070 — Edit your own chat message

- **Status:** Accepted.
- **Related:** 0051 (competition chat), 0063 (edit forum messages — the pattern
  this mirrors), 0069 (copy message text — same long-press menu).

## Context
You can copy or delete your own competition-chat message, but you cannot fix a
typo — the chat shipped deliberately immutable (no UPDATE policy). The forum
already lets an author edit their own thread/reply (spec 0063); chat should work
the same way.

## Requirements
1. Long-pressing **your own** message offers **Rediger**, alongside Kopier tekst
   (spec 0069) and Slett (spec 0051).
2. Choosing it opens an editor pre-filled with the message text; **Lagre** saves
   the new text, which appears live for everyone. **Avbryt** discards.
3. Only the **author** may edit — not the competition owner. (Unlike delete,
   moderation stays delete-only; only the author rewrites their own words.)
4. The edit changes only the **text**; the post time, author, image and
   reactions are untouched. Clearing the text is allowed only when the message
   still has an image.

## Rationale
**Mirror the forum (spec 0063).** Same author-only UPDATE policy, same edit
dialog shape, same "body only, created_at preserved" rule — no `edited_at`
column, matching the forum's deliberate simplicity. Reusing the pattern keeps
chat and forum consistent and the change small.

**Author-only, owner excluded.** The competition owner can already *delete* any
message for moderation (spec 0051); editing someone else's words is different —
it would put words in their mouth — so edit is restricted to the author both in
the UI (`Rediger` shows only on your own bubble) and in Row-Level Security (the
`using`/`with check` pin `user_id = auth.uid()`).

**Realtime needs no change.** The chat subscription already listens for
`PostgresChangeEvent.all`, so an UPDATE re-emits the chat the same way an
INSERT/DELETE does.

## Design
- `competition_repository.dart`: add
  `editMessage(String messageId, {required String body})` to the interface; the
  in-memory repo replaces the body author-only (a non-author update is a no-op),
  preserving `createdAt`/`imagePath`.
- `supabase_competition_repository.dart`: `update({'body': body}).eq('id', …)` —
  RLS limits it to the author's own row.
- `supabase/migrations/20260630230000_competition_message_edit.sql`: an
  author-only UPDATE policy on `competition_messages` (`using`/`with check` =
  `auth.uid() = user_id`). **Requires applying to the hosted database.**
- `competition_chat_screen.dart`: the message action sheet gains **Rediger**
  (`chatEditKey`) on your own message; `_EditMessageDialog` (`chatEditBodyFieldKey`
  / `chatEditSaveKey`) collects the new text; `_editMessage` calls the repo and
  surfaces a failure snackbar.

## Verification
- **Repository:** the author edits their own message (the body changes); a
  non-author edit (incl. the owner) is a no-op (spec 0070 test).
- **Widget:** long-press your own message → Rediger → type → Lagre shows the new
  text and drops the old; another shooter's message offers Slett (you own the
  competition) but **no** Rediger.
- **RLS (manual, against the hosted DB):** the author's update succeeds; another
  participant's update of the same row affects no row.

## Out of scope
- An "(redigert)" marker / edit history (the forum has none either).
- Editing the attached image (only the text body changes).
