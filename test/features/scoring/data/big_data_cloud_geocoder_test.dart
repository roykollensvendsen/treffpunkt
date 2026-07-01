// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the BigDataCloud reverse geocoder (spec 0076): a fix resolves
// to a locality name; the fallback order is locality → city → region; a bad
// response degrades to null so the caller shows the coordinates.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:treffpunkt/features/scoring/data/big_data_cloud_geocoder.dart';

void main() {
  test('resolves the locality and sends the coordinates (spec 0076)', () async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'locality': 'Majorstuen',
          'city': 'Oslo',
          'principalSubdivision': 'Oslo',
        }),
        200,
      );
    });

    final name = await BigDataCloudGeocoder(client).reverseGeocode(59.9, 10.7);

    expect(name, 'Majorstuen');
    expect(requested.host, 'api.bigdatacloud.net');
    expect(requested.queryParameters['latitude'], '59.9');
    expect(requested.queryParameters['longitude'], '10.7');
  });

  test('names fall back locality → city → region, else null (spec 0076)', () {
    expect(
      placeNameFromBigDataCloud(<String, dynamic>{
        'locality': '',
        'city': 'Oslo',
      }),
      'Oslo',
    );
    expect(
      placeNameFromBigDataCloud(<String, dynamic>{
        'principalSubdivision': 'Viken',
      }),
      'Viken',
    );
    expect(placeNameFromBigDataCloud(<String, dynamic>{}), isNull);
  });

  test('a non-200 or malformed response yields null (spec 0076)', () async {
    final failing = BigDataCloudGeocoder(
      MockClient((_) async => http.Response('nope', 500)),
    );
    expect(await failing.reverseGeocode(1, 2), isNull);

    final malformed = BigDataCloudGeocoder(
      MockClient((_) async => http.Response('not json', 200)),
    );
    expect(await malformed.reverseGeocode(1, 2), isNull);
  });
}
