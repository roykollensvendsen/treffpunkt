# Spec 0069 — Copy message text

- **Status:** Accepted.
- **Related:** 0051 (competition chat), 0054 (community forum), 0063 (edit
  forum messages), 0064 (reply bubbles) — this extends their long-press menus.

## Context
You can read a chat message or a forum thread/reply, but there is no way to get
the text back out — to quote it elsewhere, paste a result into a calculator, or
forward a phone number. The bodies are plain `Text`, so nothing is selectable.

## Requirements
1. **Chat:** long-pressing a message offers **Kopier tekst** (when the message
   has text), alongside **Slett** where you already could delete it.
2. **Forum reply:** long-pressing a reply offers **Kopier tekst** (when it has
   text), alongside the existing **Rediger** / **Slett**.
3. **Forum thread:** long-pressing the opening post's text offers **Kopier
   tekst**.
4. Copying puts the message body on the clipboard and confirms with a brief
   snackbar (**Tekst kopiert**).

## Rationale
**Extend the long-press menu, don't switch to `SelectableText`.** The bubbles
already own rich long-press gestures (react, who-reacted, edit, delete);
`SelectableText` would fight those gestures and behave differently per platform.
A **Kopier tekst** item in the same `showModalBottomSheet` the app already uses
(forum reply actions, the emoji palette, "who reacted") is consistent,
predictable, and copies the whole message — the common need.

**One shared helper.** `copyMessageText` (in `core/presentation/`) does the
clipboard write and the confirmation snackbar once, so chat and forum behave
identically.

## Design
- `lib/core/presentation/copy_message_text.dart`: `copyMessageText(context, text)`
  — `Clipboard.setData` then a one-second **Tekst kopiert** snackbar (the
  messenger is captured before the await, so it is safe across the async gap).
- `competition_chat_screen.dart`: `_MessageBubble` gains `_showActions`, a bottom
  sheet with **Kopier tekst** (`chatCopyKey`, when the body is non-empty) and
  **Slett** (`chatDeleteKey`, when `canDelete`). The bubble's long-press opens it
  whenever either applies.
- `forum_screen.dart`: `_ReplyTile._showActions` gains **Kopier tekst**
  (`forumReplyCopyKey`, when the body is non-empty); the long-press opens the
  sheet when edit, delete **or** copy applies. The thread's opening-post body
  gets a long-press that opens a **Kopier tekst** sheet (`forumThreadCopyKey`).

## Verification
- **Widget (chat):** long-pressing a text message shows **Kopier tekst**; tapping
  it writes the body to the clipboard and shows **Tekst kopiert**. An image-only
  message (empty body) offers no copy item.
- **Widget (forum reply):** long-pressing a reply with text shows **Kopier
  tekst** next to Rediger/Slett; tapping copies the body. A reply you cannot edit
  or delete still long-presses to a sheet that offers copy.
- **Widget (forum thread):** long-pressing the opening post's body copies it.
- **Unit:** `copyMessageText` sets the clipboard to the given text (verified via
  the mock clipboard channel).

## Out of scope
- Partial / character-range selection within a message.
- Copying an attached image (only its text body is copied).
