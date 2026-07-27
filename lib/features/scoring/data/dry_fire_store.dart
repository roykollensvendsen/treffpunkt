// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:shared_preferences/shared_preferences.dart';
import 'package:treffpunkt/core/data/prefs_store.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';

/// Local storage for the dry-fire log — the list of recorded bouts (spec 0161).
///
/// The rest of the app depends on this interface, not a concrete engine,
/// mirroring `PendingUploadsStore` (spec 0025), so the log is testable with an
/// in-memory fake and never touches real storage.
abstract interface class DryFireStore {
  /// The recorded entries in stored order, or an empty list when none are
  /// stored.
  Future<List<DryFireEntry>> load();

  /// Persists [entries] as the whole log, replacing any previous one.
  Future<void> save(List<DryFireEntry> entries);
}

/// A [DryFireStore] that keeps the log in memory only.
///
/// The default binding and the test fake: it never touches the platform, so
/// widget and unit tests run with no real I/O. A restart is simulated in tests
/// by reusing the same instance across a fresh log.
class InMemoryDryFireStore implements DryFireStore {
  /// Creates an empty in-memory store.
  InMemoryDryFireStore();

  List<DryFireEntry> _entries = <DryFireEntry>[];

  @override
  Future<List<DryFireEntry>> load() async =>
      List<DryFireEntry>.unmodifiable(_entries);

  @override
  Future<void> save(List<DryFireEntry> entries) async =>
      _entries = List<DryFireEntry>.of(entries);
}

/// A [DryFireStore] backed by `shared_preferences` (web + mobile).
///
/// Delegates to a [PrefsJsonListStore]: the whole log lives as one JSON array
/// under one key (ADR-0016), and anything unreadable loads as the empty list,
/// like never-saved. Tests drive it with
/// `SharedPreferences.setMockInitialValues`, so no real platform storage is
/// touched.
class SharedPreferencesDryFireStore implements DryFireStore {
  /// Creates a store reading and writing through [prefs].
  SharedPreferencesDryFireStore(SharedPreferences prefs)
    : _store = PrefsJsonListStore<DryFireEntry>(
        prefs,
        key: 'dry_fire_log',
        toJson: (entry) => entry.toJson(),
        fromJson: (json) =>
            DryFireEntry.fromJson(json! as Map<String, dynamic>),
      );

  final PrefsJsonListStore<DryFireEntry> _store;

  @override
  Future<List<DryFireEntry>> load() => _store.load();

  @override
  Future<void> save(List<DryFireEntry> entries) => _store.save(entries);
}
