// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:meta/meta.dart';

/// Where a session was shot: a human [label] and optional coordinates.
///
/// Coordinates and a label coexist (ADR-0012) — a GPS fix can still be named,
/// and a typed place needs no coordinates. A pure value type compared by value.
@immutable
class Place {
  /// Creates a place with a [label] and optional [latitude] / [longitude].
  const Place({required this.label, this.latitude, this.longitude});

  /// Human-readable place name, e.g. `'Løvenskiold skytebane'`.
  final String label;

  /// Latitude in decimal degrees, or `null` when no coordinates are known.
  final double? latitude;

  /// Longitude in decimal degrees, or `null` when no coordinates are known.
  final double? longitude;

  /// A copy with the given fields replaced; unspecified fields are kept.
  Place copyWith({String? label, double? latitude, double? longitude}) {
    return Place(
      label: label ?? this.label,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Place &&
      other.label == label &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(label, latitude, longitude);
}
