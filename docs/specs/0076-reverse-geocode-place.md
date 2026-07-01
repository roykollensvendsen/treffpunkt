# Spec 0076 — Name the place from my coordinates

- **Status:** Accepted.
- **Related:** 0008 (session setup metadata), ADR-0015 (location capture via a
  service interface).

## Context
"Bruk min posisjon" fills the session's **place** field with a raw **coordinate
string** (e.g. `59.9000, 10.7000`). A name — the town or area — is far more
useful on a scorecard and in "Mine økter" than numbers. Turn the coordinates
into a **place name** (reverse geocoding), keeping the coordinates stored
underneath.

## Requirements
1. Tapping **Bruk min posisjon** fills the place field with a **name** resolved
   from the device's coordinates when one can be found.
2. If no name can be resolved (offline, no match, or a service error), fall back
   to the **coordinate string** exactly as before — the feature never blocks or
   errors.
3. The place still carries the **coordinates** into the session metadata.
4. A name the shooter has **already typed** is not overwritten (unchanged).

## Rationale
**A `Geocoder` service, like the location one.** Reverse geocoding is a swappable
service behind an interface (a real one, a no-op default, a fake in tests),
mirroring `LocationService` (ADR-0015). The default resolves nothing, so the
place gracefully stays as the coordinates until the real geocoder is wired.

**BigDataCloud's key-less client endpoint.** The app is web-first, and the
`geocoding` plugin does not work on the web. BigDataCloud's
`reverse-geocode-client` endpoint is **free, needs no API key, and is
CORS-enabled**, so it works from the browser and mobile alike. It is called
best-effort over `package:http`; any failure returns `null` and the caller shows
the coordinates. The name is the most specific of **locality → city → region**.

**Privacy.** Reverse geocoding necessarily sends the user's own coordinates to
the geocoding service — only when they tap "Bruk min posisjon", and only to
resolve a name. No name lookup happens otherwise.

## Design
- `lib/features/scoring/data/geocoder.dart`: the `Geocoder` interface and
  `NoGeocoder` (the resolves-nothing default).
- `lib/features/scoring/data/big_data_cloud_geocoder.dart`:
  `BigDataCloudGeocoder(http.Client)` + `placeNameFromBigDataCloud(json)`.
- `session_providers.dart`: `geocoderProvider` (defaults to `NoGeocoder`).
- `session_setup_screen.dart`: `_useMyLocation` reverse-geocodes the fix and
  fills the field with the name, falling back to the coordinate string.
- `bootstrap.dart` / `main.dart`: wire `BigDataCloudGeocoder(http.Client())`.
- `pubspec.yaml`: add `http`.

## Verification
- **Unit** (`big_data_cloud_geocoder_test.dart`, `MockClient`): a fix resolves to
  the locality and sends the coordinates; the name falls back locality → city →
  region; a non-200 or malformed response yields `null`.
- **Widget** (`session_setup_screen_test.dart`): with a fake geocoder the place
  field shows the **name** and the metadata keeps the coordinates; with the
  default geocoder it still shows the **coordinate string** (unchanged).

## Out of scope
- Choosing the specific shooting-range name; offline/on-device geocoding; caching
  or rate-limiting lookups.
