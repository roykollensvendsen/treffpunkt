// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:treffpunkt/features/scoring/data/target_scanner.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_calibration.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

/// In-memory [TargetScanner] for tests — no real decoding or detection.
class FakeTargetScanner implements TargetScanner {
  /// Creates a fake returning [result] from [scan] (defaults to `null`, a
  /// processing failure). Pass an empty list for "no holes found".
  FakeTargetScanner({this.result});

  /// The shots returned by [scan], or `null` for a failure.
  List<Shot>? result;

  /// How many times [scan] has been called.
  int scanCount = 0;

  @override
  Future<List<Shot>?> scan(
    Uint8List bytes, {
    required TargetCalibration calibration,
    required double boxSide,
    required TargetGeometry geometry,
    required int maxHoles,
  }) async {
    scanCount++;
    return result;
  }
}
