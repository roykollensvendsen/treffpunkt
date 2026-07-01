// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/felt/data/felt_history_store.dart';
import 'package:treffpunkt/features/felt/data/felt_session_store.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';

/// The app's felt-session store for save/resume (spec 0081). Defaults to the
/// in-memory store; `main()` overrides it with the `shared_preferences` one.
final feltSessionStoreProvider = Provider<FeltSessionStore>(
  (ref) => InMemoryFeltSessionStore(),
);

/// The saved in-progress felt round read back from the store, or null. Watched
/// by the course preview to show the "Fortsett felt-økt" card (spec 0081).
final feltSavedSessionProvider = FutureProvider<FeltSessionSnapshot?>(
  (ref) => ref.watch(feltSessionStoreProvider).load(),
);

/// The app's store of finished felt rounds (spec 0082). Defaults to in-memory;
/// `main()` overrides it with the `shared_preferences` one.
final feltHistoryStoreProvider = Provider<FeltHistoryStore>(
  (ref) => InMemoryFeltHistoryStore(),
);

/// The finished felt rounds, newest-first, watched by "Mine økter" (spec 0082).
final feltHistoryProvider = FutureProvider<List<FeltSessionRecord>>(
  (ref) => ref.watch(feltHistoryStoreProvider).load(),
);

/// Prepends [record] to the finished-round history and refreshes readers
/// (spec 0082).
Future<void> saveFeltRound(WidgetRef ref, FeltSessionRecord record) async {
  final store = ref.read(feltHistoryStoreProvider);
  final current = await store.load();
  await store.save(<FeltSessionRecord>[record, ...current]);
  ref.invalidate(feltHistoryProvider);
}
