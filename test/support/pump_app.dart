// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Shared widget-test shell: every widget test mounts its screen inside the
// same ProviderScope + MaterialApp skeleton, so that skeleton lives here once.
// Tests state only what varies — the screen and its provider overrides.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// The main flutter_riverpod library does not re-export the Override type;
// its misc.dart companion library does.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// The standard test app shell: [home] inside a [MaterialApp] inside a
/// [ProviderScope] with [overrides].
///
/// Use this instead of [pumpApp] when the test needs the widget itself, for
/// example to re-pump the same tree after mutating a fake.
Widget buildApp({
  required Widget home,
  List<Override> overrides = const <Override>[],
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(home: home),
);

/// Pumps the [buildApp] shell around [home] into [tester].
Future<void> pumpApp(
  WidgetTester tester, {
  required Widget home,
  List<Override> overrides = const <Override>[],
}) => tester.pumpWidget(buildApp(home: home, overrides: overrides));
