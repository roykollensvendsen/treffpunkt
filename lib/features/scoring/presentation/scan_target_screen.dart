// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/data/image_source_service.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_calibration.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/presentation/scan_overlay_painter.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

/// Key for the "take a photo" button on the capture step.
const Key scanCameraButtonKey = ValueKey<String>('scanCameraButton');

/// Key for the "choose a photo" (gallery / file) button on the capture step.
const Key scanGalleryButtonKey = ValueKey<String>('scanGalleryButton');

/// Key for the "retake / choose another" app-bar action.
const Key scanRetakeKey = ValueKey<String>('scanRetake');

/// Key for the "looks aligned" button that leaves calibration for placement.
const Key scanCalibrateConfirmKey = ValueKey<String>('scanCalibrateConfirm');

/// Key for the tappable photo overlay (rings + markers) shots are placed on.
const Key scanOverlayKey = ValueKey<String>('scanOverlay');

/// Key for the draggable centre calibration handle.
const Key scanCentreHandleKey = ValueKey<String>('scanCentreHandle');

/// Key for the draggable scale (outer-ring) calibration handle.
const Key scanScaleHandleKey = ValueKey<String>('scanScaleHandle');

/// Key for the live score read-out of the most recently placed shot.
const Key scanLiveScoreKey = ValueKey<String>('scanLiveScore');

/// Key for the "undo last shot" action on the placement step.
const Key scanUndoKey = ValueKey<String>('scanUndo');

/// Key for the "confirm" action that commits the placed shots and returns.
const Key scanConfirmKey = ValueKey<String>('scanConfirm');

/// Key for the "auto-detect holes" action on the placement step (spec 0040).
const Key scanDetectKey = ValueKey<String>('scanDetect');

/// The steps of the scan flow.
enum _ScanMode { capture, calibrate, place }

/// Camera-assisted shot placement (spec 0039): photograph the paper target,
/// align the app's ring overlay on it, tap each bullet hole, and return the
/// placed shots to the series.
///
/// Self-contained: it takes the [geometry] to score against and the [maxShots]
/// it may place (the series' remaining capacity), reads the camera / gallery
/// through [imageSourceServiceProvider], and pops a `List<Shot>` (mm from the
/// target centre) — so the caller commits them into the current series. It does
/// not seal the series; sealing stays the manual gesture on the series screen.
class ScanTargetScreen extends ConsumerStatefulWidget {
  /// Creates the scan screen for [geometry], allowing up to [maxShots] shots.
  const ScanTargetScreen({
    required this.geometry,
    required this.maxShots,
    super.key,
  });

  /// The target the placed shots are scored and overlaid against.
  final TargetGeometry geometry;

  /// The most shots that may be placed (the series' remaining capacity).
  final int maxShots;

  @override
  ConsumerState<ScanTargetScreen> createState() => _ScanTargetScreenState();
}

class _ScanTargetScreenState extends ConsumerState<ScanTargetScreen> {
  static const ScoringService _scoring = ScoringService();

  /// How close (logical px) a long-press must be to a marker to pick it up.
  static const double _pickRadiusPx = 28;

  /// Visual radius (logical px) of a calibration handle.
  static const double _handleRadius = 18;

  _ScanMode _mode = _ScanMode.capture;
  Uint8List? _imageBytes;
  PixelPoint? _centre;
  PixelPoint? _scale;
  double _boxSide = 0;
  bool _analysing = false;
  final List<Shot> _candidates = <Shot>[];
  int? _draggingIndex;

  TargetCalibration get _calibration => TargetCalibration.fromHandles(
    centre: _centre!,
    scale: _scale!,
    referenceRadiusMm: widget.geometry.maxScoringRadiusMm,
  );

  Future<void> _capture() async {
    final result = await ref.read(imageSourceServiceProvider).capturePhoto();
    _onResult(result, deniedHint: 'Kameratilgang avslått — velg et bilde.');
  }

  Future<void> _pickFromGallery() async {
    final result = await ref.read(imageSourceServiceProvider).pickFromGallery();
    _onResult(result, deniedHint: 'Bildetilgang avslått.');
  }

  void _onResult(ImageSourceResult result, {required String deniedHint}) {
    if (!mounted) return;
    switch (result) {
      case ImagePicked(:final image):
        setState(() {
          _imageBytes = image.bytes;
          _centre = null;
          _scale = null;
          _candidates.clear();
          _draggingIndex = null;
          _mode = _ScanMode.calibrate;
        });
      case ImagePickCancelled():
        break;
      case ImagePickDenied():
        _showHint(deniedHint);
      case ImagePickUnavailable():
        _showHint('Fant ingen kamera eller bilder.');
    }
  }

