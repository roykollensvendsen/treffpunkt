// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/scoring/data/personal_records_store.dart';
import 'package:treffpunkt/features/scoring/domain/personal_best.dart';

/// The record key of the felt course for [group] (spec 0102): records are
/// per group, like the «Ny pers!» comparison (spec 0101).
String feltRecordKey(FeltShooterGroup group) =>
    'NorgesFelt-løype 2026 · ${group.label}';

/// The app's [PersonalRecordsStore] for the manual baselines (spec 0102).
/// Defaults to an in-memory store so tests and a fresh app never touch real
/// storage; `main()` overrides it with the `shared_preferences`-backed one.
final personalRecordsStoreProvider = Provider<PersonalRecordsStore>(
  (ref) => InMemoryPersonalRecordsStore(),
);

/// The baselines loaded from the store at launch, seeding
/// [PersonalRecordsNotifier]. `main()` reads the saved map once (prefs is
/// already awaited there) and overrides this, so the notifier stays
/// synchronous. Defaults to no baselines.
final initialPersonalRecordsProvider = Provider<Map<String, ExerciseResult>>(
  (ref) => const {},
);

/// The shooter's manual personal-record baselines (spec 0102), keyed by
/// exercise — a catalogue program name, or [feltRecordKey] per felt group.
/// Persisted locally so they survive a restart.
class PersonalRecordsNotifier extends Notifier<Map<String, ExerciseResult>> {
  @override
  Map<String, ExerciseResult> build() =>
      ref.read(initialPersonalRecordsProvider);

  /// Saves the baseline [result] for [exercise].
  void setRecord(String exercise, ExerciseResult result) {
    state = {...state, exercise: result};
    _persist();
  }

  /// Removes the baseline for [exercise].
  void removeRecord(String exercise) {
    state = {...state}..remove(exercise);
    _persist();
  }

  void _persist() {
    final write = ref.read(personalRecordsStoreProvider).save(state);
    // Best-effort persistence, as for the theme mode: the in-memory map is
    // the source of truth this run, but a silent failure would be
    // undiagnosable, so surface it in debug builds.
    unawaited(
      write.catchError((Object error) {
        if (!kReleaseMode) {
          debugPrint('Failed to persist the personal records: $error');
        }
      }),
    );
  }
}

/// The manual personal-record baselines, keyed by exercise.
final personalRecordsProvider =
    NotifierProvider<PersonalRecordsNotifier, Map<String, ExerciseResult>>(
      PersonalRecordsNotifier.new,
    );
