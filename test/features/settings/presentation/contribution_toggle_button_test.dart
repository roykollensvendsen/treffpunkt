// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the contribution toggle (spec 0041): it reflects the consent
// state and turning it off flips the provider.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/settings/presentation/contribution_providers.dart';
import 'package:treffpunkt/features/settings/presentation/contribution_toggle_button.dart';

Widget _app(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: const MaterialApp(
    home: Scaffold(body: Center(child: ContributionToggleButton())),
  ),
);

void main() {
  testWidgets('turning the toggle off flips the consent provider', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));

    expect(container.read(contributionConsentProvider).enabled, isTrue);

    await tester.tap(find.byKey(contributionToggleKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(contributionToggleOption(enabled: false)));
    await tester.pumpAndSettle();

    expect(container.read(contributionConsentProvider).enabled, isFalse);
  });
}
