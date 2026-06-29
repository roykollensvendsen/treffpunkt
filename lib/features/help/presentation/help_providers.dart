// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Loads the raw Markdown for a manual page, given its asset path
/// (`docs/user/<file>`). A seam (spec 0050) so widget tests can feed canned
/// text instead of relying on the real asset bundle.
typedef ManualLoader = Future<String> Function(String assetPath);

/// Reads a bundled manual page from the asset bundle (the real implementation).
///
/// Overridden in tests with a fake that returns canned Markdown.
final manualLoaderProvider = Provider<ManualLoader>(
  (ref) => rootBundle.loadString,
);

/// The raw Markdown of the manual page with the given `docs/user/` file name,
/// loaded through [manualLoaderProvider] (spec 0050). A family so each page is
/// cached by file name and the screen can show loading / error states.
// ignore: specify_nonobvious_property_types
final manualPageProvider = FutureProvider.family<String, String>(
  (ref, file) => ref.watch(manualLoaderProvider)('docs/user/$file'),
);
