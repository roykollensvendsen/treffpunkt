// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';

/// A competition: a contest that **fixes a program** at creation, so every
/// entrant shoots the same structure (spec 0010 / ROADMAP increment 2).
///
/// Owned by its creator ([ownerId]); [isPublic] decides whether any signed-in
/// user may read it or only the owner and invited members. The [id] is
/// client-generated (a stable uuid) so creating is an idempotent upsert.
@immutable
class Competition {
  /// Creates a competition.
  const Competition({
    required this.id,
    required this.name,
    required this.program,
    required this.ownerId,
    this.isPublic = false,
    this.createdAt,
    this.eventDate,
  });

  /// Reads a competition from a `competitions` row (snake_case columns).
  factory Competition.fromJson(Map<String, dynamic> json) {
    final createdAt = json['created_at'] as String?;
    final eventDate = json['event_date'] as String?;
    return Competition(
      id: json['id'] as String,
      name: json['name'] as String,
      program: json['program'] as String,
      ownerId: json['owner_id'] as String,
      isPublic: (json['is_public'] as bool?) ?? false,
      createdAt: createdAt == null ? null : DateTime.parse(createdAt),
      eventDate: eventDate == null ? null : DateTime.parse(eventDate),
    );
  }

  /// Client-generated stable id (the upsert key).
  final String id;

  /// The competition's display name.
  final String name;

  /// The fixed program name (resolved via `ProgramCatalogue.byName`).
  final String program;

  /// The auth user id of the creator/owner.
  final String ownerId;

  /// Whether any signed-in user may read it (`true`) or only owner + members.
  final bool isPublic;

  /// When the row was created server-side, or `null` before it is read back.
  final DateTime? createdAt;

  /// The date the competition is held (date-only), or `null` when none is set.
  /// Used to browse/filter the list by a calendar (spec 0057).
  final DateTime? eventDate;

  /// The columns a client sets when creating a competition.
  ///
  /// `owner_id` is intentionally omitted — it defaults to `auth.uid()` in the
  /// database, so the client cannot create a competition owned by someone else.
  Map<String, dynamic> toInsertJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'program': program,
    'is_public': isPublic,
    if (eventDate != null) 'event_date': _formatDate(eventDate!),
  };

  @override
  bool operator ==(Object other) =>
      other is Competition &&
      other.id == id &&
      other.name == name &&
      other.program == program &&
      other.ownerId == ownerId &&
      other.isPublic == isPublic &&
      other.createdAt == createdAt &&
      other.eventDate == eventDate;

  @override
  int get hashCode =>
      Object.hash(id, name, program, ownerId, isPublic, createdAt, eventDate);
}

/// Formats a date-only [date] as `YYYY-MM-DD` for a Postgres `date` column.
String _formatDate(DateTime date) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-'
      '${two(date.month)}-${two(date.day)}';
}
