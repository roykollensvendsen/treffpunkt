// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/config/build_info.dart';
import 'package:treffpunkt/core/presentation/frosted_bar.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/scoring/data/image_source_service.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/domain/target_calibration.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/domain/training_sample.dart';
import 'package:treffpunkt/features/scoring/presentation/scan_overlay_painter.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/settings/presentation/contribution_disclosure.dart';
import 'package:treffpunkt/features/settings/presentation/contribution_providers.dart';

/// Key for the "take a photo" button on the capture step.
const Key scanCameraButtonKey = ValueKey<String>('scanCameraButton');

/// Key for the "choose a photo" (gallery / file) button on the capture step.
const Key scanGalleryButtonKey = ValueKey<String>('scanGalleryButton');

/// Key for the "retake / choose another" app-bar action.
const Key scanRetakeKey = ValueKey<String>('scanRetake');

/// Key for the "looks aligned" button that leaves calibration for placement.
const Key scanCalibrateConfirmKey = ValueKey<String>('scanCalibrateConfirm');

/// Key for the photo overlay (rings + markers): tap to place, drag/pinch to
/// calibrate.
const Key scanOverlayKey = ValueKey<String>('scanOverlay');

/// Key for the live score read-out of the most recently placed shot.
const Key scanLiveScoreKey = ValueKey<String>('scanLiveScore');

/// Key for the "undo last shot" action on the placement step.
const Key scanUndoKey = ValueKey<String>('scanUndo');

/// Key for the "confirm" action that commits the placed shots and returns.
const Key scanConfirmKey = ValueKey<String>('scanConfirm');

/// Key for the "auto-detect holes" action on the placement step (spec 0040).
const Key scanDetectKey = ValueKey<String>('scanDetect');

/// Key for the photo zoom-in button on the placement step (spec 0045).
const Key scanZoomInKey = ValueKey<String>('scanZoomIn');

/// Key for the photo zoom-out button on the placement step.
const Key scanZoomOutKey = ValueKey<String>('scanZoomOut');

/// Key for the photo zoom-reset button on the placement step.
const Key scanZoomResetKey = ValueKey<String>('scanZoomReset');

/// The steps of the scan flow.
enum _ScanMode { capture, calibrate, place }

/// The calibration after a pan-pinch gesture on the ring overlay (spec 0046):
/// pure so the maths is unit-testable.
///
/// [scale] is the cumulative pinch factor since the gesture started ([focal] is
/// the current finger focal point, [startFocal] the one at the start). A
/// one-finger drag has `scale == 1`, so the overlay just follows the finger; a
/// pinch resizes it about the focal point, which stays put under the fingers.
@visibleForTesting
({PixelPoint centre, double pixelsPerMm}) calibrationAfterGesture({
  required PixelPoint startCentre,
  required double startPixelsPerMm,
  required PixelPoint startFocal,
  required PixelPoint focal,
  required double scale,
}) {
  return (
    centre: PixelPoint(
      focal.x + scale * (startCentre.x - startFocal.x),
      focal.y + scale * (startCentre.y - startFocal.y),
    ),
    pixelsPerMm: startPixelsPerMm * scale,
  );
}

/// A placed shot together with its training-label provenance (spec 0041): the
/// [source] that placed it and whether it was [edited] (dragged) afterwards.
class _Candidate {
  _Candidate(this.shot, this.source);

  Shot shot;
  final TrainingHoleSource source;
  bool edited = false;
}

