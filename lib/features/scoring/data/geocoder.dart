// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Turns coordinates into a human place name (spec 0076).
///
/// A one-method interface on purpose: it is a swappable service (a real one,
/// the no-op default, a fake in tests), like the other `data/` interfaces.
// ignore: one_member_abstracts
abstract interface class Geocoder {
  /// The name of the place at [latitude] / [longitude], or `null` when it can't
  /// be resolved (offline, no match, or a service error) — the caller then
  /// falls back to showing the coordinates.
  Future<String?> reverseGeocode(double latitude, double longitude);
}

/// A geocoder that resolves nothing — the default, so "use my location" keeps
/// showing the coordinates until a real geocoder is wired (spec 0076).
class NoGeocoder implements Geocoder {
  /// Creates the no-op geocoder.
  const NoGeocoder();

  @override
  Future<String?> reverseGeocode(double latitude, double longitude) async =>
      null;
}
