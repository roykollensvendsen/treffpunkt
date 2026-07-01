// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:treffpunkt/features/felt/data/felt_session_repository.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';

/// A [FeltSessionRepository] backed by Supabase (spec 0083): one row per
/// finished round in `felt_sessions`, owner-scoped by RLS. Upload is
/// best-effort (swallows + logs in debug); a failed [list] throws
/// [FeltSyncException] so "Mine økter" can note it without hiding the local
/// rounds. Mirrors the ring `SupabaseSessionRepository`.
final class SupabaseFeltSessionRepository implements FeltSessionRepository {
  /// Creates a repository over [_client].
  SupabaseFeltSessionRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'felt_sessions';

  @override
  Future<void> upload(FeltSessionRecord record) async {
    try {
      await _client.from(_table).upsert(<String, dynamic>{
        'id': record.id,
        'captured_at': record.capturedAt.toIso8601String(),
        'group_name': record.session.group.name,
        'points': record.points,
        'payload': record.session.toJson(),
      }, onConflict: 'id');
    } on Object catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to upload the felt round: $error');
      }
    }
  }

  @override
  Future<List<FeltSessionRecord>> list() async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .order('captured_at', ascending: false);
      return <FeltSessionRecord>[for (final row in rows) _fromRow(row)];
    } on Object catch (error) {
      if (!kReleaseMode) {
        debugPrint('Failed to list the felt rounds: $error');
      }
      throw FeltSyncException(error);
    }
  }

  FeltSessionRecord _fromRow(Map<String, dynamic> row) => FeltSessionRecord(
    id: row['id'] as String,
    capturedAt: DateTime.parse(row['captured_at'] as String),
    session: FeltSessionSnapshot.fromJson(
      row['payload'] as Map<String, dynamic>,
    ),
  );
}
