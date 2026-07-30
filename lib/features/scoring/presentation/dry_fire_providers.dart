// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/scoring/data/dry_fire_repository.dart';
import 'package:treffpunkt/features/scoring/data/dry_fire_store.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_weapon.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

/// The app's [DryFireStore] for offline persistence of the log (spec 0161).
///
/// Defaults to an in-memory store so tests and a fresh app never touch real
/// storage; `main()` overrides it with the `shared_preferences`-backed store,
/// mirroring [sessionStoreProvider].
final dryFireStoreProvider = Provider<DryFireStore>(
  (ref) => InMemoryDryFireStore(),
);

/// The app's [DryFireRepository] for account sync of the log (spec 0162).
///
/// Defaults to an in-memory repository so tests and the integration harness
/// never reach a real backend; `main()` overrides it with the Supabase-backed
/// repository, mirroring [sessionRepositoryProvider].
final dryFireRepositoryProvider = Provider<DryFireRepository>(
  (ref) => InMemoryDryFireRepository(),
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
/// shooter registers new ones (spec 0161), backed up to and merged with the
/// account when signed in (spec 0162).
///
/// An [AsyncNotifier] so the initial load is surfaced as loading/data and a
/// registration updates the list in place. Persistence and upload are both
/// best-effort — neither a write failure nor an unreachable backend breaks the
/// in-memory state (the upload queue does the same).
class DryFireLog extends AsyncNotifier<List<DryFireEntry>> {
  // Serializes sync and delete so a background sync can't interleave with — and
  // clobber — a delete (e.g. re-adding an entry the user just removed because
  // its `list()` was issued before the delete reached the account).
  Future<void> _tail = Future<void>.value();

  Future<void> _serial(Future<void> Function() task) {
    final run = _tail.then((_) => task());
    _tail = run.then((_) {}, onError: (_) {});
    return run;
  }

  @override
  Future<List<DryFireEntry>> build() async {
    // Re-sync on a transition into signed-in: entries logged while signed out
    // get backed up, and another device's entries are merged in.
    ref.listen(authStateChangesProvider, (previous, next) {
      if (previous?.value is! SignedIn && next.value is SignedIn) {
        unawaited(sync());
      }
    });
    final local = await _load();
    // Show the local log instantly; merge the account's entries in the
    // background so the card is never blocked on the network.
    if (_isSignedIn()) unawaited(sync());
    return local;
  }

  /// Records a bout of [triggerPulls] avtrekk with [weapon] on [discipline]
  /// (spec 0165).
  ///
  /// A non-positive count is rejected (no entry is added), matching the
  /// presentation-layer validation; the id comes from
  /// [sessionIdGeneratorProvider] and the time from [dryFireClockProvider].
  /// When signed in, the new entry is also uploaded (best-effort).
  Future<void> register(
    DryFireWeapon weapon,
    DryFireDiscipline discipline,
    int triggerPulls,
  ) async {
    if (triggerPulls <= 0) return;
    final entry = DryFireEntry(
      id: ref.read(sessionIdGeneratorProvider)(),
      recordedAt: ref.read(dryFireClockProvider)(),
      discipline: discipline,
      triggerPulls: triggerPulls,
      weapon: weapon,
    );
    final current = state.value ?? await _load();
    final next = <DryFireEntry>[...current, entry];
    state = AsyncData<List<DryFireEntry>>(next);
    await _persist(next);
    if (_isSignedIn()) {
      await ref.read(dryFireRepositoryProvider).upload(<DryFireEntry>[entry]);
    }
  }

  /// Removes the entry with [id] from the log (spec 0163).
  ///
  /// When signed in, the account row is deleted first (it may throw
  /// [DryFireSyncException], leaving the log intact so the caller can surface
  /// the failure); then the entry is removed from state and persisted.
  Future<void> delete(String id) => _serial(() async {
    if (_isSignedIn()) {
      await ref.read(dryFireRepositoryProvider).deleteById(id);
    }
    final current = state.value ?? await _load();
    final next = current.where((entry) => entry.id != id).toList();
    state = AsyncData<List<DryFireEntry>>(next);
    await _persist(next);
  });

  /// Backs up the local entries and merges the account's entries into the log
  /// (spec 0162); best-effort and only when signed in.
  ///
  /// Uploads every local entry (idempotent — this backs up anything logged
  /// while signed out), then lists the account's entries and unions them with
  /// the local ones by id. A failed list leaves the local log in place, so an
  /// unreachable backend never empties the card.
  Future<void> sync() => _serial(() async {
    if (!_isSignedIn()) return;
    final repository = ref.read(dryFireRepositoryProvider);
    final local = state.value ?? await _load();
    await repository.upload(local);
    try {
      final remote = await repository.list();
      // Merge against the *current* state, not the snapshot taken before the
      // network round-trip, so a register that landed meanwhile is kept.
      final base = state.value ?? local;
      final merged = _mergeById(base, remote);
      state = AsyncData<List<DryFireEntry>>(merged);
      await _persist(merged);
    } on DryFireSyncException catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to sync the dry-fire log: $error');
      }
    }
  });

  /// Unions [local] and [remote] by id (a shared id is the same entry), newest
  /// first.
  List<DryFireEntry> _mergeById(
    List<DryFireEntry> local,
    List<DryFireEntry> remote,
  ) {
    final byId = <String, DryFireEntry>{};
    for (final entry in <DryFireEntry>[...local, ...remote]) {
      byId[entry.id] = entry;
    }
    return byId.values.toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  bool _isSignedIn() {
    try {
      return ref.read(authStateChangesProvider).value is SignedIn;
    } on Object {
      return false;
    }
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

/// The app's dry-fire log (spec 0161, spec 0162).
final dryFireLogProvider =
    AsyncNotifierProvider<DryFireLog, List<DryFireEntry>>(DryFireLog.new);
