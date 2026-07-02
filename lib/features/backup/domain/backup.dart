// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/scoring/domain/personal_best.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/weapons/data/weapons_snapshot.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';

/// Everything a shooter can take with them (spec 0106): the ring sessions,
/// the felt rounds, the personal weapons, the record baselines (spec 0102)
/// and the default place. Pure Dart, so the blob is unit-testable.
@immutable
class Backup {
  /// Creates a backup aggregate.
  const Backup({
    required this.sessions,
    required this.feltRounds,
    required this.weapons,
    required this.records,
    required this.defaultPlace,
  });

  /// The ring sessions (pending and synced, merged).
  final List<SessionRecord> sessions;

  /// The finished felt rounds (local and synced, merged).
  final List<FeltSessionRecord> feltRounds;

  /// The personal weapons.
  final List<Weapon> weapons;

  /// The personal-record baselines, keyed by exercise (spec 0102).
  final Map<String, ExerciseResult> records;

  /// The default place, or null when none is set.
  final String? defaultPlace;
}

/// Builds the versioned backup blob for [backup] (spec 0106).
Map<String, dynamic> buildBackupJson(
  Backup backup, {
  required DateTime exportedAt,
}) => <String, dynamic>{
  'app': 'treffpunkt',
  'kind': 'backup',
  'version': 1,
  'exportedAt': exportedAt.toIso8601String(),
  'sessions': [for (final record in backup.sessions) record.toJson()],
  'feltRounds': [for (final round in backup.feltRounds) round.toJson()],
  'weapons': WeaponsSnapshot.toJson(backup.weapons),
  'records': <String, dynamic>{
    for (final entry in backup.records.entries)
      entry.key: <String, int>{
        'points': entry.value.points,
        'inner': entry.value.inner,
      },
  },
  if (backup.defaultPlace != null) 'defaultPlace': backup.defaultPlace,
};

/// Parses a backup blob produced by [buildBackupJson].
///
/// Throws a [FormatException] when [json] is not a Treffpunkt backup (wrong
/// `kind` or missing `version`); within a recognised blob it is tolerant —
/// missing sections parse as empty and an unreadable entry is skipped, so
/// one broken record can never block a restore.
Backup parseBackupJson(Map<String, dynamic> json) {
  if (json['kind'] != 'backup' || json['version'] is! int) {
    throw const FormatException('Not a Treffpunkt backup file.');
  }
  return Backup(
    sessions: _list(json['sessions'], SessionRecord.fromJson),
    feltRounds: _list(json['feltRounds'], FeltSessionRecord.fromJson),
    weapons: _list(
      json['weapons'],
      (item) => WeaponsSnapshot.fromJson([item]).single,
    ),
    records: _records(json['records']),
    defaultPlace: json['defaultPlace'] as String?,
  );
}

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is! List) return const [];
  final items = <T>[];
  for (final entry in raw) {
    try {
      items.add(fromJson(entry as Map<String, dynamic>));
    } on Object {
      // A broken entry is skipped, never fatal.
    }
  }
  return items;
}

Map<String, ExerciseResult> _records(Object? raw) {
  if (raw is! Map<String, dynamic>) return const {};
  final records = <String, ExerciseResult>{};
  for (final entry in raw.entries) {
    try {
      final value = entry.value as Map<String, dynamic>;
      records[entry.key] = (
        points: value['points'] as int,
        inner: value['inner'] as int,
      );
    } on Object {
      // Skipped, never fatal.
    }
  }
  return records;
}

/// The outcome of merging a backup into what is already on the device
/// (spec 0106): the merged data to save, and how much of it was new.
@immutable
class BackupMergeResult {
  /// Creates a merge result.
  const BackupMergeResult({
    required this.sessions,
    required this.feltRounds,
    required this.weapons,
    required this.records,
    required this.defaultPlace,
    required this.newSessions,
    required this.newFeltRounds,
    required this.newWeapons,
    required this.newRecords,
  });

  /// The merged ring sessions.
  final List<SessionRecord> sessions;

  /// The merged felt rounds.
  final List<FeltSessionRecord> feltRounds;

  /// The merged weapons.
  final List<Weapon> weapons;

  /// The merged record baselines.
  final Map<String, ExerciseResult> records;

  /// The resulting default place.
  final String? defaultPlace;

  /// How many ring sessions the backup added.
  final int newSessions;

  /// How many felt rounds the backup added.
  final int newFeltRounds;

  /// How many weapons the backup added.
  final int newWeapons;

  /// How many record baselines the backup added.
  final int newRecords;
}

/// Merges [incoming] into the existing data — additive, never destructive
/// (spec 0106): sessions and felt rounds are keyed by id and the existing
/// copy wins; weapons merge by name; record baselines keep the
/// lexicographically best result (spec 0102); the default place is only
/// taken when none is set.
BackupMergeResult mergeBackup({
  required Backup incoming,
  required List<SessionRecord> sessions,
  required List<FeltSessionRecord> feltRounds,
  required List<Weapon> weapons,
  required Map<String, ExerciseResult> records,
  required String? defaultPlace,
}) {
  final mergedSessions = [...sessions];
  final sessionIds = {for (final record in sessions) record.id};
  var newSessions = 0;
  for (final record in incoming.sessions) {
    if (sessionIds.add(record.id)) {
      mergedSessions.add(record);
      newSessions++;
    }
  }

  final mergedRounds = [...feltRounds];
  final roundIds = {for (final round in feltRounds) round.id};
  var newFeltRounds = 0;
  for (final round in incoming.feltRounds) {
    if (roundIds.add(round.id)) {
      mergedRounds.add(round);
      newFeltRounds++;
    }
  }

  final mergedWeapons = [...weapons];
  final weaponNames = {for (final weapon in weapons) weapon.name};
  var newWeapons = 0;
  for (final weapon in incoming.weapons) {
    if (weaponNames.add(weapon.name)) {
      mergedWeapons.add(weapon);
      newWeapons++;
    }
  }

  final mergedRecords = {...records};
  var newRecords = 0;
  for (final entry in incoming.records.entries) {
    final existing = mergedRecords[entry.key];
    if (existing == null) {
      mergedRecords[entry.key] = entry.value;
      newRecords++;
    } else {
      mergedRecords[entry.key] = bestResult([existing, entry.value])!;
    }
  }

  return BackupMergeResult(
    sessions: mergedSessions,
    feltRounds: mergedRounds,
    weapons: mergedWeapons,
    records: mergedRecords,
    defaultPlace: defaultPlace ?? incoming.defaultPlace,
    newSessions: newSessions,
    newFeltRounds: newFeltRounds,
    newWeapons: newWeapons,
    newRecords: newRecords,
  );
}
