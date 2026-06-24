// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/scoring/data/image_source_service.dart';

/// In-memory [ImageSourceService] for tests — no real camera or gallery.
class FakeImageSourceService implements ImageSourceService {
  /// Creates a fake returning [camera] from [capturePhoto] and [gallery] from
  /// [pickFromGallery]. Each defaults to [result], which itself defaults to an
  /// [ImagePickUnavailable] (no image).
  FakeImageSourceService({
    ImageSourceResult? result,
    ImageSourceResult? camera,
    ImageSourceResult? gallery,
  }) : camera = camera ?? result ?? const ImagePickUnavailable(),
       gallery = gallery ?? result ?? const ImagePickUnavailable();

  /// The result returned by [capturePhoto].
  ImageSourceResult camera;

  /// The result returned by [pickFromGallery].
  ImageSourceResult gallery;

  /// How many times [capturePhoto] has been called.
  int captureCount = 0;

  /// How many times [pickFromGallery] has been called.
  int galleryCount = 0;

  @override
  Future<ImageSourceResult> capturePhoto() async {
    captureCount++;
    return camera;
  }

  @override
  Future<ImageSourceResult> pickFromGallery() async {
    galleryCount++;
    return gallery;
  }
}
