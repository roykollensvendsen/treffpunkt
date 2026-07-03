// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

/// The wire marker for a mention (spec 0120): `@[Navn]`. Display names carry
/// spaces, so the brackets delimit the name; old clients show the raw marker,
/// which stays readable.
final RegExp _mention = RegExp(r'@\[([^\]]+)\]');

/// Splits [body] into spans where every `@[Navn]` marker is a highlighted,
/// bold `@Navn` in the [accent] colour and everything else is plain text.
List<InlineSpan> mentionSpans(String body, {required Color accent}) {
  final spans = <InlineSpan>[];
  var at = 0;
  for (final match in _mention.allMatches(body)) {
    if (match.start > at) {
      spans.add(TextSpan(text: body.substring(at, match.start)));
    }
    spans.add(
      TextSpan(
        text: '@${match.group(1)}',
        style: TextStyle(color: accent, fontWeight: FontWeight.bold),
      ),
    );
    at = match.end;
  }
  if (at < body.length || spans.isEmpty) {
    spans.add(TextSpan(text: body.substring(at)));
  }
  return spans;
}

/// The names tagged in [body], in order.
List<String> mentionNames(String body) =>
    _mention.allMatches(body).map((m) => m.group(1)!).toList();

/// Wraps a name as the wire marker the composer inserts.
String mentionMarker(String name) => '@[$name]';
