// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the in-app user manual (spec 0050): the page list is
// well-formed, links resolve only to bundled pages, and — crucially — the list
// is pinned to docs/user/ so a guide page cannot be added without surfacing it
// in the app (the "document all functionality" rule, enforced).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/help/domain/manual.dart';

void main() {
  test('manualPages is non-empty and every entry is well-formed', () {
    expect(manualPages, isNotEmpty);
    for (final page in manualPages) {
      expect(page.title.trim(), isNotEmpty);
      expect(page.file, endsWith('.md'));
    }
  });

  test(
    'manualPageForLink resolves bundled pages and rejects everything else',
    () {
      expect(manualPageForLink('competitions.md')?.file, 'competitions.md');
      // An anchor is dropped before matching.
      expect(manualPageForLink('signing-in.md#godta')?.file, 'signing-in.md');
      // Not bundled / not same-folder / external → null.
      expect(manualPageForLink('../ROADMAP.md'), isNull);
      expect(manualPageForLink('https://example.com'), isNull);
      expect(manualPageForLink('nope.md'), isNull);
      expect(manualPageForLink(''), isNull);
    },
  );

  test('the in-app manual stays in sync with docs/user (spec 0050)', () {
    final onDisk = Directory('docs/user')
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.endsWith('.md') && name != 'index.md')
        .toSet();
    final inManifest = manualPages.map((page) => page.file).toSet();
    expect(
      inManifest,
      onDisk,
      reason:
          'A docs/user page is missing from (or stale in) manualPages — keep '
          'the in-app manual in sync with the guide (spec 0050).',
    );
  });
}
