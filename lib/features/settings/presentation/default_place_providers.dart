// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/settings/data/default_place_store.dart';

/// The app's [DefaultPlaceStore] for persisting the default place (spec
/// 0102). Defaults to an in-memory store so tests and a fresh app never
/// touch real storage; `main()` overrides it with the
/// `shared_preferences`-backed store.
final defaultPlaceStoreProvider = Provider<DefaultPlaceStore>(
  (ref) => InMemoryDefaultPlaceStore(),
);

/// The default place loaded from the store at launch, seeding
/// [DefaultPlaceNotifier]. `main()` reads the saved value once (prefs is
/// already awaited there) and overrides this, so the notifier stays
/// synchronous. Defaults to null (no default place).
final initialDefaultPlaceProvider = Provider<String?>((ref) => null);

/// The shooter's default place (spec 0102) — pre-fills the session-setup
/// form's place field. Persisted locally so it survives a restart.
class DefaultPlaceNotifier extends Notifier<String?> {
  @override
  String? build() => ref.read(initialDefaultPlaceProvider);

  /// Saves [place]; null or blank clears the default.
  void set(String? place) {
    final trimmed = place?.trim();
    state = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    final write = ref.read(defaultPlaceStoreProvider).save(state);
    // Best-effort persistence, as for the theme mode: the in-memory value is
    // the source of truth this run, but a silent failure would be
    // undiagnosable, so surface it in debug builds.
    unawaited(
      write.catchError((Object error) {
        if (!kReleaseMode) {
          debugPrint('Failed to persist the default place: $error');
        }
      }),
    );
  }
}

/// The shooter's default place, or null when none is set.
final defaultPlaceProvider = NotifierProvider<DefaultPlaceNotifier, String?>(
  DefaultPlaceNotifier.new,
);
