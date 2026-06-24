// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the image_picker mapping (spec 0039): a picked file becomes
// ImagePicked, a cancel becomes ImagePickCancelled, a permission denial becomes
// ImagePickDenied, and any other error becomes ImagePickUnavailable — driven
// through a fake gateway so no real plugin is touched.
import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/data/image_picker_image_source_service.dart';
import 'package:treffpunkt/features/scoring/data/image_source_service.dart';

/// A fake gateway returning a queued outcome (a [PickedImage], `null`, or a
/// thrown error) so the service's mapping is tested without `image_picker`.
class _FakeGateway implements ImagePickerGateway {
  _FakeGateway({this.image, this.error});

  final PickedImage? image;
  final Object? error;
  bool? lastFromCamera;

  @override
  Future<PickedImage?> pickImage({required bool fromCamera}) async {
    lastFromCamera = fromCamera;
    final err = error;
    // ignore: only_throw_errors — the test drives both Error and Exception.
    if (err != null) throw err;
    return image;
  }
}

void main() {
  final bytes = Uint8List.fromList(<int>[1, 2, 3]);

  test('a picked file becomes ImagePicked carrying the bytes', () async {
    final gateway = _FakeGateway(image: PickedImage(bytes: bytes));
    final service = ImagePickerImageSourceService(gateway: gateway);

    final result = await service.capturePhoto();

    expect(result, isA<ImagePicked>());
    expect((result as ImagePicked).image.bytes, bytes);
    expect(gateway.lastFromCamera, isTrue);
  });

  test(
    'capturePhoto asks the camera, pickFromGallery asks the gallery',
    () async {
      final gateway = _FakeGateway(image: PickedImage(bytes: bytes));
      final service = ImagePickerImageSourceService(gateway: gateway);

      await service.pickFromGallery();

      expect(gateway.lastFromCamera, isFalse);
    },
  );

  test('a null pick (user cancelled) becomes ImagePickCancelled', () async {
    final service = ImagePickerImageSourceService(gateway: _FakeGateway());

    expect(await service.capturePhoto(), isA<ImagePickCancelled>());
  });

  test(
    'a permission-denied PlatformException becomes ImagePickDenied',
    () async {
      final service = ImagePickerImageSourceService(
        gateway: _FakeGateway(
          error: PlatformException(code: 'camera_access_denied'),
        ),
      );

      expect(await service.capturePhoto(), isA<ImagePickDenied>());
    },
  );

  test('any other error becomes ImagePickUnavailable', () async {
    final service = ImagePickerImageSourceService(
      gateway: _FakeGateway(error: Exception('boom')),
    );

    expect(await service.capturePhoto(), isA<ImagePickUnavailable>());
  });
}
