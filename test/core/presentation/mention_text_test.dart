// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit tests for the mention renderer (spec 0120): `@[Navn]` markers become
// highlighted `@Navn` spans, plain text passes through untouched.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/mention_text.dart';

void main() {
  const accent = Colors.deepPurple;

  String textOf(InlineSpan span) => (span as TextSpan).text!;

  test('plain text is one untouched span', () {
    final spans = mentionSpans('Hei på deg', accent: accent);
    expect(spans, hasLength(1));
    expect(textOf(spans.single), 'Hei på deg');
  });

  test('a marker renders as a highlighted @Navn (spec 0120)', () {
    final spans = mentionSpans(
      'Hei @[Roy Svendsen], ser du dette?',
      accent: accent,
    );
    expect(spans, hasLength(3));
    expect(textOf(spans[0]), 'Hei ');
    expect(textOf(spans[1]), '@Roy Svendsen');
    expect((spans[1] as TextSpan).style?.color, accent);
    expect((spans[1] as TextSpan).style?.fontWeight, FontWeight.bold);
    expect(textOf(spans[2]), ', ser du dette?');
  });

  test('several markers and edges parse cleanly', () {
    final spans = mentionSpans('@[A] og @[B]', accent: accent);
    expect(spans.map(textOf).toList(), ['@A', ' og ', '@B']);
  });

  test('an unclosed bracket stays literal', () {
    final spans = mentionSpans('epost@[stedet uten slutt', accent: accent);
    expect(spans, hasLength(1));
    expect(textOf(spans.single), 'epost@[stedet uten slutt');
  });

  test('mentionNames lists the tagged names', () {
    expect(mentionNames('Hei @[Roy] og @[Robot Hood]!'), ['Roy', 'Robot Hood']);
    expect(mentionNames('ingen her'), isEmpty);
  });
}
