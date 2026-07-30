// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:treffpunkt/core/data/sync_exception.dart';
import 'package:treffpunkt/core/time/wire_time.dart';
import 'package:treffpunkt/features/scoring/data/dry_fire_repository.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_weapon.dart';

/// A [DryFireRepository] backed by Supabase (spec 0162): one row per recorded
/// bout in `dry_fire_entries`, owner-scoped by RLS. Upload is best-effort
/// (swallows + logs in debug); a failed [list] throws [DryFireSyncException]
/// so the card can keep showing the local log. Mirrors the felt
/// `SupabaseFeltSessionRepository`.
final class SupabaseDryFireRepository implements DryFireRepository {
  /// Creates a repository over [_client].
  SupabaseDryFireRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'dry_fire_entries';

  @override
  Future<void> upload(List<DryFireEntry> entries) async {
    if (entries.isEmpty) return;
    try {
      await _client
          .from(_table)
          .upsert(entries.map(rowFor).toList(), onConflict: 'id');
    } on Object catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to upload the dry-fire entries: $error');
      }
    }
  }

  /// The upsert row for [entry] (spec 0162, spec 0165).
  ///
  /// Extracted so the column contract — including the nullable `weapon` column
  /// (`null` for a legacy entry) — is unit-testable without a live client.
  @visibleForTesting
  static Map<String, dynamic> rowFor(DryFireEntry entry) => <String, dynamic>{
    'id': entry.id,
    'recorded_at': formatWireTimeUtc(entry.recordedAt),
    'discipline': entry.discipline.wireName,
    'trigger_pulls': entry.triggerPulls,
    'weapon': entry.weapon?.wireName,
  };

  /// The entry for a Supabase [row] (spec 0162, spec 0165).
  ///
  /// A row with no `weapon`, a `null` weapon, or an unknown value all map to
  /// «no weapon» — the same degrade-not-throw rule as `DryFireEntry.fromJson`,
  /// so a pre-feature or foreign row never breaks `list()`.
  @visibleForTesting
  static DryFireEntry entryFromRow(Map<String, dynamic> row) => DryFireEntry(
    id: row['id'] as String,
    recordedAt: parseWireTime(row['recorded_at'] as String),
    discipline: DryFireDiscipline.fromWireName(row['discipline'] as String),
    triggerPulls: row['trigger_pulls'] as int,
    weapon: switch (row['weapon']) {
      final String name => DryFireWeapon.fromWireName(name),
      _ => null,
    },
  );

  @override
  Future<List<DryFireEntry>> list() => guardSync(
    () async {
      final rows = await _client
          .from(_table)
          .select()
          .order('recorded_at', ascending: false);
      return <DryFireEntry>[for (final row in rows) entryFromRow(row)];
    },
    debugLabel: 'Failed to list the dry-fire entries',
    wrap: DryFireSyncException.new,
  );

  @override
  Future<void> deleteById(String id) => guardSync(
    () async {
      await _client.from(_table).delete().eq('id', id);
    },
    debugLabel: 'Failed to delete the dry-fire entry',
    wrap: DryFireSyncException.new,
  );
}
