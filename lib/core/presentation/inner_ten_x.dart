// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

/// The inner-ten ("X") badge: a capital **X inside a thin ring**, the way an
/// innertier is marked on a paper target.
///
/// It is *drawn* (a bordered box), not a font glyph, so it looks identical on
/// every platform — the web included — and matches the size and colour of the
/// score text it sits beside. Built with [innerTenScoreText] (spec 0023).
class InnerTenX extends StatelessWidget {
  /// Creates a ringed X sized to [fontSize] and painted in [color].
  const InnerTenX({required this.fontSize, required this.color, super.key});

  /// Font size of the surrounding score text; the ring is sized from it.
  final double fontSize;

  /// Colour of the ring and the X — taken from the surrounding text.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final diameter = fontSize + 4;
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: fontSize < 16 ? 1 : 1.4),
      ),
      child: Text(
        'X',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize * 0.66,
          height: 1,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// The score line "[lead]", optionally followed by "[separator]N Ⓧ" where the
/// X is the drawn [InnerTenX] ring, when there are any inner tens.
///
/// When [innerTens] is `0` it is a plain [Text] of [lead]. The X-count is shown
/// as a ring round the X (not "×X"), so it reads as an inner ten rather than a
/// multiplication (spec 0023). Callers that need a spoken form usually wrap the
/// result in their own `Semantics`; [semanticsLabel] is offered for the rest.
Widget innerTenScoreText({
  required BuildContext context,
  required String lead,
  required int innerTens,
  TextStyle? style,
  String separator = ' · ',
  String? semanticsLabel,
}) {
  if (innerTens <= 0) {
    return Text(lead, style: style, semanticsLabel: semanticsLabel);
  }
  final resolved = DefaultTextStyle.of(context).style.merge(style);
  final fontSize = resolved.fontSize ?? 14;
  final color = resolved.color ?? Theme.of(context).colorScheme.onSurface;
  return Text.rich(
    TextSpan(
      style: style,
      children: <InlineSpan>[
        TextSpan(text: '$lead$separator$innerTens '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: InnerTenX(fontSize: fontSize, color: color),
        ),
      ],
    ),
    semanticsLabel: semanticsLabel,
  );
}
