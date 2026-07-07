// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/data/link_opener.dart';

/// The app's [LinkOpener] (spec 0146). Defaults to unavailable so tests and
/// a fresh widget tree never touch the platform; `main()` overrides it with
/// the `url_launcher` implementation.
final linkOpenerProvider = Provider<LinkOpener>(
  (ref) => const UnavailableLinkOpener(),
);
