// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/core/data/link_opener.dart';
import 'package:url_launcher/url_launcher.dart';

/// The real [LinkOpener] (spec 0146) — the only file importing
/// `url_launcher`. External-application mode, so a Vipps link leaves the
/// app and opens Vipps (or the browser) rather than an in-app web view.
/// Never throws: a platform refusal reads as `false`, which the caller
/// turns into its hint.
class UrlLauncherLinkOpener implements LinkOpener {
  /// Creates the launcher-backed opener.
  const UrlLauncherLinkOpener();

  @override
  Future<bool> open(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}
