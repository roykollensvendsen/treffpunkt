// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/scoring/data/location_service.dart';

/// In-memory [LocationService] for tests — no real GPS.
class FakeLocationService implements LocationService {
  /// Creates a fake that returns [result] from [currentLocation].
  ///
  /// Defaults to [LocationUnavailable] (no fix). Pass a [LocationFix] for a
  /// fix, or [LocationDeniedForever] to drive the open-settings affordance.
  FakeLocationService({LocationResult? result})
    : result = result ?? const LocationUnavailable();

  /// Convenience: a fake returning a [LocationFix] at [latitude]/[longitude].
  FakeLocationService.fix({required double latitude, required double longitude})
    : result = LocationFix(
        DeviceLocation(latitude: latitude, longitude: longitude),
      );

  /// The outcome returned by [currentLocation].
  LocationResult result;

  /// Number of times [currentLocation] has been called.
  int callCount = 0;

  /// Number of times [openLocationSettings] has been called.
  int openSettingsCount = 0;

  @override
  Future<LocationResult> currentLocation() async {
    callCount++;
    return result;
  }

  @override
  Future<void> openLocationSettings() async {
    openSettingsCount++;
  }
}
