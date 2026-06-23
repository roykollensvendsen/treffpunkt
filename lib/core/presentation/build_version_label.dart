// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:treffpunkt/config/build_info.dart';

/// Key for the build-version footer, used by widget and system tests.
const Key buildVersionKey = ValueKey<String>('buildVersion');

/// A small, muted, centred stamp of the running build's version (spec 0028).
///
/// Shows [BuildInfo.label] — the deploy's short commit SHA (matching the
/// spec-0027 `?v=` cache-bust version) and build time — so a user can confirm
/// at a glance which build they are on. Discreet by design: it is a diagnostic
/// aid, not chrome. Reusable; dropped as a footer on always-reachable screens.
class BuildVersionLabel extends StatelessWidget {
  /// Creates the build-version footer.
  const BuildVersionLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Bygg: ${BuildInfo.label}',
      child: Text(
        BuildInfo.label,
        key: buildVersionKey,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
