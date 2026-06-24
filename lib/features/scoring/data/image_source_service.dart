// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

/// A picked image as raw bytes, with its declared [mimeType] when known.
///
/// Bytes (not a file path) so the same value works on web — which has no file
/// system — and on mobile (spec 0039).
class PickedImage {
  /// Creates a picked image wrapping [bytes], optionally tagged [mimeType].
  const PickedImage({required this.bytes, this.mimeType});

  /// The image's encoded bytes (PNG / JPEG …), ready for `Image.memory`.
  final Uint8List bytes;

  /// The image's MIME type (e.g. `image/jpeg`), or `null` when unknown.
  final String? mimeType;
}

/// The outcome of an [ImageSourceService] capture / pick.
///
/// A sealed result so callers `switch` over every outcome exhaustively (like
/// `LocationResult`, ADR-0015): [ImagePicked] carries the bytes; the other
/// three all keep the user on the capture step — only [ImagePickDenied]
/// additionally warrants pointing them at the gallery (no camera permission).
sealed class ImageSourceResult {
  /// Const base constructor.
  const ImageSourceResult();
}

/// A successful pick carrying the chosen [image].
class ImagePicked extends ImageSourceResult {
  /// Creates a picked result wrapping [image].
  const ImagePicked(this.image);

  /// The captured or chosen image.
  final PickedImage image;
}

/// The user backed out without choosing an image. Normal; not an error.
class ImagePickCancelled extends ImageSourceResult {
  /// Creates the cancelled result.
  const ImagePickCancelled();
}

/// Camera or photo-library permission was denied.
///
/// The capture step stays; the UI can suggest the gallery, which needs no
/// camera permission, as the alternative.
class ImagePickDenied extends ImageSourceResult {
  /// Creates the denied result.
  const ImagePickDenied();
}

/// No image for any other reason — no camera, an unsupported source, or any
/// thrown error. The capture step stays so the user can pick a file instead.
class ImagePickUnavailable extends ImageSourceResult {
  /// Creates the unavailable result.
  const ImagePickUnavailable();
}

/// Captures or picks a target photo, independent of any platform or plugin.
///
/// Reaching the camera / gallery through this interface keeps the scan screen
/// testable with a fake and confines the plugin to one data-layer file (the
/// same seam pattern as `LocationService`, ADR-0015). Both methods report a
/// sealed [ImageSourceResult] and **never throw**, so the screen degrades
/// cleanly when a source is missing or denied (spec 0039).
abstract interface class ImageSourceService {
  /// Opens the camera to take a target photo. On web, where the camera is not
  /// reliably available, this falls back to (or behaves like) a file picker.
  Future<ImageSourceResult> capturePhoto();

  /// Picks an existing target photo from the gallery (mobile) or a file dialog
  /// (web / desktop). Needs no camera permission, so it always works.
  Future<ImageSourceResult> pickFromGallery();
}

/// An [ImageSourceService] that can never pick an image.
///
/// The default binding until the real `image_picker`-backed service is wired
/// (spec 0039); it makes the scan feature degrade cleanly — "can't pick" rather
/// than a crash — on every platform and in tests.
class UnavailableImageSourceService implements ImageSourceService {
  /// Creates the always-unavailable service.
  const UnavailableImageSourceService();

  @override
  Future<ImageSourceResult> capturePhoto() async =>
      const ImagePickUnavailable();

  @override
  Future<ImageSourceResult> pickFromGallery() async =>
      const ImagePickUnavailable();
}
