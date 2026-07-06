// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:treffpunkt/core/data/sync_exception.dart';
import 'package:treffpunkt/core/time/wire_time.dart';
import 'package:treffpunkt/features/scoring/data/session_repository.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';

/// [SessionRepository] backed by Supabase (spec 0024).
///
/// This is the only file (besides `SupabaseAuthRepository`) that imports
/// `supabase_flutter`. Like that one (spec 0003) it is excluded from automated
/// tests — no real credentials — and verified by the manual checklist in spec
/// 0024.
///
/// The upload is an **idempotent upsert** keyed by the record's id (so a retry
/// overwrites the row in place) and is **best-effort: it catches every error
/// and never throws** (ADR-0017), so a missing `sessions` table or a dropped
/// connection cannot crash the app or break the completion flow. `user_id`
/// defaults to `auth.uid()` in the database, so it is not sent from the client.
final class SupabaseSessionRepository implements SessionRepository {
  /// Creates a repository writing through the given Supabase client.
  SupabaseSessionRepository(this._client);

  final SupabaseClient _client;

  /// The owner-only table the migration creates (spec 0024 / ADR-0017).
  static const String _table = 'sessions';

  @override
  Future<void> upload(SessionRecord record) async {
    try {
      await _client.from(_table).upsert(<String, dynamic>{
        'id': record.id,
        'program': record.program,
        'captured_at': formatWireTimeUtc(record.capturedAt),
        'place_label': record.placeLabel,
        'latitude': record.latitude,
        'longitude': record.longitude,
        'weapon_name': record.weaponName,
        'total': record.total,
        'max_total': record.maxTotal,
        'inner_tens': record.innerTens,
        'payload': record.payload,
      }, onConflict: 'id');
    } on Object catch (error) {
      // Best-effort (ADR-0017): losing one upload is not fatal — the local
      // recording is authoritative this run — but a crash would be, and the
      // table may not yet exist in hosted Supabase. Swallow and, in debug,
      // surface so a real failure is diagnosable.
      if (!kReleaseMode) {
        debugPrint('Failed to upload the session record: $error');
      }
    }
  }

  // Surfaces a failure (spec 0029) — unlike [upload], the read throws so a
  // missing table or a dropped connection can show as a non-blocking notice
  // on the "My sessions" screen rather than masquerading as an empty
  // account. In debug, also prints so a real failure is diagnosable.
  @override
  Future<List<SessionRecord>> list() => guardSync(
    () async {
      final rows = await _client
          .from(_table)
          .select()
          .order('captured_at', ascending: false);
      return <SessionRecord>[for (final row in rows) _recordFromRow(row)];
    },
    debugLabel: 'Failed to list the session records',
    wrap: SessionSyncException.new,
  );

  // A deliberate user action (spec 0033) — surfaces failure, unlike the
  // silent best-effort upload (ADR-0017).
  @override
  Future<void> deleteById(String id) => guardSync(
    () async {
      // RLS ("Sessions are deletable by their owner") gates this to the owner's
      // own rows. Deleting a missing id affects no rows and is not an error.
      await _client.from(_table).delete().eq('id', id);
    },
    debugLabel: 'Failed to delete the session record',
    wrap: SessionSyncException.new,
  );

  /// Maps one `sessions` row back to a [SessionRecord] (the inverse of the
  /// upsert map in [upload], using the same snake_case column names).
  static SessionRecord _recordFromRow(Map<String, dynamic> row) {
    return SessionRecord(
      id: row['id'] as String,
      program: row['program'] as String,
      capturedAt: parseWireTimeOrNull(row['captured_at'] as String?),
      placeLabel: row['place_label'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      weaponName: row['weapon_name'] as String?,
      total: (row['total'] as num).toInt(),
      maxTotal: (row['max_total'] as num).toInt(),
      innerTens: (row['inner_tens'] as num).toInt(),
      payload: row['payload'] as Map<String, dynamic>,
    );
  }
}
