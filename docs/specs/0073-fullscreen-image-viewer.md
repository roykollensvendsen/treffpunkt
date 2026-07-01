# Spec 0073 — Full-screen image viewer

- **Status:** Accepted.
- **Related:** 0053 (chat image attachments), 0056 (forum image attachments),
  0062 (paste images) — this makes those pictures inspectable.

## Context
Chat and forum pictures render as a small inline thumbnail (180 px tall,
`BoxFit.cover`) that is cropped and not tappable. You can't read the details of a
scanned target or a shared photo, and there's no way to zoom or pan.

## Requirements
1. Tapping a chat or forum picture opens it **full-screen**.
2. In the viewer you can **zoom** (pinch / scroll) and **pan** (drag) to inspect
   detail.
3. A clear **close** action (and the system back) returns to the conversation.

## Rationale
**One shared widget.** Chat and forum both rendered the same
`ClipRRect(Image.network(...))`; replace both with a single
`TappableNetworkImage` so the tap-to-zoom behaviour is identical and defined
once. The full-screen view uses Flutter's built-in **`InteractiveViewer`** for
zoom/pan (no dependency) and a **`Hero`** so the thumbnail expands smoothly into
the viewer and back.

**Per-image Hero tag.** Each thumbnail passes a tag unique on screen
(`chatImage-<id>` / `forumImage-<id>`) so multiple pictures animate correctly and
never collide.

## Design
- `lib/core/presentation/full_screen_image.dart`:
  - `TappableNetworkImage` — the thumbnail (keeps the per-image `thumbnailKey`
    for tests), wrapped in a `GestureDetector` + `Hero`; on tap it calls
    `openFullScreenImage`.
  - `openFullScreenImage(context, url, heroTag)` — pushes a `fullscreenDialog`
    route showing an `InteractiveViewer` (`fullScreenImageKey`, `minScale` 1,
    `maxScale` 5) over a black background, with a close button
    (`fullScreenImageCloseKey`).
- `competition_chat_screen.dart` and `forum_screen.dart` (`_ForumImage`) render
  `TappableNetworkImage` instead of a bare `Image.network`.

## Verification
- **Widget** (`full_screen_image_test.dart`): tapping the thumbnail shows the
  `InteractiveViewer`; the close action dismisses it.
- **Widget** (chat, forum): tapping an attached picture opens the full-screen
  viewer; the existing "renders the picture" checks still pass.

## Out of scope
- Saving/downloading the image, double-tap-to-zoom, and multi-image swiping.
