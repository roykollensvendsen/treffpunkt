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
  });

  final bool serviceEnabled;
  final LocationPermission permission;
  final LocationPermission? afterRequest;
  final Position? position;
  final bool throwOnPosition;

  int requestCount = 0;

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
    test('returns null when location services are disabled', () async {
      final service = GeolocatorLocationService(
        gateway: _FakeGateway(serviceEnabled: false),
      );
      expect(await service.currentLocation(), isNull);
    });

    test('returns null when permission is denied', () async {
      final service = GeolocatorLocationService(
        gateway: _FakeGateway(permission: LocationPermission.denied),
      );
      expect(await service.currentLocation(), isNull);
    });

    test('returns null when permission is permanently denied', () async {
      final gateway = _FakeGateway(
        permission: LocationPermission.deniedForever,
      );
      final service = GeolocatorLocationService(gateway: gateway);
      expect(await service.currentLocation(), isNull);
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

      final fix = await service.currentLocation();

      expect(gateway.requestCount, 1);
      expect(fix?.latitude, 59.9);
      expect(fix?.longitude, 10.7);
    });

    test(
      'returns the DeviceLocation when granted and a position is read',
      () async {
        final service = GeolocatorLocationService(
          gateway: _FakeGateway(
            permission: LocationPermission.always,
            position: _positionAt(63.43, 10.39),
          ),
        );

        final fix = await service.currentLocation();

        expect(fix, isA<DeviceLocation>());
        expect(fix?.latitude, 63.43);
        expect(fix?.longitude, 10.39);
      },
    );

    test('returns null (does not throw) when the gateway throws', () async {
      final service = GeolocatorLocationService(
        gateway: _FakeGateway(throwOnPosition: true),
      );
      expect(await service.currentLocation(), isNull);
    });
  });
}
