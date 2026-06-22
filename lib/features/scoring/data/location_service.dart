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

/// The outcome of a [LocationService.currentLocation] attempt.
///
/// A sealed result so callers `switch` over every outcome exhaustively
/// (ADR-0015): a [LocationFix] carries coordinates; [LocationDenied] and
/// [LocationUnavailable] both degrade to manual entry; [LocationDeniedForever]
/// additionally tells the UI to offer an "open settings" action, since only the
/// OS settings can undo it.
sealed class LocationResult {
  const LocationResult();
}

/// A successful fix carrying the device [location].
class LocationFix extends LocationResult {
  /// Creates a fix wrapping [location].
  const LocationFix(this.location);

  /// The captured device location.
  final DeviceLocation location;
}

/// Permission was denied this time, but can still be asked for again.
///
/// Degrades to manual entry like [LocationUnavailable]; no "open settings"
/// affordance, because re-asking can still succeed.
class LocationDenied extends LocationResult {
  /// Creates the denied result.
  const LocationDenied();
}

/// Permission is permanently denied (`deniedForever`).
///
/// The app can no longer prompt; the only fix is the OS settings, so the UI
/// offers an "open settings" action ([LocationService.openLocationSettings])
/// while manual entry stays available.
class LocationDeniedForever extends LocationResult {
  /// Creates the permanently-denied result.
  const LocationDeniedForever();
}

/// No fix for any other reason — services off, unsupported platform, a timeout
/// or any thrown error. Degrades to manual entry.
class LocationUnavailable extends LocationResult {
  /// Creates the unavailable result.
  const LocationUnavailable();
}

/// Reads the device's current location, independent of any platform or plugin.
///
/// Reaching GPS through this interface (like `AuthRepository`) keeps the
/// presentation layer testable with a fake and lets a real geolocator-backed
/// implementation drop in later (ADR-0015). [currentLocation] reports the
/// outcome as a sealed [LocationResult]; [openLocationSettings] opens the OS
/// app settings so a permanently-denied permission can be granted there.
abstract interface class LocationService {
  /// The current location outcome: a [LocationFix] with coordinates, or
  /// [LocationDenied] / [LocationDeniedForever] / [LocationUnavailable]. Every
  /// non-fix outcome is normal: callers fall back to manual entry (graceful
  /// degradation), and only [LocationDeniedForever] warrants an "open settings"
  /// affordance.
  Future<LocationResult> currentLocation();

  /// Opens the OS application settings so the user can grant location
  /// permission after a permanent denial. A no-op where unsupported.
  Future<void> openLocationSettings();
}

/// A [LocationService] that never has a fix.
///
/// The default binding until a real GPS implementation is wired (ADR-0015); it
/// makes "use my location" degrade cleanly to manual entry on every platform.
/// It is never permanently denied and opening settings is a no-op.
class UnavailableLocationService implements LocationService {
  /// Creates the always-unavailable service.
  const UnavailableLocationService();

  @override
  Future<LocationResult> currentLocation() async => const LocationUnavailable();

  @override
  Future<void> openLocationSettings() async {}
}
