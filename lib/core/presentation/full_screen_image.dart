// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';

/// Key for the zoomable image on the full-screen viewer (spec 0073).
const Key fullScreenImageKey = ValueKey<String>('fullScreenImage');

/// Key for the close action on the full-screen viewer (spec 0073).
const Key fullScreenImageCloseKey = ValueKey<String>('fullScreenImageClose');

/// A thumbnail network image that opens a zoomable full-screen viewer on tap
/// (spec 0073), so a chat/forum picture can be inspected in detail.
///
/// [heroTag] must be unique among the images on screen (e.g. `chatImage-<id>`);
/// [thumbnailKey] keeps the existing per-image key for tests.
class TappableNetworkImage extends StatelessWidget {
  /// Creates a tappable thumbnail for [url].
  const TappableNetworkImage({
    required this.url,
    required this.heroTag,
    this.thumbnailKey,
    this.height = 180,
    super.key,
  });

  /// The image URL.
  final String url;

  /// The Hero tag shared with the full-screen view (unique on screen).
  final String heroTag;

  /// Key placed on the thumbnail image itself, for tests.
  final Key? thumbnailKey;

  /// The thumbnail height.
  final double height;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () =>
        unawaited(openFullScreenImage(context, url: url, heroTag: heroTag)),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Hero(
        tag: heroTag,
        child: Image.network(
          url,
          key: thumbnailKey,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => SizedBox(
            height: height,
            width: height,
            child: const Center(child: Icon(Icons.broken_image)),
          ),
        ),
      ),
    ),
  );
}

/// Opens the full-screen, zoomable viewer for [url] (spec 0073).
Future<void> openFullScreenImage(
  BuildContext context, {
  required String url,
  required String heroTag,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => _FullScreenImage(url: url, heroTag: heroTag),
  ),
);

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.url, required this.heroTag});

  final String url;
  final String heroTag;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      iconTheme: const IconThemeData(color: Colors.white),
      leading: IconButton(
        key: fullScreenImageCloseKey,
        icon: const Icon(Icons.close),
        tooltip: 'Lukk',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ),
    // Pinch or scroll to zoom, drag to move around; back or ✕ closes.
    body: InteractiveViewer(
      key: fullScreenImageKey,
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: Hero(
          tag: heroTag,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    ),
  );
}
