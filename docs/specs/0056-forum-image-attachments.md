# Spec 0056 — Image attachments in the forum

- **Status:** Accepted
- **Related:** spec 0054 (forum), spec 0055 (forum reactions), spec 0053 (chat
  image attachments — same shape).

## Context
A bug report or idea is often clearer with a picture. We add **image
attachments** to forum **threads** (the opening post) and **replies**, shown
inline.

## Requirements
1. When starting a thread, the author can **attach one image**; when replying,
   the author can attach one image.
2. The image shows **inline** in the opening post / reply for everyone.
3. Images are **private**: a non-public bucket, shown via a short-lived signed
   URL.

## Rationale
**The chat image pattern (spec 0053), forum-wide.** A private `forum-images`
bucket; the row keeps the object path in `image_path`; reads resolve a signed
URL into `imageUrl`. Because the forum is read- and write-able by every
signed-in user, the Storage RLS is the simplest possible — read and insert for
any authenticated user, scoped to the bucket. Upload is a separate
`uploadForumImage` step that returns the path, set on the created thread / posted
reply, so writes stay plain inserts. The picker is behind a `forumImagePicker`
seam so the flow is widget-tested without the OS gallery.

## Design
- Migration `forum_images`: a private `forum-images` bucket; `storage.objects`
  select/insert policies for authenticated; `image_path text` on `forum_threads`
  and `forum_posts`.
- `imagePath` (persisted) + `imageUrl` (resolved) on `ForumThread`/`ForumPost`,
  part of equality so the image renders on arrival.
- `ForumRepository.uploadForumImage(bytes, {fileExtension})`; reads attach signed
  URLs.
- UI: an attach-image button on the new-thread form (with an "attached"
  indicator) and in the reply composer; the opening post and replies render
  `Image.network(imageUrl)`.

## Verification
### Unit tests (in-memory repository)
- Uploading returns a path; a thread and a reply created with it carry the path
  and a resolved URL on `watchThreads` / `watchPosts`.

### System tests
- A thread with an image renders an image widget in its opening post.
- Tapping attach in the reply composer (with an injected picker) uploads and
  posts an image reply.

### Manual (real Supabase — storage RLS cannot be unit-tested here)
- Attaching an image to a thread/reply uploads and shows it; verify the
  `forum-images` policies against local Supabase before relying on them.

## Open questions
- Multiple images, captions and a lightbox could follow.
