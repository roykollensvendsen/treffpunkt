// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/settings/data/theme_mode_store.dart';

/// The app's [ThemeModeStore] for persisting the chosen theme (spec 0030).
///
/// Defaults to an in-memory store so tests and a fresh app never touch real
/// storage; `main()` overrides it with the `shared_preferences`-backed store.
final themeModeStoreProvider = Provider<ThemeModeStore>(
  (ref) => InMemoryThemeModeStore(),
);

/// The theme mode loaded from the store at launch, seeding [ThemeModeNotifier].
///
/// `main()` reads the saved choice once (`shared_preferences` is already
/// awaited there) and overrides this so the notifier starts on the right theme
/// without an async `build` and without a first-frame flash of the wrong theme.
/// Defaults to [ThemeMode.system], so a fresh app and every test follow the
/// system/browser theme unless a choice was saved.
final initialThemeModeProvider = Provider<ThemeMode>(
  (ref) => ThemeMode.system,
);

/// The shooter's chosen theme mode, persisted locally so it survives a restart
/// (spec 0030).
///
/// The initial state is seeded from [initialThemeModeProvider] (loaded at
/// launch); [select] updates the state and writes it back through
/// [themeModeStoreProvider]. Loading is done eagerly in `main()` rather than in
/// `build`, so the notifier stays synchronous and tests never touch real I/O.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(initialThemeModeProvider);

  /// Chooses [mode] (system / light / dark) and persists the choice.
  void select(ThemeMode mode) {
    state = mode;
    _persist();
  }

  void _persist() {
    final write = ref.read(themeModeStoreProvider).save(state);
    // Persistence is best-effort and off the happy path (losing one save is not
    // fatal — the in-memory choice is the source of truth this run), but a
    // silent failure would be undiagnosable, so surface it in debug builds.
    unawaited(
      write.catchError((Object error, StackTrace stackTrace) {
        if (!kReleaseMode) {
          debugPrint('Failed to persist the theme mode: $error');
        }
      }),
    );
  }
}

/// The shooter's chosen theme mode (defaults to following the system theme).
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