/// The ＋ / reset / − zoom buttons overlaid on the scan photo (spec 0045).
class _ScanZoomControls extends StatelessWidget {
  const _ScanZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: const StadiumBorder(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: scanZoomInKey,
            icon: const Icon(Icons.add),
            tooltip: 'Zoom inn',
            onPressed: onZoomIn,
          ),
          IconButton(
            key: scanZoomResetKey,
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Nullstill zoom',
            onPressed: onReset,
          ),
          IconButton(
            key: scanZoomOutKey,
            icon: const Icon(Icons.remove),
            tooltip: 'Zoom ut',
            onPressed: onZoomOut,
          ),
        ],
      ),
    );
  }
}

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

  static const double _minScale = 1;
  static const double _maxScale = 6;

  _ScanMode _mode = _ScanMode.capture;
  Uint8List? _imageBytes;
  PixelPoint? _centre;
  double? _pixelsPerMm;
  double _boxSide = 0;
  bool _analysing = false;
  final List<_Candidate> _candidates = <_Candidate>[];
  int? _draggingIndex;

  // The calibration centre / scale at the start of a pan-pinch gesture.
  PixelPoint? _gestureStartCentre;
  double? _gestureStartPixelsPerMm;
  PixelPoint? _gestureStartFocal;

  /// Pan/zoom of the photo while placing shots, so a hole can be marked
  /// precisely. Pointer coordinates reach the overlay already mapped back into
  /// the photo's own space, so the calibration is unaffected by the zoom.
  final TransformationController _transform = TransformationController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDisclosure());
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  double get _currentScale => _transform.value.getMaxScaleOnAxis();

  /// Sets a centred zoom level on the photo, clamped to [_minScale].._maxScale.
  void _zoomTo(double target, double side) {
    final clamped = target.clamp(_minScale, _maxScale);
    final translate = (side / 2) * (1 - clamped);
    _transform.value = Matrix4.identity()
      ..setEntry(0, 0, clamped)
      ..setEntry(1, 1, clamped)
      ..setEntry(0, 3, translate)
      ..setEntry(1, 3, translate);
  }

  /// Shows the one-time training-data disclosure on the first scan (spec 0041).
  void _maybeShowDisclosure() {
    if (!mounted) return;
    if (ref.read(contributionConsentProvider).disclosureShown) return;
    ref.read(contributionConsentProvider.notifier).markDisclosureShown();
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const ContributionDisclosureDialog(),
      ),
    );
  }

  TargetCalibration get _calibration =>
      TargetCalibration(centre: _centre!, pixelsPerMm: _pixelsPerMm!);

  /// Records the calibration at the start of a pan-pinch gesture (calibrate).
  void _calibrateStart(ScaleStartDetails details) {
    _gestureStartCentre = _centre;
    _gestureStartPixelsPerMm = _pixelsPerMm;
    _gestureStartFocal = PixelPoint(
      details.localFocalPoint.dx,
      details.localFocalPoint.dy,
    );
  }

  /// Moves (pan) and scales (pinch) the ring overlay to fit the photographed
  /// target: a one-finger drag moves the centre, a pinch resizes about the
  /// fingers (spec 0046).
  void _calibrateUpdate(ScaleUpdateDetails details) {
    final startCentre = _gestureStartCentre;
    final startPixelsPerMm = _gestureStartPixelsPerMm;
    final startFocal = _gestureStartFocal;
    if (startCentre == null || startPixelsPerMm == null || startFocal == null) {
      return;
    }
    final next = calibrationAfterGesture(
      startCentre: startCentre,
      startPixelsPerMm: startPixelsPerMm,
      startFocal: startFocal,
      focal: PixelPoint(details.localFocalPoint.dx, details.localFocalPoint.dy),
      scale: details.scale,
    );
    setState(() {
      _centre = next.centre;
      _pixelsPerMm = next.pixelsPerMm;
    });
  }

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
        _transform.value = Matrix4.identity();
        setState(() {
          _imageBytes = image.bytes;
          _centre = null;
          _pixelsPerMm = null;
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

  /// Seeds the calibration from the photo box [side] the first time the photo
  /// is shown, so the ring overlay is visible before any adjustment: centred,
  /// with its outer ring about a third of the box across.
  void _seedCalibration(double side) {
    _boxSide = side;
    _centre ??= PixelPoint(side / 2, side / 2);
    _pixelsPerMm ??= (side * 0.3) / widget.geometry.maxScoringRadiusMm;
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
    final added = <_Candidate>[];
    for (final shot in detected) {
      if (added.length >= remaining) break;
      final duplicate = _candidates
          .followedBy(added)
          .any((existing) => _distanceMm(existing.shot, shot) < minSepMm);
      if (!duplicate) {
        added.add(_Candidate(shot, TrainingHoleSource.auto));
      }
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
      _candidates.add(
        _Candidate(
          _calibration.shotFor(PixelPoint(localPx.dx, localPx.dy)),
          TrainingHoleSource.manual,
        ),
      );
    });
  }

  void _pickUp(Offset localPx) {
    final press = PixelPoint(localPx.dx, localPx.dy);
    var nearest = -1;
    var nearestPx = double.infinity;
    for (var i = 0; i < _candidates.length; i++) {
      final markerPx = _calibration.imagePxFor(_candidates[i].shot);
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
      _candidates[index]
        ..shot = _calibration.shotFor(PixelPoint(localPx.dx, localPx.dy))
        ..edited = true;
    });
  }

  void _undo() {
    if (_candidates.isEmpty) return;
    setState(_candidates.removeLast);
  }

  void _confirm() {
    final shots = <Shot>[for (final c in _candidates) c.shot];
    _maybeContribute();
    Navigator.of(context).pop(shots);
  }

  /// Captures the scan as a consented training sample (spec 0041), best-effort
  /// and fire-and-forget: only when signed in and consent is on, so it never
  /// blocks the pop above and never throws.
  void _maybeContribute() {
    // Entirely best-effort and off the happy path: any failure (an unwired
    // provider in a test scope, a build error) must never break confirming.
    try {
      final bytes = _imageBytes;
      if (bytes == null || _candidates.isEmpty) return;
      final status = ref.read(authStateChangesProvider).value;
      final uid = status is SignedIn ? status.user.id : null;
      if (uid == null || !ref.read(contributionConsentProvider).enabled) return;
      final sample = TrainingSample(
        id: ref.read(sessionIdGeneratorProvider)(),
        imageBytes: bytes,
        geometry: widget.geometry,
        calibration: _calibration,
        boxSide: _boxSide,
        holes: <TrainingHole>[
          for (final c in _candidates)
            TrainingHole(shot: c.shot, source: c.source, edited: c.edited),
        ],
        capturedAt: DateTime.now(),
        appVersion: BuildInfo.label,
      );
      unawaited(
        ref
            .read(contributionServiceProvider)
            .contribute(sample)
            .catchError((Object _) {}),
      );
    } on Object {
      // Swallow — contributing training data never blocks a scan.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FrostedAppBar(
        title: const Text('Skann skive'),
        actions: [
          if (_imageBytes != null)
            IconButton(
              key: scanRetakeKey,
              icon: const Icon(Icons.restart_alt),
              tooltip: 'Ta nytt bilde',
              onPressed: () {
                _transform.value = Matrix4.identity();
                setState(() {
                  _imageBytes = null;
                  _mode = _ScanMode.capture;
                });
              },
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
        _seedCalibration(side);
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
            // Zoom + pan while placing shots (not while calibrating, where the
            // two handles are dragged directly). A single-finger drag pans, a
            // pinch (or the on-photo buttons / trackpad scroll) zooms; the
            // overlay's pointer coordinates are mapped back to the photo's own
            // space, so the calibration and scoring are unaffected.
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: _minScale,
              maxScale: _maxScale,
              trackpadScrollCausesScale: true,
              panEnabled: !calibrating,
              scaleEnabled: !calibrating,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      key: scanOverlayKey,
                      behavior: HitTestBehavior.opaque,
                      // Calibrating: drag to move and pinch to scale the ring
                      // overlay onto the target. Placing: tap to place a shot,
                      // long-press to drag one.
                      onScaleStart: calibrating ? _calibrateStart : null,
                      onScaleUpdate: calibrating ? _calibrateUpdate : null,
                      onTapUp: calibrating
                          ? null
                          : (d) => _placeAt(d.localPosition),
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
                          shots: <Shot>[for (final c in _candidates) c.shot],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!calibrating)
            Positioned(
              right: 8,
              bottom: 8,
              child: _ScanZoomControls(
                onZoomIn: () => _zoomTo(_currentScale * 1.6, side),
                onZoomOut: () => _zoomTo(_currentScale / 1.6, side),
                onReset: () => _zoomTo(1, side),
              ),
            ),
        ],
      ),
    );
  }

  Widget _calibrateControls(TargetCalibration calibration) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dra for å flytte ringene og knip for å skalere dem, til de ligger '
          'oppå skiva på bildet.',
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
    final lastShot = _candidates.isEmpty ? null : _candidates.last.shot;
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
