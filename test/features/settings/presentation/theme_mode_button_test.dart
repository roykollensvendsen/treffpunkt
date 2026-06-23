// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the theme-mode button (spec 0030): it offers System / Lyst /
// Mørkt, defaults to following the system theme, and a selection both switches
// the app's themeMode and persists through the store.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/app_theme.dart';
import 'package:treffpunkt/features/settings/data/theme_mode_store.dart';
import 'package:treffpunkt/features/settings/presentation/theme_mode_button.dart';
import 'package:treffpunkt/features/settings/presentation/theme_providers.dart';

Widget _app(ThemeModeStore store) {
  return ProviderScope(
    overrides: [themeModeStoreProvider.overrideWithValue(store)],
    child: const _Harness(),
  );
}

/// A minimal app whose themeMode is driven by the provider, with the button in
/// its app bar — the real wiring app.dart uses.
class _Harness extends ConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ref.watch(themeModeProvider),
      home: Scaffold(appBar: AppBar(actions: const [ThemeModeButton()])),
    );
  }
}

void main() {
  testWidgets('defaults to following the system theme', (tester) async {
    await tester.pumpWidget(_app(InMemoryThemeModeStore()));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ThemeModeButton)),
    );
    expect(container.read(themeModeProvider), ThemeMode.system);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
  });

  testWidgets('offers System / Lyst / Mørkt', (tester) async {
    await tester.pumpWidget(_app(InMemoryThemeModeStore()));

    await tester.tap(find.byKey(themeModeButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(themeModeOption(ThemeMode.system)), findsOneWidget);
    expect(find.byKey(themeModeOption(ThemeMode.light)), findsOneWidget);
    expect(find.byKey(themeModeOption(ThemeMode.dark)), findsOneWidget);
    expect(find.text('Mørkt'), findsOneWidget);
  });

  testWidgets('selecting Mørkt switches the app to dark and persists', (
    tester,
  ) async {
    final store = InMemoryThemeModeStore();
    await tester.pumpWidget(_app(store));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ThemeModeButton)),
    );

    await tester.tap(find.byKey(themeModeButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(themeModeOption(ThemeMode.dark)));
    await tester.pumpAndSettle();

    // The choice updates the provider and the app's themeMode...
    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    // ...and persists so it survives a restart.
    expect(await store.load(), ThemeMode.dark);
  });
}
