// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shares text (e.g. a competition join link) or a file (spec 0106) through
/// the OS share sheet (spec 0048). A seam so the share UI is testable without
/// invoking the real native/Web Share sheet, and so `share_plus` is confined
/// to one file.
abstract interface class Sharer {
  /// Opens the platform share sheet for [text].
  Future<void> share(String text);

  /// Opens the platform share sheet for a file with the given [filename],
  /// [mimeType] and [bytes] (spec 0106) — on web this typically becomes a
  /// download, on mobile the usual share targets.
  Future<void> shareFile({
    required String filename,
    required String mimeType,
    required Uint8List bytes,
  });
}

/// The default binding: sharing is a no-op (e.g. in tests and on platforms
/// without a share sheet). `main()` overrides [sharerProvider] with the real
/// `share_plus`-backed one.
class UnavailableSharer implements Sharer {
  /// Creates the no-op sharer.
  const UnavailableSharer();

  @override
  Future<void> share(String text) async {}

  @override
  Future<void> shareFile({
    required String filename,
    required String mimeType,
    required Uint8List bytes,
  }) async {}
}

/// The app's [Sharer]; overridden in `main()` with the `share_plus`-backed one.
final sharerProvider = Provider<Sharer>((ref) => const UnavailableSharer());
