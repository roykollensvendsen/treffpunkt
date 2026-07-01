// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

/// A supported uploadable image format (spec 0075): JPEG, PNG or GIF.
enum ImageFormat {
  /// PNG.
  png('png', 'image/png'),

  /// JPEG (stored with a `.jpg` extension).
  jpeg('jpg', 'image/jpeg'),

  /// GIF (keeps animation).
  gif('gif', 'image/gif');

  const ImageFormat(this.extension, this.mimeType);

  /// The file extension to store the object under (no dot).
  final String extension;

  /// The MIME type to tag the upload with.
  final String mimeType;
}

/// The message shown when someone picks a file we do not support (spec 0075).
const String unsupportedImageMessage =
    'Filformatet støttes ikke. Bruk JPG, PNG eller GIF.';

/// Detects the format of [bytes] from its magic-byte header, or `null` if it is
/// not a supported image (spec 0075).
///
/// Reads the actual content rather than trusting a file name or MIME string, so
/// a mislabelled or renamed file is judged by what it really is.
ImageFormat? detectImageFormat(Uint8List bytes) {
  if (bytes.length < 4) return null;
  // PNG: 89 50 4E 47 ("‰PNG").
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return ImageFormat.png;
  }
  // JPEG: FF D8 FF.
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return ImageFormat.jpeg;
  }
  // GIF: 47 49 46 38 ("GIF8", covers 87a and 89a).
  if (bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38) {
    return ImageFormat.gif;
  }
  return null;
}

/// The MIME type for a stored [extension] (`png`/`gif`/anything else → JPEG).
String imageMimeForExtension(String extension) => switch (extension) {
  'png' => 'image/png',
  'gif' => 'image/gif',
  _ => 'image/jpeg',
};
