# Spec 0053 — Image attachments in competition chat

- **Status:** Accepted
- **Related:** spec 0051 (competition chat), spec 0052 (reactions), spec 0041
  (private training-images bucket — the storage pattern). Third chat increment;
  the forum follows and reuses this.

## Context
A chat is more useful when you can share a photo — a target, a scorecard, the
range. We add **image attachments** to competition chat messages: pick an image,
it uploads and posts as a message, and everyone sees it inline.

## Requirements
1. A participant can attach **one image** to the chat (optionally with text).
2. The image shows **inline** in the message bubble for everyone who can read the
   competition.
3. Images are **private**: stored in a non-public bucket and shown via a
   short-lived signed URL, so a leaked link expires and a non-reader can never
   fetch one.
4. Only a **participant** of the competition may upload (same boundary as
   posting).

## Rationale
**A private bucket keyed by competition, like the training-images bucket
(spec 0041).** Chat images are user content, so the bucket is private and the app
fetches a signed URL per image. The object path is `<competition_id>/<uuid>.<ext>`
so Storage Row-Level Security can read the competition id from the **first path
segment** (`storage.foldername(name)[1]`) and reuse `can_read_competition` /
`is_competition_participant` — no new helper, the same security story as the
message rows.

**The path on the message, the URL resolved on read.** The message row keeps the
object path in `image_path`; `watchMessages` resolves a signed URL per attached
image and hands it to the bubble as `imageUrl` (not persisted). Upload is a
separate `uploadChatImage` step that returns the path, which the composer then
sets on the posted message — so posting stays a plain insert.

## Design
- Migration `chat_images`: a private `chat-images` bucket; `storage.objects`
  policies (select = competition reader, insert = participant; no client delete
  — an orphaned image is harmless); and `competition_messages.image_path text`.
- `CompetitionMessage` gains `imagePath` (persisted) and `imageUrl` (resolved,
  attached by the repo, part of equality so the image renders on arrival).
- Repository `uploadChatImage(competitionId, bytes, {fileExtension})` → path;
  `watchMessages` attaches a signed URL for each `imagePath`.
- UI: an **attach-image** button in the composer (`chatAttachImageKey`) picks via
  an injected `imagePickerProvider` seam, uploads, then posts a message carrying
  the path; the bubble renders `Image.network(imageUrl)` (`chatImageKey`).

## Verification
### Unit tests (in-memory repository)
- A participant uploads → a path under `<competition>/`; posting a message with
  it makes the image (path + a resolved URL) ride along on `watchMessages`.
- A non-participant cannot upload (throws).

### System tests
- A message with an image renders an image widget in its bubble.
- Tapping attach (with an injected picker) uploads and posts an image message.

### Manual (real Supabase — storage RLS cannot be unit-tested here)
- As a participant, attaching an image uploads and shows it; as a
  non-participant of a private competition, the object is neither readable nor
  uploadable. Verify against local Supabase + the storage policies before
  relying on it in production.

## Open questions
- Multiple images per message, captions, and an image lightbox could follow.
- Orphaned objects (image whose message was deleted) are left for a later sweep.
