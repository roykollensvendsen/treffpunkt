// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Tests for the geolocator-backed LocationService: its permission and fallback
// logic is exercised through a fake gateway, so no real GPS or platform channel
// is touched. The trivial RealGeolocatorGateway (plugin binding) is not tested.
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:treffpunkt/features/scoring/data/geolocator_location_service.dart';
import 'package:treffpunkt/features/scoring/data/location_service.dart';

/// A fake [GeolocatorGateway] returning scripted outcomes (or throwing).
class _FakeGateway implements GeolocatorGateway {
  _FakeGateway({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.afterRequest,
    this.position,
    this.throwOnPosition = false,
    this.throwOnOpenSettings = false,
  });

  final bool serviceEnabled;
  final LocationPermission permission;
  final LocationPermission? afterRequest;
  final Position? position;
  final bool throwOnPosition;
  final bool throwOnOpenSettings;

  int requestCount = 0;
  int openSettingsCount = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestCount++;
    return afterRequest ?? permission;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    if (throwOnPosition) throw Exception('boom');
    return Future<Position>.value(position);
  }

  @override
  Future<bool> openAppSettings() async {
    openSettingsCount++;
    if (throwOnOpenSettings) throw Exception('boom');
    return true;
  }
}

Position _positionAt(double latitude, double longitude) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime(2026, 6, 22),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  group('GeolocatorLocationService', () {
    test('reports unavailable when location services are disabled', () async {
      final service = GeolocatorLocationService(
        gateway: _FakeGateway(serviceEnabled: false),
      );
      expect(await service.currentLocation(), isA<LocationUnavailable>());
    });

    test('reports denied when permission is denied', () async {
      final service = GeolocatorLocationService(
        gateway: _FakeGateway(permission: LocationPermission.denied),
      );
      expect(await service.currentLocation(), isA<LocationDenied>());
    });

    test('reports unavailable when permission is unableToDetermine', () async {
      final service = GeolocatorLocationService(
        gateway: _FakeGateway(
          permission: LocationPermission.unableToDetermine,
        ),
      );
      expect(await service.currentLocation(), isA<LocationUnavailable>());
    });

    test('reports deniedForever when permission is permanently denied, '
        'without re-prompting', () async {
      final gateway = _FakeGateway(
        permission: LocationPermission.deniedForever,
      );
      final service = GeolocatorLocationService(gateway: gateway);
      expect(await service.currentLocation(), isA<LocationDeniedForever>());
      expect(gateway.requestCount, 0); // never re-prompts on permanent denial
    });

    test('requests permission once when initially denied, then returns the '
        'fix on a grant', () async {
      final gateway = _FakeGateway(
        permission: LocationPermission.denied,
        afterRequest: LocationPermission.whileInUse,
        position: _positionAt(59.9, 10.7),
      );
      final service = GeolocatorLocationService(gateway: gateway);

      final result = await service.currentLocation();

      expect(gateway.requestCount, 1);
      expect(result, isA<LocationFix>());
      final fix = (result as LocationFix).location;
      expect(fix.latitude, 59.9);
      expect(fix.longitude, 10.7);
    });

    test(
      'reports deniedForever when a re-prompt is permanently denied',
      () async {
        final gateway = _FakeGateway(
          permission: LocationPermission.denied,
          afterRequest: LocationPermission.deniedForever,
        );
        final service = GeolocatorLocationService(gateway: gateway);

        expect(await service.currentLocation(), isA<LocationDeniedForever>());
        expect(gateway.requestCount, 1);
      },
    );

    test(
      'returns the DeviceLocation when granted and a position is read',
      () async {
        final service = GeolocatorLocationService(
          gateway: _FakeGateway(
            permission: LocationPermission.always,
            position: _positionAt(63.43, 10.39),
          ),
        );

        final result = await service.currentLocation();

        expect(result, isA<LocationFix>());
        final fix = (result as LocationFix).location;
        expect(fix.latitude, 63.43);
        expect(fix.longitude, 10.39);
      },
    );

    test(
      'reports unavailable (does not throw) when the gateway throws',
      () async {
        final service = GeolocatorLocationService(
          gateway: _FakeGateway(throwOnPosition: true),
        );
        expect(await service.currentLocation(), isA<LocationUnavailable>());
      },
    );

    test('openLocationSettings calls through to the gateway', () async {
      final gateway = _FakeGateway();
      final service = GeolocatorLocationService(gateway: gateway);

      await service.openLocationSettings();

      expect(gateway.openSettingsCount, 1);
    });

    test(
      'openLocationSettings swallows a gateway error (best-effort)',
      () async {
        final gateway = _FakeGateway(throwOnOpenSettings: true);
        final service = GeolocatorLocationService(gateway: gateway);

        await expectLater(service.openLocationSettings(), completes);
        expect(gateway.openSettingsCount, 1);
      },
    );
  });
}
