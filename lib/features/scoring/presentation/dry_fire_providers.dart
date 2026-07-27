// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/data/dry_fire_store.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

/// The app's [DryFireStore] for offline persistence of the log (spec 0161).
///
/// Defaults to an in-memory store so tests and a fresh app never touch real
/// storage; `main()` overrides it with the `shared_preferences`-backed store,
/// mirroring [sessionStoreProvider].
final dryFireStoreProvider = Provider<DryFireStore>(
  (ref) => InMemoryDryFireStore(),
);

/// The clock the dry-fire log stamps entries with (spec 0161).
///
/// Defaults to `DateTime.now`; overridden in tests with a fixed clock so the
/// recorded time is deterministic. Injected here in the presentation layer, not
/// read by the domain, so the entry type stays pure (as ids are, ADR-0017).
final dryFireClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The recorded dry-fire bouts, loaded from the store and appended to as the
/// shooter registers new ones (spec 0161).
///
/// An [AsyncNotifier] so the initial load is surfaced as loading/data and a
/// registration updates the list in place. Persistence is best-effort — a write
/// failure never breaks the in-memory state (the upload queue does the same).
class DryFireLog extends AsyncNotifier<List<DryFireEntry>> {
  @override
  Future<List<DryFireEntry>> build() => _load();

  /// Records a bout of [triggerPulls] avtrekk on [discipline].
  ///
  /// A non-positive count is rejected (no entry is added), matching the
  /// presentation-layer validation; the id comes from
  /// [sessionIdGeneratorProvider] and the time from [dryFireClockProvider].
  Future<void> register(
    DryFireDiscipline discipline,
    int triggerPulls,
  ) async {
    if (triggerPulls <= 0) return;
    final entry = DryFireEntry(
      id: ref.read(sessionIdGeneratorProvider)(),
      recordedAt: ref.read(dryFireClockProvider)(),
      discipline: discipline,
      triggerPulls: triggerPulls,
    );
    final current = state.value ?? await _load();
    final next = <DryFireEntry>[...current, entry];
    state = AsyncData<List<DryFireEntry>>(next);
    await _persist(next);
  }

  /// Loads the persisted log; an unreadable store yields an empty list rather
  /// than breaking startup.
  Future<List<DryFireEntry>> _load() async {
    try {
      return await ref.read(dryFireStoreProvider).load();
    } on Object catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to load the dry-fire log: $error');
      }
      return <DryFireEntry>[];
    }
  }

  /// Persists [entries]; best-effort, so a write failure never breaks the log
  /// (the in-memory state is authoritative this run).
  Future<void> _persist(List<DryFireEntry> entries) async {
    try {
      await ref.read(dryFireStoreProvider).save(entries);
    } on Object catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to persist the dry-fire log: $error');
      }
    }
  }
}

/// The app's dry-fire log (spec 0161).
final dryFireLogProvider =
    AsyncNotifierProvider<DryFireLog, List<DryFireEntry>>(DryFireLog.new);
