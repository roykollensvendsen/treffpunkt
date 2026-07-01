// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for image-format detection (spec 0075): PNG/JPEG/GIF are read from
// the magic-byte header; anything else is rejected.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/platform/image_format.dart';

Uint8List _bytes(List<int> header) =>
    Uint8List.fromList(<int>[...header, 0, 0, 0, 0]);

void main() {
  test('detects PNG, JPEG and GIF from their headers', () {
    expect(
      detectImageFormat(_bytes(<int>[0x89, 0x50, 0x4E, 0x47])),
      ImageFormat.png,
    );
    expect(
      detectImageFormat(_bytes(<int>[0xFF, 0xD8, 0xFF])),
      ImageFormat.jpeg,
    );
    expect(
      detectImageFormat(_bytes(<int>[0x47, 0x49, 0x46, 0x38])),
      ImageFormat.gif,
    );
  });

  test('extensions and MIME types are correct', () {
    expect(ImageFormat.png.extension, 'png');
    expect(ImageFormat.jpeg.extension, 'jpg');
    expect(ImageFormat.gif.extension, 'gif');
    expect(imageMimeForExtension('png'), 'image/png');
    expect(imageMimeForExtension('gif'), 'image/gif');
    expect(imageMimeForExtension('jpg'), 'image/jpeg');
  });

  test('rejects unsupported or too-short content', () {
    // WebP ("RIFF....WEBP") is not supported.
    expect(detectImageFormat(_bytes(<int>[0x52, 0x49, 0x46, 0x46])), isNull);
    expect(detectImageFormat(_bytes(<int>[1, 2, 3, 4])), isNull);
    expect(detectImageFormat(Uint8List.fromList(<int>[1, 2])), isNull);
  });
}
