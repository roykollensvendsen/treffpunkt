// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/presentation/target_canvas.dart';

/// The screen showing the 10 m air-rifle target.
class TargetScreen extends StatelessWidget {
  /// Creates the target screen with optional app-bar [actions].
  const TargetScreen({this.actions, super.key});

  /// Extra actions shown in the app bar (e.g. a sign-out button).
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('10 m Air Rifle'), actions: actions),
      body: const SafeArea(
        child: TargetCanvas(geometry: TargetGeometry.airRifle10m()),
      ),
    );
  }
}
