// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';

/// One page of the in-app user manual (spec 0050): a `docs/user/` Markdown file
/// and the title shown for it in the contents list.
@immutable
class ManualPage {
  /// Creates a manual page for [file] (e.g. `competitions.md`) titled [title].
  const ManualPage({required this.file, required this.title});

  /// The Markdown file name within `docs/user/`, e.g. `competitions.md`.
  final String file;

  /// The human title shown in the contents list (in Norwegian, app chrome).
  final String title;

  @override
  bool operator ==(Object other) =>
      other is ManualPage && other.file == file && other.title == title;

  @override
  int get hashCode => Object.hash(file, title);
}

/// The user manual's pages, in reading order — mirrors the mkdocs nav, minus
/// the `index.md` overview (the in-app contents list replaces it). A test pins
/// to the files in `docs/user/`, so a new guide page cannot be added without
/// also surfacing it here (spec 0050).
const List<ManualPage> manualPages = <ManualPage>[
  ManualPage(file: 'getting-started.md', title: 'Kom i gang'),
  ManualPage(file: 'signing-in.md', title: 'Logg inn'),
  ManualPage(
    file: 'score-a-10m-air-rifle-target.md',
    title: 'Poengsetting på 10 m luftrifle',
  ),
  ManualPage(file: 'scan-a-paper-target.md', title: 'Skann en papirblink'),
  ManualPage(file: 'competitions.md', title: 'Konkurranser'),
  ManualPage(
    file: 'personvern-treningsbilder.md',
    title: 'Treningsbilder og personvern',
  ),
];

/// The manual page a Markdown link [href] points to, or `null` when the link is
/// not one of the bundled pages (an external or dev-doc reference).
///
/// Resolves only same-folder links to a bundled file — it drops any `#anchor`
/// and rejects links that escape the folder (`../…`) or are absolute URLs, so
/// the viewer navigates within the manual and leaves everything else alone.
ManualPage? manualPageForLink(String href) {
  if (href.isEmpty || href.contains('://') || href.contains('/')) return null;
  final file = href.split('#').first;
  for (final page in manualPages) {
    if (page.file == file) return page;
  }
  return null;
}
