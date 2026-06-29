// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/help/domain/manual.dart';
import 'package:treffpunkt/features/help/presentation/help_providers.dart';

/// Key for the help action that opens the manual (spec 0050).
const Key helpButtonKey = ValueKey<String>('help');

/// Key for the contents-list row of the manual page with file name [file].
Key manualPageTileKey(String file) => ValueKey<String>('manualPage-$file');

/// The in-app user manual (spec 0050): a contents list of the `docs/user/`
/// pages. Tapping one opens it rendered. The same Markdown the published guide
/// uses, bundled so it works offline.
class HelpScreen extends StatelessWidget {
  /// Creates the manual's contents screen.
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Brukerveiledning')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: <Widget>[
                for (final page in manualPages)
                  ListTile(
                    key: manualPageTileKey(page.file),
                    leading: const Icon(Icons.article_outlined),
                    title: Text(page.title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ManualPageScreen(page: page),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One manual page, loaded from the bundle and rendered (spec 0050).
class ManualPageScreen extends ConsumerWidget {
  /// Creates a viewer for [page].
  const ManualPageScreen({required this.page, super.key});

  /// The page to load and render.
  final ManualPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final markdown = ref.watch(manualPageProvider(page.file));
    return Scaffold(
      appBar: AppBar(title: Text(page.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: markdown.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Kunne ikke laste denne siden.'),
              ),
              data: (raw) => Markdown(
                data: _withoutLicenceComment(raw),
                onTapLink: (text, href, title) => _onTapLink(context, href),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onTapLink(BuildContext context, String? href) {
    if (href == null) return;
    final target = manualPageForLink(href);
    if (target != null) {
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ManualPageScreen(page: target),
          ),
        ),
      );
      return;
    }
    // A dev-doc or external reference: it is not bundled, so say so rather than
    // silently doing nothing (spec 0050).
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Denne lenken finnes bare i nettversjonen.'),
        ),
      );
  }
}

/// Drops a leading SPDX licence HTML comment so it never renders as a blank gap
/// or stray text above the first heading.
String _withoutLicenceComment(String markdown) =>
    markdown.replaceFirst(RegExp(r'^\s*<!--.*?-->\s*', dotAll: true), '');
