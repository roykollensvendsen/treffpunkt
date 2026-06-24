// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:treffpunkt/features/scoring/data/contribution_service.dart';
import 'package:treffpunkt/features/scoring/domain/training_label.dart';
import 'package:treffpunkt/features/scoring/domain/training_sample.dart';

/// A [ContributionService] backed by Supabase Storage + Postgres (spec 0041).
/// The only file importing `supabase_flutter` + the Storage API.
///
/// Re-encodes the photo to a clean JPEG — stripping EXIF/GPS and baking
/// orientation, so the uploaded pixels match the label's image-pixel
/// coordinates — uploads it to the private `training-images` bucket under
/// `<uid>/<id>.jpg`, then inserts the annotation row. Owner-only RLS scopes both
/// to the signed-in shooter. Best-effort: every failure is swallowed (debug log
/// only), so a contribution never blocks or breaks a scan.
class SupabaseContributionService implements ContributionService {
  /// Creates the service over [_client].
  SupabaseContributionService(this._client);

  final SupabaseClient _client;

  static const String _bucket = 'training-images';
  static const String _table = 'training_samples';

  @override
  Future<void> contribute(TrainingSample sample) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return;

      final decoded = img.decodeImage(sample.imageBytes);
      if (decoded == null) return;
      final oriented = img.bakeOrientation(decoded);
      // Re-encode to a fresh JPEG: this drops EXIF/GPS and gives the exact
      // dimensions of the bytes we upload, which the label's pixel coordinates
      // are expressed against.
      final cleanBytes = img.encodeJpg(oriented, quality: 85);

      final path = '$uid/${sample.id}.jpg';
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            path,
            cleanBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      await _client.from(_table).insert(<String, dynamic>{
        'id': sample.id,
        'image_path': path,
        'program': sample.geometry.name,
        'label': buildLabel(
          sample,
          imageWidth: oriented.width,
          imageHeight: oriented.height,
        ),
        'app_version': sample.appVersion,
      });
    } on Object catch (error) {
      // Non-critical and off the happy path: never surface a failure.
      if (!kReleaseMode) debugPrint('Failed to contribute a scan: $error');
    }
  }
}
