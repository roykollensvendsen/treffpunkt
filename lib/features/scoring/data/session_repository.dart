// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/core/data/sync_exception.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';

/// Thrown by [SessionRepository.list] when the synced read fails — a missing
/// table, denied permission, a dropped connection or a timeout (spec 0029).
///
/// It lets a caller tell a genuine failure apart from an empty account, so the
/// "My sessions" screen can show a non-blocking "couldn't reach the cloud"
/// notice instead of a failure looking like "no sessions yet".
/// [SessionRepository.upload] does **not** throw this — it stays silent
/// (ADR-0017) so it never blocks recording.
class SessionSyncException extends SyncException {
  /// Creates an exception wrapping the underlying [cause].
  const SessionSyncException(super.cause);
}

/// Uploads a completed session to the shooter's account (spec 0024).
///
/// The rest of the app depends on this interface, not a concrete backend —
/// mirroring `AuthRepository` and `SessionStore` — so the auto-upload flow is
/// testable with an in-memory fake and never reaches a real Supabase. The
/// concrete `SupabaseSessionRepository` is the only file importing
/// `supabase_flutter` (ADR-0017).
///
abstract interface class SessionRepository {
  /// Uploads [record] to the backend, keyed by its [SessionRecord.id].
  ///
  /// Implementations are **idempotent by id**: re-uploading a record with the
  /// same id overwrites in place rather than creating a duplicate. The upload
  /// is best-effort — a real backend swallows transport errors (ADR-0017) — so
  /// callers may fire-and-forget.
  Future<void> upload(SessionRecord record);

  /// The shooter's synced sessions, most recent first (spec 0026).
  ///
  /// Reads back the records previously uploaded to the account, ordered by when
  /// they were shot (newest first). A successful read of an empty account
  /// returns `const []`.
  ///
  /// Unlike [upload], the read is **not** silent: it throws a
  /// [SessionSyncException] when the cloud read fails — a missing table, denied
  /// permission, a dropped connection or a timeout (spec 0029). The failure is
  /// then distinct from an empty account, so the "My sessions" screen surfaces
  /// a non-blocking notice (and still shows the local sessions) rather than a
  /// failure silently looking like "no sessions yet".
  Future<List<SessionRecord>> list();

  /// Deletes the session [id] from the account (spec 0033).
  ///
  /// Unlike [upload], this is a deliberate action the user waits on, so it
  /// **throws** [SessionSyncException] on failure (a dropped connection, denied
  /// permission). Deleting an id that is not there is a no-op.
  Future<void> deleteById(String id);
}

/// A [SessionRepository] that keeps uploaded records in memory only.
///
/// The default binding and the test fake: it never touches the network, so unit
/// and widget tests run with no real I/O. Records are stored by id, so a second
/// upload of the same id replaces the first (idempotent, like the real upsert).
class InMemorySessionRepository implements SessionRepository {
  /// Creates an empty in-memory repository.
  InMemorySessionRepository();

  final Map<String, SessionRecord> _byId = <String, SessionRecord>{};

  /// The records uploaded so far, one per distinct id, in insertion order.
  List<SessionRecord> get uploads => List<SessionRecord>.unmodifiable(
    _byId.values,
  );

  @override
  Future<void> upload(SessionRecord record) async {
    _byId[record.id] = record;
  }

  @override
  Future<List<SessionRecord>> list() async => uploads;

  @override
  Future<void> deleteById(String id) async {
    _byId.remove(id);
  }
}
