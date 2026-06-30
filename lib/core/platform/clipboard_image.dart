// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/platform/clipboard_image_stub.dart'
    if (dart.library.js_interop) 'package:treffpunkt/core/platform/clipboard_image_web.dart'
    as impl;

/// An image the user pasted from the clipboard (spec 0062).
class PastedImage {
  /// Creates a pasted image.
  const PastedImage({required this.bytes, required this.isPng});

  /// The raw image bytes.
  final Uint8List bytes;

  /// Whether the image is a PNG (else treated as JPEG), from its MIME type.
  final bool isPng;
}

/// Watches for images pasted with Ctrl/Cmd+V (spec 0062).
///
/// The real implementation (web only) listens to the document's `paste` event;
/// off the web — and in tests — the stub emits nothing. A fake drives tests.
abstract interface class ClipboardImageWatcher {
  /// Emits an image each time the user pastes one.
  Stream<PastedImage> get images;
}

/// The real watcher on the web; an empty one elsewhere and in tests.
ClipboardImageWatcher createClipboardImageWatcher() =>
    impl.createClipboardImageWatcher();

/// The app's [ClipboardImageWatcher]. Tests override it with a fake.
final clipboardImageWatcherProvider = Provider<ClipboardImageWatcher>(
  (ref) => createClipboardImageWatcher(),
);
