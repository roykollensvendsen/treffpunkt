// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';
import 'package:treffpunkt/core/time/wire_time.dart';

/// The target discipline a dry-fire bout was practised on (spec 0161).
///
/// Dry-fire has no shot to place, so the discipline is a plain label on the
/// entry — the presisjon and duell target faces are not drawn (spec 0161 keeps
/// that to a later increment). Each value carries a Norwegian [label] for
/// display and a stable [wireName] for storage that never changes even if the
/// label does.
enum DryFireDiscipline {
  /// Presisjonsskyting — the precision target.
  presisjon('Presisjon', 'presisjon'),

  /// Duellskyting — the duel target.
  duell('Duell', 'duell');

  const DryFireDiscipline(this.label, this.wireName);

  /// The human-readable name shown in the UI.
  final String label;

  /// The stable storage key; the inverse of [DryFireDiscipline.fromWireName].
  final String wireName;

  /// The discipline whose [wireName] is [name].
  ///
  /// Throws [FormatException] on an unknown name, so a corrupt stored entry
  /// surfaces as an unreadable list (emptied by the store) rather than a silent
  /// wrong value.
  static DryFireDiscipline fromWireName(String name) {
    for (final discipline in DryFireDiscipline.values) {
      if (discipline.wireName == name) return discipline;
    }
    throw FormatException('Unknown dry-fire discipline: $name');
  }
}

/// One recorded dry-fire bout: a discipline and a count of trigger pulls
/// (avtrekk), taken at a moment in time (spec 0161).
///
/// A pure value type. Its [id] and [recordedAt] are supplied by the caller (the
/// presentation layer), not derived here, so the domain stays deterministic and
/// Flutter-free — as ids are for `SessionRecord` (ADR-0017). Round-trips
/// losslessly through [toJson] / [DryFireEntry.fromJson].
@immutable
class DryFireEntry {
  /// Creates an entry with the given [id], [recordedAt], [discipline] and
  /// [triggerPulls].
  const DryFireEntry({
    required this.id,
    required this.recordedAt,
    required this.discipline,
    required this.triggerPulls,
  });

  /// Rebuilds an entry from a [json] map produced by [toJson].
  ///
  /// The inverse of [toJson]. Throws on a missing or invalid field, or an
  /// unknown discipline `wireName`, exactly like `SessionRecord.fromJson`; the
  /// list store treats any such throw as an unreadable (empty) log.
  factory DryFireEntry.fromJson(Map<String, dynamic> json) {
    return DryFireEntry(
      id: json['id'] as String,
      recordedAt: parseWireTime(json['recordedAt'] as String),
      discipline: DryFireDiscipline.fromWireName(json['discipline'] as String),
      triggerPulls: json['triggerPulls'] as int,
    );
  }

  /// The stable client-generated id.
  final String id;

  /// When the bout was recorded.
  final DateTime recordedAt;

  /// The target discipline it was practised on.
  final DryFireDiscipline discipline;

  /// How many trigger pulls (avtrekk) were taken; always greater than zero for
  /// a stored entry (the presentation layer rejects a non-positive count).
  final int triggerPulls;

  /// A JSON-able map of this entry, round-tripped by [DryFireEntry.fromJson].
  ///
  /// [recordedAt] is written as a UTC ISO-8601 string and the [discipline] as
  /// its stable [DryFireDiscipline.wireName].
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'recordedAt': formatWireTimeUtc(recordedAt),
    'discipline': discipline.wireName,
    'triggerPulls': triggerPulls,
  };

  @override
  bool operator ==(Object other) =>
      other is DryFireEntry &&
      other.id == id &&
      other.recordedAt == recordedAt &&
      other.discipline == discipline &&
      other.triggerPulls == triggerPulls;

  @override
  int get hashCode => Object.hash(id, recordedAt, discipline, triggerPulls);
}
