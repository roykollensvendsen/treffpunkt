// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:treffpunkt/features/scoring/domain/gray_field.dart';
import 'package:treffpunkt/features/scoring/domain/target_calibration.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';

/// Finds candidate bullet holes in a calibrated photo of a target (spec 0040).
///
/// A pure-Dart heuristic — no ML, no native code — exploiting the calibration
/// the shooter already set: the centre, the scale (so the expected hole size in
/// pixels is known) and the printed geometry. It is *assistive*: it pre-fills
/// editable shots the shooter reviews, so it is tuned to favour false negatives
/// (a missed hole costs one tap) over false positives (a phantom must be
/// noticed and deleted).
///
/// All operations are O(W·H): a two-sided local-contrast mask (via an integral
/// image) catches a hole whether it is dark-on-white paper or light-on-black
/// bull and is robust to lighting gradients; connected components are filtered
/// by size and compactness (rejecting thin ring lines) and by a radial band at
/// the bull edge (its strong circular edge); survivors are de-duplicated and
/// ranked by contrast strength.
class HoleDetector {
  /// Creates a detector with tunable thresholds.
  const HoleDetector({
    this.contrastThreshold = 22,
    this.minPeakContrast = 55,
    this.minCompactness = 0.4,
    this.maxAspect = 2.6,
  });

  /// Minimum |intensity − local mean| (0–255) for a pixel to be hole-candidate.
  final double contrastThreshold;

  /// Minimum *peak* |intensity − local mean| anywhere in a blob for it to be a
  /// real hole. A bullet hole has a strong dark/light core (peak ≫ 100); the
  /// faint "halo" where a disc depresses its own local mean barely clears
  /// [contrastThreshold], so this peak gate removes those phantom blobs.
  final double minPeakContrast;

  /// Minimum `area / boundingBoxArea` for a blob to count as a compact hole
  /// (a filled disc is ≈0.79; thin lines are far lower).
  final double minCompactness;

  /// Maximum bounding-box aspect ratio (long/short) for a blob to be a hole.
  final double maxAspect;

  /// The candidate hole centroids in [field] pixels, given the field-space
  /// [centre] and [pixelsPerMm] and the target [geometry], up to [maxHoles].
  List<PixelPoint> detect(
    GrayField field, {
    required PixelPoint centre,
    required double pixelsPerMm,
    required TargetGeometry geometry,
    required int maxHoles,
  }) {
    if (maxHoles <= 0 || pixelsPerMm <= 0) return <PixelPoint>[];
    final holeR = geometry.pelletRadiusMm * pixelsPerMm;
    // Below a few pixels a hole is indistinguishable from noise; bail rather
    // than emit junk (the caller keeps the photo at higher resolution instead).
    if (holeR < 1.5) return <PixelPoint>[];

    final w = field.width;
    final h = field.height;
    final roiR = geometry.maxScoringRadiusMm * pixelsPerMm * 1.1;
    final scoringR = geometry.maxScoringRadiusMm * pixelsPerMm;
    // A generous background window keeps a hole a small fraction of the local
    // mean, so the mean is barely pulled toward the hole and the surrounding
    // paper stays well under [contrastThreshold].
    final win = math.max(3, (holeR * 4).round());
    final expectedArea = math.pi * holeR * holeR;
    final minArea = math.max(2, (0.2 * expectedArea).round());
    final maxArea = math.max(minArea + 1, (6 * expectedArea).round());
    final bullRadiusPx = geometry.blackBullDiameterMm / 2 * pixelsPerMm;
    final bandPx = math.max(1.5, holeR * 0.35);

    final dev = _contrastMask(field, centre: centre, roiR: roiR, win: win);
    final blobs = _components(dev, w, h, minArea: minArea, maxArea: maxArea);

    final kept = <_Candidate>[];
    for (final blob in blobs) {
      if (blob.maxDev < minPeakContrast) continue;
      final bw = blob.maxX - blob.minX + 1;
      final bh = blob.maxY - blob.minY + 1;
      final compactness = blob.area / (bw * bh);
      if (compactness < minCompactness) continue;
      final aspect = bw >= bh ? bw / bh : bh / bw;
      if (aspect > maxAspect) continue;
      final cx = blob.sumX / blob.area;
      final cy = blob.sumY / blob.area;
      // Reject the bull's circular edge: a blob whose centroid radius lands on
      // the printed bull-edge band is almost always an edge fragment, not a
      // shot.
      final r = math.sqrt(
        (cx - centre.x) * (cx - centre.x) + (cy - centre.y) * (cy - centre.y),
      );
      if ((r - bullRadiusPx).abs() < bandPx) continue;
      // Beyond the outermost scoring ring a hole is a miss (0), so auto-placing
      // it adds no score and, on a photo, is almost always a paper-margin or
      // background artefact rather than a real shot — drop it.
      if (r > scoringR) continue;
      kept.add(
        _Candidate(PixelPoint(cx, cy), blob.sumDev / blob.area),
      );
    }

    kept.sort((a, b) => b.strength.compareTo(a.strength));
    final minSeparation = holeR * 1.5;
    final accepted = <PixelPoint>[];
    for (final candidate in kept) {
      if (accepted.length >= maxHoles) break;
      final tooClose = accepted.any(
        (p) => p.distanceTo(candidate.point) < minSeparation,
      );
      if (!tooClose) accepted.add(candidate.point);
    }
    return accepted;
  }

