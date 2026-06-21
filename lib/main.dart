// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/domain/target_geometry.dart';
import 'package:treffpunkt/features/scoring/presentation/target_canvas.dart';

void main() {
  runApp(const ProviderScope(child: TreffpunktApp()));
}

/// The Treffpunkt application root.
class TreffpunktApp extends StatelessWidget {
  /// Creates the application root.
  const TreffpunktApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Treffpunkt',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const TargetScreen(),
    );
  }
}

/// The screen showing the 10 m air-rifle target.
class TargetScreen extends StatelessWidget {
  /// Creates the target screen.
  const TargetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('10 m Air Rifle')),
      body: const SafeArea(
        child: TargetCanvas(geometry: TargetGeometry.airRifle10m()),
      ),
    );
  }
}
