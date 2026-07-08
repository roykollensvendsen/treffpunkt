// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

/// Reports where a single-finger placement gesture ended (spec 0150): the
/// release [position] in the overlay's local (viewport) coordinates, and
/// whether the finger [moved] beyond touch slop before release. Not called
/// for a pinch or a cancelled gesture.
typedef LoupeCommit = void Function(Offset position, {required bool moved});

/// Wraps a shot-placement target with a magnifier loupe (spec 0150).
///
/// While a single finger presses or drags on the [child], a small circular,
/// magnified view of the area under the finger floats above it with a
/// crosshair, so the finger never hides the point being set. A [Listener]
/// tracks pointers without joining the gesture arena, so the child's taps,
/// long-presses and pinches are untouched; the loupe is [IgnorePointer]. It
/// shows only for a single pointer — a two-finger pinch-zoom raises none.
///
/// [onCommit] fires on the release of a single-finger gesture with the
/// release point, so a shot lands **where the finger lifts** even after
/// sliding to aim with the loupe (spec 0151) — not where it first touched.
class MagnifierOverlay extends StatefulWidget {
  /// Wraps [child] with the loupe overlay. Set [enabled] to false to keep the
  /// pointer tracking off entirely (e.g. a non-touch context).
  const MagnifierOverlay({
    required this.child,
    this.enabled = true,
    this.onCommit,
    this.readoutAt,
    super.key,
  });

  /// The interactive target (e.g. the target painter, kept inside its own
  /// `InteractiveViewer` so the loupe sits in untransformed space above it).
  final Widget child;

  /// Whether the loupe is shown at all.
  final bool enabled;

  /// Called on the release of a single-finger gesture (spec 0151).
  final LoupeCommit? onCommit;

  /// A live readout for the point under the finger (spec 0153): given the
  /// current focal (viewport) point, returns a short label — e.g. the decimal
  /// score «10,4» — drawn as a badge on the loupe. Null result, or no
  /// callback, shows no badge.
  final String? Function(Offset focal)? readoutAt;

  @override
  State<MagnifierOverlay> createState() => _MagnifierOverlayState();
}

class _MagnifierOverlayState extends State<MagnifierOverlay> {
  /// A finger that travels more than this (logical px) has "moved" — a slide,
  /// not a tap.
  static const double _slop = 8;

  final Set<int> _pointers = <int>{};
  Offset? _focal;
  Offset _downAt = Offset.zero;
  bool _moved = false;
  bool _wasPinch = false;

  void _sync(Offset? position) {
    // A single pointer means "placing/moving": show the loupe. Zero or two+
    // (a pinch) means no loupe.
    final next = (_pointers.length == 1) ? position : null;
    if (next != _focal) setState(() => _focal = next);
  }

  void _down(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (_pointers.length >= 2) {
      _wasPinch = true;
    } else {
      _downAt = event.localPosition;
      _moved = false;
      _wasPinch = false;
    }
    _sync(event.localPosition);
  }

  void _move(PointerMoveEvent event) {
    if (_pointers.length != 1) return;
    if ((event.localPosition - _downAt).distance > _slop) _moved = true;
    _sync(event.localPosition);
  }

  void _release(PointerEvent event, {required bool committed}) {
    final wasLast = _pointers.length == 1;
    _pointers.remove(event.pointer);
    if (wasLast) {
      // The last finger lifted: a single-finger gesture ended. Commit the
      // placement at the lift point unless it was ever part of a pinch.
      if (committed && !_wasPinch) {
        widget.onCommit?.call(event.localPosition, moved: _moved);
      }
      setState(() => _focal = null);
    } else {
      _sync(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return LayoutBuilder(
      builder: (context, constraints) => Listener(
        // Opaque so the overlay always sees pointers over the target area;
        // the child (in front) still receives them — opaque only blocks
        // siblings behind, not descendants.
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: (event) => _release(event, committed: true),
        onPointerCancel: (event) => _release(event, committed: false),
        child: Stack(
          children: <Widget>[
            widget.child,
            if (_focal != null)
              TargetLoupe(
                focal: _focal!,
                area: constraints.biggest,
                readout: widget.readoutAt?.call(_focal!),
              ),
          ],
        ),
      ),
    );
  }
}

/// The floating magnifier itself (spec 0150): a circular [RawMagnifier] over
/// the area under [focal], drawn above the finger (below it near the top
/// edge) and clamped inside [area], with a crosshair on the focal point.
class TargetLoupe extends StatelessWidget {
  /// Creates the loupe centred on the content under [focal].
  const TargetLoupe({
    required this.focal,
    required this.area,
    this.readout,
    super.key,
  });

  /// The point under the finger, in the overlay's local coordinates.
  final Offset focal;

  /// The overlay's size, so the loupe stays on-screen.
  final Size area;

  /// A short label (e.g. the decimal score «10,4») shown as a badge on the
  /// side of the loupe away from the finger (spec 0153), or null for none.
  final String? readout;

  /// Loupe diameter.
  static const double diameter = 96;

  /// How far the loupe floats from the finger.
  static const double lift = 96;

  /// Magnification factor.
  static const double magnification = 1.8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Stay above the finger as long as possible — the loupe may ride up to
    // half off the top edge (its centre, the crosshair, reaching the edge)
    // before it flips below the finger (spec 0152).
    final fitsAbove = focal.dy - lift >= 0;
    final centreY = focal.dy + (fitsAbove ? -lift : lift);
    final centreX = focal.dx.clamp(diameter / 2, area.width - diameter / 2);
    // Keep the crosshair on the true finger point even when the glass is
    // nudged to stay on-screen: focalPointOffset shifts what the lens shows
    // relative to its own centre (Flutter's RawMagnifier contract).
    final focalOffset = Offset(focal.dx - centreX, focal.dy - centreY);
    // The whole area, so the loupe and its badge can be positioned freely
    // over the target; nothing here takes pointers.
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: <Widget>[
            Positioned(
              left: centreX - diameter / 2,
              top: centreY - diameter / 2,
              child: RawMagnifier(
                size: const Size.square(diameter),
                magnificationScale: magnification,
                focalPointOffset: focalOffset,
                clipBehavior: Clip.hardEdge,
                decoration: MagnifierDecoration(
                  shape: CircleBorder(
                    side: BorderSide(color: scheme.primary, width: 2),
                  ),
                  shadows: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: _CrosshairPainter(scheme.primary),
                  size: const Size.square(diameter),
                ),
              ),
            ),
            if (readout != null)
              // The value badge on the far side of the loupe from the finger:
              // above the loupe when it floats above, below it when flipped.
              Positioned(
                left: centreX - 60,
                width: 120,
                top: fitsAbove
                    ? centreY - diameter / 2 - 28
                    : centreY + diameter / 2 + 6,
                child: Center(
                  child: _ScoreBadge(readout!, scheme),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The value pill drawn beside the loupe (spec 0153).
class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge(this.label, this.scheme);

  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(11),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
      ],
    ),
    child: Text(
      label,
      style: TextStyle(
        color: scheme.onPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 15,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    ),
  );
}

/// A small ring with a centre dot at the lens centre — the focal point.
class _CrosshairPainter extends CustomPainter {
  const _CrosshairPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    canvas
      ..drawCircle(centre, 7, ring)
      ..drawCircle(centre, 1.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CrosshairPainter old) => old.color != color;
}
