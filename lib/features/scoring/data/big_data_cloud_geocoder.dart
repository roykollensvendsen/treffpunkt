// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:treffpunkt/features/scoring/data/geocoder.dart';

/// A [Geocoder] backed by BigDataCloud's free, key-less **client** reverse
/// geocoder (spec 0076).
///
/// The `reverse-geocode-client` endpoint is CORS-enabled and needs no API key,
/// so it works straight from the browser as well as mobile. It is best-effort:
/// any failure resolves to `null` and the caller falls back to the coordinates.
class BigDataCloudGeocoder implements Geocoder {
  /// Creates the geocoder over an HTTP client.
  BigDataCloudGeocoder(this._client);

  final http.Client _client;

  @override
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    final uri = Uri.https(
      'api.bigdatacloud.net',
      '/data/reverse-geocode-client',
      <String, String>{
        'latitude': '$latitude',
        'longitude': '$longitude',
        'localityLanguage': 'nb',
      },
    );
    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return placeNameFromBigDataCloud(json);
    } on Object {
      // Best-effort: offline, a bad response, or malformed JSON → fall back.
      return null;
    }
  }
}

/// Picks the most useful place name from a BigDataCloud response: the locality
/// (town / suburb), else the city (municipality), else the region — or `null`
/// when none is present (spec 0076).
String? placeNameFromBigDataCloud(Map<String, dynamic> json) {
  for (final key in <String>['locality', 'city', 'principalSubdivision']) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}
