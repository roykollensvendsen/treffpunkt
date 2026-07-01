# Spec 0075 — Supported image types & upload errors

- **Status:** Accepted.
- **Related:** 0053 (chat images), 0056 (forum images), 0062 (paste images),
  0073 (full-screen viewer).

## Context
Chat and forum uploads only ever distinguished **PNG vs JPEG** (by file name),
so a picked or pasted **GIF** was stored mislabelled as `image/jpeg`, and any
other file was silently accepted and mis-tagged with no feedback. We want to
**support GIF** as well and give a **clear message** when a file isn't a
supported image.

## Requirements
1. **JPG/JPEG, PNG and GIF** can be attached (picked or pasted) to a chat message
   or a forum thread/reply, and are stored with the correct extension and MIME
   type.
2. Any other file is **refused with a clear message** — nothing is uploaded or
   posted.

## Rationale
**Judge by content, not the file name.** A single `detectImageFormat(bytes)`
reads the **magic-byte header** (PNG `89 50 4E 47`, JPEG `FF D8 FF`, GIF
`47 49 46 38`) and returns the format — or `null` for anything else. This is
robust to a renamed or mislabelled file and removes the old `.png`-vs-everything
guess. The format carries its own storage `extension` and `mimeType`, so the
upload is always tagged correctly (GIFs keep `image/gif`, preserving animation).

**One choke point, one message.** The chat and forum image handlers all funnel
bytes through the detector; on `null` they show `unsupportedImageMessage` and
return, so the refusal is identical everywhere.

## Design
- `lib/core/platform/image_format.dart`: the `ImageFormat` enum
  (`png`/`jpeg`/`gif`, each with `extension` + `mimeType`),
  `detectImageFormat(bytes)`, `imageMimeForExtension(ext)` and the
  `unsupportedImageMessage` string.
- `competition_chat_screen.dart` / `forum_screen.dart`: the pick/paste handlers
  detect the format from the bytes, refuse with a snackbar on `null`, else upload
  with `format.extension`.
- The Supabase repos tag the object with `imageMimeForExtension(fileExtension)`
  (now including `image/gif`).

## Verification
- **Unit** (`image_format_test.dart`): PNG/JPEG/GIF headers map to the right
  format, extension and MIME; WebP / short / unknown content → `null`.
- **Widget** (chat, forum): a pasted GIF is stored with a `.gif` path; an
  unsupported file shows `unsupportedImageMessage` and posts nothing; the
  existing PNG pick/paste tests still pass.

## Out of scope
- Server-side (bucket) MIME/size limits; WebP/HEIC support; converting an
  unsupported image to a supported one.
