// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/settings/presentation/contribution_providers.dart';

/// Key for the one-time training-data disclosure dialog (spec 0041).
const Key contributionDisclosureKey = ValueKey<String>(
  'contributionDisclosure',
);

/// Key for the disclosure's "Skru av" action (opts out).
const Key contributionDisclosureDeclineKey = ValueKey<String>(
  'contributionDisclosureDecline',
);

/// Key for the disclosure's "Greit" action (keeps the default opt-in).
const Key contributionDisclosureAcceptKey = ValueKey<String>(
  'contributionDisclosureAccept',
);

/// The one-time disclosure shown the first time a shooter scans (spec 0041).
///
/// Tells the shooter, in plain Norwegian, what is collected (the target photo +
/// the marked hit positions), why (to improve hit detection), and that it is
/// optional and on by default — with an immediate "Skru av" affordance. The
/// scan proceeds regardless of the choice.
class ContributionDisclosureDialog extends ConsumerWidget {
  /// Creates the disclosure dialog.
  const ContributionDisclosureDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      key: contributionDisclosureKey,
      title: const Text('Hjelp oss å gjenkjenne treff bedre'),
      content: const Text(
        'For å forbedre den automatiske treffgjenkjenningen lagrer Treffpunkt '
        'bildet du tar av skiva sammen med hvor treffene er markert. Bildene '
        'knyttes til kontoen din og brukes bare til å gjøre gjenkjenningen '
        'bedre.\n\n'
        'Dette er valgfritt og på som standard. Du kan skru det av når som '
        'helst i appen, og det påvirker ikke skanningen din. Takk for at du '
        'bidrar!',
      ),
      actions: [
        TextButton(
          key: contributionDisclosureDeclineKey,
          onPressed: () {
            ref
                .read(contributionConsentProvider.notifier)
                .setEnabled(enabled: false);
            Navigator.of(context).pop();
          },
          child: const Text('Skru av'),
        ),
        FilledButton(
          key: contributionDisclosureAcceptKey,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Greit'),
        ),
      ],
    );
  }
}
