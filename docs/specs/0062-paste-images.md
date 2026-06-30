# Spec 0062 — Paste an image into chat and forum

- **Status:** Accepted
- **Related:** spec 0053 (chat images), spec 0056 (forum images), spec 0042
  (conditional-import platform seam).

## Context
You can attach an image to a competition chat message, a forum thread and a
forum reply by **picking a file** (specs 0053/0056). On a computer the natural
gesture is to **paste** — copy a screenshot or image and press **Ctrl/Cmd+V**
straight into the composer. We add that, reusing the existing upload paths.

## Requirements
1. Pasting an image (Ctrl/Cmd+V) sends/attaches it exactly as picking one does:
   - in a **competition chat** — uploads and posts it (with any composer text);
   - in a **forum reply** — uploads and posts the reply with the image;
   - in the **new-thread** form — attaches it as the thread's pending image.
2. Only the **visible** composer handles a paste (the top-most route), so a paste
   is not delivered twice.
3. It is a **web** capability; off the web (and in tests) nothing happens — the
   file-picker buttons remain the universal path.
4. Pasting non-image content is ignored (normal text paste still works).

## Rationale
**A conditional-import seam, like the browser environment (spec 0042).** A pure
`ClipboardImageWatcher` exposes a `Stream<PastedImage>`; the `_web` implementation
registers a single `paste` listener on the document (capture phase) and reads the
pasted image from `clipboardData.files` as bytes; the `_stub` is an empty stream
off-web and in tests. A fake stream drives the widget tests.

**Reuse the existing upload, don't duplicate it.** Each composer already has a
handler that takes image bytes and either posts (chat, reply) or stages the
upload (new thread). The pick handlers are refactored to call a shared
bytes-handler, and the paste subscription calls the same one — so paste and pick
behave identically, including error handling.

**Route-gated so it fires once.** A composer handles a paste only when its route
`isCurrent`, so the forum list (new-thread) and a pushed thread (reply) never both
react to the same paste.

## Design
- `lib/core/platform/clipboard_image.dart` — `PastedImage{bytes, isPng}`,
  `ClipboardImageWatcher`, `createClipboardImageWatcher()` (conditional import);
  `clipboardImageWatcherProvider`.
- `_web.dart` reads `ClipboardEvent.clipboardData.files`; `_stub.dart` is empty.
- Chat / forum-reply / new-thread: extract a bytes-handler from each pick handler;
  subscribe to the watcher in `initState`, route-gate, and feed the bytes in;
  cancel on dispose.

## Verification
### Widget tests (fake watcher)
- Emitting a `PastedImage` in the chat posts a message with an image.
- Emitting one in a forum reply posts a reply with an image.
- Emitting one in the new-thread form stages the attached-image indicator.

### Manual (web)
- Copy a screenshot, focus the chat, press Ctrl/Cmd+V → it posts. Same in a forum
  reply and the new-thread form. A non-image paste does nothing special.

## Open questions
- A small preview/confirm step before sending a pasted chat image.
- Drag-and-drop of an image file (a natural companion gesture).
