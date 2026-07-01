// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Unit test for the app scroll behaviour (spec 0074): the mouse and trackpad
// can drag scrollables, so horizontal strips work on desktop/web.
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/app_scroll_behavior.dart';

void main() {
  test('the mouse and trackpad can drag-scroll (spec 0074)', () {
    final devices = const AppScrollBehavior().dragDevices;
    expect(devices, contains(PointerDeviceKind.mouse));
    expect(devices, contains(PointerDeviceKind.trackpad));
    expect(devices, contains(PointerDeviceKind.touch));
  });
}