  /// The per-pixel contrast deviation (0 = not a candidate, else the clamped
  /// |intensity − local mean|) within [roiR] of [centre], via integral image.
  Uint8List _contrastMask(
    GrayField field, {
    required PixelPoint centre,
    required double roiR,
    required int win,
  }) {
    final w = field.width;
    final h = field.height;
    // Integral image with a zero border: sum over [0,x]×[0,y] at (x+1,y+1).
    final integral = Int64List((w + 1) * (h + 1));
    for (var y = 0; y < h; y++) {
      var rowSum = 0;
      for (var x = 0; x < w; x++) {
        rowSum += field.at(x, y);
        integral[(y + 1) * (w + 1) + (x + 1)] =
            integral[y * (w + 1) + (x + 1)] + rowSum;
      }
    }

    int boxSum(int x0, int y0, int x1, int y1) =>
        integral[(y1 + 1) * (w + 1) + (x1 + 1)] -
        integral[y0 * (w + 1) + (x1 + 1)] -
        integral[(y1 + 1) * (w + 1) + x0] +
        integral[y0 * (w + 1) + x0];

    final dev = Uint8List(w * h);
    final roiR2 = roiR * roiR;
    for (var y = 0; y < h; y++) {
      final dy = y - centre.y;
      for (var x = 0; x < w; x++) {
        final dx = x - centre.x;
        if (dx * dx + dy * dy > roiR2) continue;
        final x0 = math.max(0, x - win);
        final y0 = math.max(0, y - win);
        final x1 = math.min(w - 1, x + win);
        final y1 = math.min(h - 1, y + win);
        final count = (x1 - x0 + 1) * (y1 - y0 + 1);
        final mean = boxSum(x0, y0, x1, y1) / count;
        final deviation = (field.at(x, y) - mean).abs();
        if (deviation > contrastThreshold) {
          dev[y * w + x] = math.min(255, deviation.round());
        }
      }
    }
    return dev;
  }

  /// The connected components (8-connected) of the non-zero pixels in [dev]
  /// whose area is within [minArea]..[maxArea].
  List<_Blob> _components(
    Uint8List dev,
    int w,
    int h, {
    required int minArea,
    required int maxArea,
  }) {
    final visited = Uint8List(w * h);
    final blobs = <_Blob>[];
    final stack = <int>[];
    for (var start = 0; start < dev.length; start++) {
      if (dev[start] == 0 || visited[start] == 1) continue;
      visited[start] = 1;
      stack
        ..clear()
        ..add(start);
      var area = 0;
      var sumX = 0.0;
      var sumY = 0.0;
      var sumDev = 0.0;
      var maxDev = 0;
      var minX = w;
      var minY = h;
      var maxX = 0;
      var maxY = 0;
      while (stack.isNotEmpty) {
        final index = stack.removeLast();
        final px = index % w;
        final py = index ~/ w;
        area++;
        sumX += px;
        sumY += py;
        sumDev += dev[index];
        if (dev[index] > maxDev) maxDev = dev[index];
        if (px < minX) minX = px;
        if (px > maxX) maxX = px;
        if (py < minY) minY = py;
        if (py > maxY) maxY = py;
        for (var ny = py - 1; ny <= py + 1; ny++) {
          if (ny < 0 || ny >= h) continue;
          for (var nx = px - 1; nx <= px + 1; nx++) {
            if (nx < 0 || nx >= w) continue;
            final ni = ny * w + nx;
            if (dev[ni] != 0 && visited[ni] == 0) {
              visited[ni] = 1;
              stack.add(ni);
            }
          }
        }
      }
      if (area >= minArea && area <= maxArea) {
        blobs.add(
          _Blob(area, sumX, sumY, sumDev, maxDev, minX, minY, maxX, maxY),
        );
      }
    }
    return blobs;
  }
}

/// A connected component of contrast pixels.
class _Blob {
  _Blob(
    this.area,
    this.sumX,
    this.sumY,
    this.sumDev,
    this.maxDev,
    this.minX,
    this.minY,
    this.maxX,
    this.maxY,
  );

  final int area;
  final double sumX;
  final double sumY;
  final double sumDev;
  final int maxDev;
  final int minX;
  final int minY;
  final int maxX;
  final int maxY;
}

/// A surviving hole candidate with its contrast [strength] for ranking.
class _Candidate {
  _Candidate(this.point, this.strength);

  final PixelPoint point;
  final double strength;
}