  void _showHint(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Seeds the two handles from the photo box [side] the first time the photo
  /// is shown, so the overlay is visible and usable before any drag: the centre
  /// at the box middle, the scale handle a third of the way out to the right.
  void _seedHandles(double side) {
    _boxSide = side;
    _centre ??= PixelPoint(side / 2, side / 2);
    _scale ??= PixelPoint(side / 2 + side * 0.3, side / 2);
  }

  /// Auto-detects holes in the photo and appends them as editable shots (spec
  /// 0040): de-duplicated against existing shots and capped at the remaining
  /// capacity. Best-effort — a failure or no hits leaves manual placement
  /// intact.
  Future<void> _detect() async {
    final bytes = _imageBytes;
    final remaining = widget.maxShots - _candidates.length;
    if (bytes == null || _analysing) return;
    if (remaining <= 0) {
      _showHint('Serien er full (${widget.maxShots} skudd).');
      return;
    }
    setState(() => _analysing = true);
    final detected = await ref
        .read(targetScannerProvider)
        .scan(
          bytes,
          calibration: _calibration,
          boxSide: _boxSide,
          geometry: widget.geometry,
          maxHoles: remaining,
        );
    if (!mounted) return;
    setState(() => _analysing = false);
    if (detected == null) {
      _showHint('Kunne ikke analysere bildet — merk treffene manuelt.');
      return;
    }
    if (detected.isEmpty) {
      _showHint('Fant ingen treff automatisk — merk dem selv.');
      return;
    }
    final minSepMm = widget.geometry.pelletRadiusMm * 1.5;
    final added = <Shot>[];
    for (final shot in detected) {
      if (added.length >= remaining) break;
      final duplicate = _candidates
          .followedBy(added)
          .any((existing) => _distanceMm(existing, shot) < minSepMm);
      if (!duplicate) added.add(shot);
    }
    setState(() => _candidates.addAll(added));
    _showHint('La til ${added.length} treff — sjekk og juster.');
  }

  static double _distanceMm(Shot a, Shot b) {
    final dx = a.dxMm - b.dxMm;
    final dy = a.dyMm - b.dyMm;
    return math.sqrt(dx * dx + dy * dy);
  }

  void _placeAt(Offset localPx) {
    if (_candidates.length >= widget.maxShots) {
      _showHint('Serien er full (${widget.maxShots} skudd).');
      return;
    }
    setState(() {
      _candidates.add(_calibration.shotFor(PixelPoint(localPx.dx, localPx.dy)));
    });
  }

  void _pickUp(Offset localPx) {
    final press = PixelPoint(localPx.dx, localPx.dy);
    var nearest = -1;
    var nearestPx = double.infinity;
    for (var i = 0; i < _candidates.length; i++) {
      final markerPx = _calibration.imagePxFor(_candidates[i]);
      final distance = markerPx.distanceTo(press);
      if (distance < nearestPx) {
        nearestPx = distance;
        nearest = i;
      }
    }
    if (nearest >= 0 && nearestPx <= _pickRadiusPx) {
      setState(() => _draggingIndex = nearest);
    }
  }

  void _dragTo(Offset localPx) {
    final index = _draggingIndex;
    if (index == null) return;
    setState(() {
      _candidates[index] = _calibration.shotFor(
        PixelPoint(localPx.dx, localPx.dy),
      );
    });
  }

  void _undo() {
    if (_candidates.isEmpty) return;
    setState(_candidates.removeLast);
  }

  void _confirm() => Navigator.of(context).pop(List<Shot>.of(_candidates));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skann skive'),
        actions: [
          if (_imageBytes != null)
            IconButton(
              key: scanRetakeKey,
              icon: const Icon(Icons.restart_alt),
              tooltip: 'Ta nytt bilde',
              onPressed: () => setState(() {
                _imageBytes = null;
                _mode = _ScanMode.capture;
              }),
            ),
        ],
      ),
      body: SafeArea(
        child: _mode == _ScanMode.capture ? _captureStep() : _photoStep(),
      ),
    );
  }

  Widget _captureStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.document_scanner_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'Ta et bilde av skiva rett forfra, så legger du appens ringer '
              'oppå og merker hvert treff.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: scanCameraButtonKey,
              onPressed: _capture,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Ta bilde'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: scanGalleryButtonKey,
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Velg bilde'),
            ),
          ],
        ),
      ),
    );
  }

  /// Logical-pixel height reserved below the photo for the step's controls.
  static const double _controlsReserve = 180;

  Widget _photoStep() {
    final calibrating = _mode == _ScanMode.calibrate;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The photo is a square that fits the width and leaves room for the
        // controls below, so it never overflows on a short screen.
        final available = constraints.maxHeight - _controlsReserve;
        final side = math.max<double>(
          0,
          math.min(available, constraints.maxWidth),
        );
        _seedHandles(side);
        return Column(
          children: [
            Center(child: _photoStack(side, calibrating: calibrating)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: calibrating
                    ? _calibrateControls(_calibration)
                    : _placeControls(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _photoStack(double side, {required bool calibrating}) {
    final calibration = _calibration;
    return SizedBox(
      width: side,
      height: side,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.memory(_imageBytes!, fit: BoxFit.contain),
          ),
          Positioned.fill(
            child: GestureDetector(
              key: scanOverlayKey,
              behavior: HitTestBehavior.opaque,
              onTapUp: calibrating ? null : (d) => _placeAt(d.localPosition),
              onLongPressStart: calibrating
                  ? null
                  : (d) => _pickUp(d.localPosition),
              onLongPressMoveUpdate: calibrating
                  ? null
                  : (d) => _dragTo(d.localPosition),
              onLongPressEnd: calibrating
                  ? null
                  : (_) => setState(() => _draggingIndex = null),
              child: CustomPaint(
                size: Size.square(side),
                painter: ScanOverlayPainter(
                  geometry: widget.geometry,
                  calibration: calibration,
                  shots: _candidates,
                ),
              ),
            ),
          ),
          if (calibrating) ...[
            _handle(scanCentreHandleKey, _centre!, Icons.add, (delta) {
              setState(() {
                _centre = PixelPoint(
                  _centre!.x + delta.dx,
                  _centre!.y + delta.dy,
                );
              });
            }),
            _handle(scanScaleHandleKey, _scale!, Icons.open_in_full, (
              delta,
            ) {
              setState(() {
                _scale = PixelPoint(
                  _scale!.x + delta.dx,
                  _scale!.y + delta.dy,
                );
              });
            }),
          ],
        ],
      ),
    );
  }

  Widget _handle(
    Key key,
    PixelPoint at,
    IconData icon,
    void Function(Offset delta) onDrag,
  ) {
    return Positioned(
      left: at.x - _handleRadius,
      top: at.y - _handleRadius,
      child: GestureDetector(
        key: key,
        onPanUpdate: (d) => onDrag(d.delta),
        child: Container(
          width: _handleRadius * 2,
          height: _handleRadius * 2,
          decoration: BoxDecoration(
            color: Colors.lightGreenAccent.withValues(alpha: 0.5),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black87, width: 2),
          ),
          child: Icon(icon, size: 18, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _calibrateControls(TargetCalibration calibration) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dra det ene merket til midten av skiva og det andre ut på den '
          'ytterste ringen, til ringene over bildet passer.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: scanCalibrateConfirmKey,
          onPressed: calibration.isUsable
              ? () => setState(() => _mode = _ScanMode.place)
              : null,
          child: const Text('Ser bra ut'),
        ),
      ],
    );
  }

  Widget _placeControls() {
    final theme = Theme.of(context);
    final lastShot = _candidates.isEmpty ? null : _candidates.last;
    final lastRing = lastShot == null
        ? null
        : _scoring.integerScore(widget.geometry, lastShot);
    final lastInnerTen =
        lastShot != null && _scoring.isInnerTen(widget.geometry, lastShot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.tonalIcon(
          key: scanDetectKey,
          onPressed: _analysing ? null : _detect,
          icon: _analysing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_fix_high),
          label: Text(_analysing ? 'Analyserer…' : 'Finn treff automatisk'),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_candidates.length} av ${widget.maxShots} plassert',
              style: theme.textTheme.titleMedium,
            ),
            Text(
              key: scanLiveScoreKey,
              lastRing == null ? '–' : '$lastRing${lastInnerTen ? ' X' : ''}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Trykk på hvert treff i bildet. Hold inne på et merke for å '
          'flytte det.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: scanUndoKey,
                onPressed: _candidates.isEmpty ? null : _undo,
                icon: const Icon(Icons.undo),
                label: const Text('Angre'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                key: scanConfirmKey,
                onPressed: _candidates.isEmpty ? null : _confirm,
                icon: const Icon(Icons.check),
                label: const Text('Bruk skudd'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
