// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';
import 'package:treffpunkt/features/scoring/data/image_source_service.dart';

/// The image-picking operations [ImagePickerImageSourceService] depends on.
///
/// A thin seam over the `image_picker` plugin (which cannot be faked directly)
/// so the cancel / denial / error mapping is unit-testable with a fake gateway.
/// [RealImagePickerGateway] binds it to the real plugin; tests supply a fake.
// ignore: one_member_abstracts — a deliberate seam, not an accidental wrapper.
abstract interface class ImagePickerGateway {
  /// Picks an image — from the camera when [fromCamera], else the gallery —
  /// returning its bytes, or `null` when the user cancels. May throw a
  /// [PlatformException] (e.g. a permission denial) for the service to map.
  Future<PickedImage?> pickImage({required bool fromCamera});
}

/// The default [ImagePickerGateway], forwarding to the real `image_picker`
/// plugin. Caps the image size to keep a full-resolution phone photo from
/// dominating memory; behaviour is otherwise the plugin's, so the testable
/// logic lives in [ImagePickerImageSourceService] instead.
class RealImagePickerGateway implements ImagePickerGateway {
  /// Creates the real gateway over [picker] (a fresh [ImagePicker] by default).
  RealImagePickerGateway({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Longest edge (px) the picked image is down-scaled to, capping memory.
  static const double _maxEdge = 2400;

  /// JPEG quality (0–100) the picked image is re-encoded at.
  static const int _quality = 85;

  @override
  Future<PickedImage?> pickImage({required bool fromCamera}) async {
    final file = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: _maxEdge,
      maxHeight: _maxEdge,
      imageQuality: _quality,
    );
    if (file == null) return null;
    return PickedImage(
      bytes: await file.readAsBytes(),
      mimeType: file.mimeType,
    );
  }
}

/// An [ImageSourceService] backed by the `image_picker` plugin (web + Android +
/// iOS). The only file that imports the plugin.
///
/// Maps the plugin's outcomes to the sealed [ImageSourceResult] and **never
/// throws** (spec 0039): a returned image is [ImagePicked]; `null` (the user
/// cancelled) is [ImagePickCancelled]; a permission-denied [PlatformException]
/// is [ImagePickDenied]; any other error is [ImagePickUnavailable]. On web,
/// where `ImageSource.camera` is not reliably supported, the plugin falls back
/// to a file dialog — still a usable pick.
class ImagePickerImageSourceService implements ImageSourceService {
  /// Creates the service over [gateway] (the real plugin by default).
  ImagePickerImageSourceService({ImagePickerGateway? gateway})
    : gateway = gateway ?? RealImagePickerGateway();

  /// The image-picking operations this service depends on (the real plugin by
  /// default; a fake in tests).
  final ImagePickerGateway gateway;

  @override
  Future<ImageSourceResult> capturePhoto() => _pick(fromCamera: true);

  @override
  Future<ImageSourceResult> pickFromGallery() => _pick(fromCamera: false);

  Future<ImageSourceResult> _pick({required bool fromCamera}) async {
    try {
      final image = await gateway.pickImage(fromCamera: fromCamera);
      return image == null ? const ImagePickCancelled() : ImagePicked(image);
    } on PlatformException catch (error) {
      // image_picker reports a blocked camera / photo library with a
      // `*_access_denied` code; everything else is a generic unavailability.
      return error.code.contains('denied')
          ? const ImagePickDenied()
          : const ImagePickUnavailable();
    } on Object {
      return const ImagePickUnavailable();
    }
  }
}
