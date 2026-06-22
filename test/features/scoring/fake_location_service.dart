// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/scoring/data/location_service.dart';

/// In-memory [LocationService] for tests — no real GPS.
class FakeLocationService implements LocationService {
  /// Creates a fake that returns [fix] (or `null` for no fix).
  FakeLocationService({this.fix});

  /// The location returned by [currentLocation], or `null` to simulate no fix.
  DeviceLocation? fix;

  /// Number of times [currentLocation] has been called.
  int callCount = 0;

  @override
  Future<DeviceLocation?> currentLocation() async {
    callCount++;
    return fix;
  }
}
