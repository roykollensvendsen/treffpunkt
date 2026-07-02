// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';
import 'package:treffpunkt/core/platform/sharer.dart';

/// A [Sharer] backed by `share_plus` — the OS share sheet on mobile/desktop and
/// the Web Share API in the browser. The only file importing `share_plus`.
class SharePlusSharer implements Sharer {
  /// Creates the share_plus-backed sharer.
  const SharePlusSharer();

  @override
  Future<void> share(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Future<void> shareFile({
    required String filename,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType)],
        // `XFile.fromData`'s name is ignored by share_plus; the override is
        // what actually names the shared/downloaded file.
        fileNameOverrides: [filename],
      ),
    );
  }
}
