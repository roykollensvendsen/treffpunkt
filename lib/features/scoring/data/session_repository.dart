// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/scoring/domain/session_record.dart';

/// Uploads a completed session to the shooter's account (spec 0024).
///
/// The rest of the app depends on this interface, not a concrete backend —
/// mirroring `AuthRepository` and `SessionStore` — so the auto-upload flow is
/// testable with an in-memory fake and never reaches a real Supabase. The
/// concrete `SupabaseSessionRepository` is the only file importing
/// `supabase_flutter` (ADR-0017).
///
// The single method is intentional: this seam exists for the fake (ADR-0017),
// so the one-member-abstract shape is the point, not a smell.
// ignore: one_member_abstracts
abstract interface class SessionRepository {
  /// Uploads [record] to the backend, keyed by its [SessionRecord.id].
  ///
  /// Implementations are **idempotent by id**: re-uploading a record with the
  /// same id overwrites in place rather than creating a duplicate. The upload
  /// is best-effort — a real backend swallows transport errors (ADR-0017) — so
  /// callers may fire-and-forget.
  Future<void> upload(SessionRecord record);
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
}
