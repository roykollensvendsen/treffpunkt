// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:meta/meta.dart';

/// A decoded photo as a grayscale pixel grid (luminance 0–255), row-major.
///
/// The pure pixel grid the heuristic hole detector (spec 0040) works on, so the
/// detection logic stays pure Dart and unit-testable: the `image` plugin only
/// produces a [GrayField], it is never imported by the domain or the tests.
@immutable
class GrayField {
  /// Creates a [width] × [height] field backed by [intensities] (row-major,
  /// one luminance byte per pixel).
  const GrayField({
    required this.width,
    required this.height,
    required this.intensities,
  }) : assert(
         intensities.length == width * height,
         'intensities must hold width*height bytes',
       );

  /// The field width in pixels.
  final int width;

  /// The field height in pixels.
  final int height;

  /// The luminance bytes (0–255), row-major: pixel `(x, y)` at `y*width + x`.
  final Uint8List intensities;

  /// The luminance (0–255) at pixel [x] / [y].
  int at(int x, int y) => intensities[y * width + x];
}
