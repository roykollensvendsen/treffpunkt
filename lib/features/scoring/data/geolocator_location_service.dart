// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:geolocator/geolocator.dart';
import 'package:treffpunkt/features/scoring/data/location_service.dart';

/// The geolocator operations [GeolocatorLocationService] depends on.
///
/// A thin seam over the static `Geolocator.*` API (which cannot be faked
/// directly) so the permission and fallback logic is unit-testable with a fake
/// gateway. [RealGeolocatorGateway] binds these to the real plugin; tests
/// supply a fake to drive each outcome.
abstract interface class GeolocatorGateway {
  /// Whether the device's location services are turned on.
  Future<bool> isLocationServiceEnabled();

  /// The app's current location permission, without prompting.
  Future<LocationPermission> checkPermission();

  /// Prompts for location permission and returns the resulting state.
  Future<LocationPermission> requestPermission();

  /// Fetches the current position using [locationSettings].
  Future<Position> getCurrentPosition({LocationSettings? locationSettings});
}

/// The default [GeolocatorGateway], forwarding to the real `Geolocator` plugin.
///
/// A trivial binding to the platform plugin; its behaviour is the plugin's, so
/// the testable logic lives in [GeolocatorLocationService] instead.
class RealGeolocatorGateway implements GeolocatorGateway {
  /// Creates the real gateway.
  const RealGeolocatorGateway();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      Geolocator.getCurrentPosition(locationSettings: locationSettings);
}

/// A [LocationService] backed by the `geolocator` plugin (web, Android, iOS).
///
/// Reads a real device fix when location services are on and permission is
/// granted; for every other outcome — services off, permission denied or
/// permanently denied, an unsupported platform, a timeout or any thrown
/// error — it returns `null` (never throws), so "Bruk min posisjon" degrades
/// cleanly to manual entry (ADR-0015).
class GeolocatorLocationService implements LocationService {
  /// Creates the service, optionally over a custom [gateway] (defaults to the
  /// real plugin) and a [timeout] guarding a hanging fix.
  const GeolocatorLocationService({
    this.gateway = const RealGeolocatorGateway(),
    this.timeout = const Duration(seconds: 10),
  });

  /// The geolocator operations this service depends on (the real plugin by
  /// default; a fake in tests).
  final GeolocatorGateway gateway;

  /// The maximum time to wait for a position before treating it as no fix.
  final Duration timeout;

  @override
  Future<DeviceLocation?> currentLocation() async {
    try {
      if (!await gateway.isLocationServiceEnabled()) return null;
      if (!await _hasPermission()) return null;
      final position = await gateway.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return DeviceLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on Object {
      // Any failure (timeout, platform exception, unsupported) is "no fix":
      // the caller falls back to manual entry rather than seeing an error.
      return null;
    }
  }

  /// Whether the app has a usable grant, requesting once if not yet decided.
  Future<bool> _hasPermission() async {
    var permission = await gateway.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await gateway.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }
}
