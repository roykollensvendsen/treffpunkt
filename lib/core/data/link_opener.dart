// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Opens external links (spec 0146) — the seam the widgets talk to, like
/// the camera and scanner seams (specs 0039/0040): tests record the URL,
/// `main()` binds the `url_launcher` implementation.
// ignore: one_member_abstracts — the seam IS the single capability.
abstract interface class LinkOpener {
  /// Opens [url] outside the app; `false` when no handler could take it.
  Future<bool> open(Uri url);
}

/// The default opener: always unavailable, so a screen under test — or a
/// platform without a handler — degrades to its own hint instead of
/// crashing.
class UnavailableLinkOpener implements LinkOpener {
  /// Creates the unavailable opener.
  const UnavailableLinkOpener();

  @override
  Future<bool> open(Uri url) async => false;
}
