// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

/// Wraps a shot-placement target with a magnifier loupe (spec 0150).
///
/// While a single finger presses or drags on the [child], a small circular,
/// magnified view of the area under the finger floats above it with a
/// crosshair, so the finger never hides the point being set. A [Listener]
/// tracks pointers without joining the gesture arena, so the child's taps,
/// long-presses and pinches are untouched; the loupe is [IgnorePointer]. It
/// shows only for a single pointer — a two-finger pinch-zoom raises none.
class MagnifierOverlay extends StatefulWidget {
  /// Wraps [child] with the loupe overlay. Set [enabled] to false to keep the
  /// pointer tracking off entirely (e.g. a non-touch context).
  const MagnifierOverlay({required this.child, this.enabled = true, super.key});

  /// The interactive target (e.g. the target painter, kept inside its own
  /// `InteractiveViewer` so the loupe sits in untransformed space above it).
  final Widget child;

  /// Whether the loupe is shown at all.
  final bool enabled;

  @override
  State<MagnifierOverlay> createState() => _MagnifierOverlayState();
}

class _MagnifierOverlayState extends State<MagnifierOverlay> {
  final Set<int> _pointers = <int>{};
  Offset? _focal;

  void _sync(Offset? position) {
    // A single pointer means "placing/moving": show the loupe. Zero or two+
    // (a pinch) means no loupe.
    final next = (_pointers.length == 1) ? position : null;
    if (next != _focal) setState(() => _focal = next);
  }

  void _down(PointerDownEvent event) {
    _pointers.add(event.pointer);
    _sync(event.localPosition);
  }

  void _release(int pointer) {
    _pointers.remove(pointer);
    _sync(null);
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
        onPointerMove: (event) {
          if (_pointers.length == 1) _sync(event.localPosition);
        },
        onPointerUp: (event) => _release(event.pointer),
        onPointerCancel: (event) => _release(event.pointer),
        child: Stack(
          children: <Widget>[
            widget.child,
            if (_focal != null)
              TargetLoupe(focal: _focal!, area: constraints.biggest),
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
  const TargetLoupe({required this.focal, required this.area, super.key});

  /// The point under the finger, in the overlay's local coordinates.
  final Offset focal;

  /// The overlay's size, so the loupe stays on-screen.
  final Size area;

  /// Loupe diameter.
  static const double diameter = 96;

  /// How far the loupe floats from the finger.
  static const double lift = 96;

  /// Magnification factor.
  static const double magnification = 1.8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Float above the finger; flip below when that would clip the top edge.
    final fitsAbove = focal.dy - lift - diameter / 2 >= 0;
    final centreY = focal.dy + (fitsAbove ? -lift : lift);
    final centreX = focal.dx.clamp(diameter / 2, area.width - diameter / 2);
    // Keep the crosshair on the true finger point even when the glass is
    // nudged to stay on-screen: focalPointOffset shifts what the lens shows
    // relative to its own centre (Flutter's RawMagnifier contract).
    final focalOffset = Offset(focal.dx - centreX, focal.dy - centreY);
    return Positioned(
      left: centreX - diameter / 2,
      top: centreY - diameter / 2,
      child: IgnorePointer(
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
    );
  }
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
