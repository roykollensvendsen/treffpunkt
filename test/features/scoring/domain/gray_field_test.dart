// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the grayscale pixel grid behind hole detection (spec 0040).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/gray_field.dart';

void main() {
  test('at(x, y) reads the row-major luminance', () {
    final field = GrayField(
      width: 3,
      height: 2,
      intensities: Uint8List.fromList(<int>[10, 20, 30, 40, 50, 60]),
    );
    expect(field.at(0, 0), 10);
    expect(field.at(2, 0), 30);
    expect(field.at(0, 1), 40);
    expect(field.at(2, 1), 60);
  });

  test('asserts the buffer matches width*height', () {
    expect(
      () => GrayField(
        width: 2,
        height: 2,
        intensities: Uint8List.fromList(<int>[1, 2, 3]),
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
