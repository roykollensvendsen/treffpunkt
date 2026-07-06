// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

/// The shared load-failure state (spec 0011): a short «Kunne ikke hente
/// konkurransene.» notice over a «Prøv igjen» button, shown when a foreground
/// read fails so the shooter gets a retry rather than a silent empty list.
class ErrorRetry extends StatelessWidget {
  /// Creates the failure state.
  const ErrorRetry({required this.onRetry, super.key});

  /// Called when the «Prøv igjen» button is tapped.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          const Text('Kunne ikke hente konkurransene.'),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('Prøv igjen')),
        ],
      ),
    );
  }
}
