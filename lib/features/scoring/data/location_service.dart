// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// A device location fix: coordinates in decimal degrees.
class DeviceLocation {
  /// Creates a location at [latitude] / [longitude].
  const DeviceLocation({required this.latitude, required this.longitude});

  /// Latitude in decimal degrees.
  final double latitude;

  /// Longitude in decimal degrees.
  final double longitude;
}

/// Reads the device's current location, independent of any platform or plugin.
///
/// Reaching GPS through this interface (like `AuthRepository`) keeps the
/// presentation layer testable with a fake and lets a real geolocator-backed
/// implementation drop in later (ADR-0015). A single member today; permission
/// state and a stream may join it as GPS lands.
// ignore: one_member_abstracts
abstract interface class LocationService {
  /// The current location, or `null` when there is no fix — denied,
  /// unavailable or unsupported. A `null` result is normal: callers fall back
  /// to manual entry (graceful degradation).
  Future<DeviceLocation?> currentLocation();
}

/// A [LocationService] that never has a fix.
///
/// The default binding until a real GPS implementation is wired (ADR-0015); it
/// makes "use my location" degrade cleanly to manual entry on every platform.
class UnavailableLocationService implements LocationService {
  /// Creates the always-unavailable service.
  const UnavailableLocationService();

  @override
  Future<DeviceLocation?> currentLocation() async => null;
}
