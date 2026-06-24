// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_calibration.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

/// Detects bullet holes in a calibrated target photo and returns them as
/// [Shot]s, independent of any image-decoding plugin (spec 0040).
///
/// Reaching the decoder + detector through this interface keeps the scan screen
/// testable with a fake (the same seam pattern as `ImageSourceService`,
/// ADR-0015). [scan] **never throws**: it returns `null` when the photo can't
/// be decoded or analysed, an empty list when nothing was found, so the screen
/// degrades to the manual flow.
// ignore: one_member_abstracts — a deliberate seam, not an accidental wrapper.
abstract interface class TargetScanner {
  /// The detected holes as [Shot]s for the photo [bytes], using the box-space
  /// [calibration] the shooter set, the photo box side [boxSide], the target
  /// [geometry] and the cap [maxHoles]. `null` on a decode/processing failure.
  Future<List<Shot>?> scan(
    Uint8List bytes, {
    required TargetCalibration calibration,
    required double boxSide,
    required TargetGeometry geometry,
    required int maxHoles,
  });
}

/// A [TargetScanner] that can never analyse a photo.
///
/// The default binding until the real `image`-backed scanner is wired (spec
/// 0040); it makes auto-detect degrade cleanly to manual placement, and keeps
/// the `image` dependency out of tests and the default provider.
class UnavailableTargetScanner implements TargetScanner {
  /// Creates the always-unavailable scanner.
  const UnavailableTargetScanner();

  @override
  Future<List<Shot>?> scan(
    Uint8List bytes, {
    required TargetCalibration calibration,
    required double boxSide,
    required TargetGeometry geometry,
    required int maxHoles,
  }) async => null;
}
