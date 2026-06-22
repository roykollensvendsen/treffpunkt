// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/presentation/series_screen.dart';

/// Lets the shooter choose which official program to shoot, then opens the
/// series screen for it.
///
/// For now a program opens its first stage as a single series; the full guided
/// multi-stage flow follows.
class ProgramPickerScreen extends StatelessWidget {
  /// Creates the picker with optional app-bar [actions].
  const ProgramPickerScreen({this.actions, super.key});

  /// Extra actions shown in the app bar (e.g. a sign-out button).
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a program'), actions: actions),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final definition in ProgramCatalogue.all)
              Card(
                child: ListTile(
                  key: ValueKey<String>('program-${definition.name}'),
                  title: Text(definition.name),
                  subtitle: Text(_subtitle(definition)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SeriesScreen(program: definition),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _subtitle(ProgramDefinition definition) {
  final discipline = definition.discipline == Discipline.rifle
      ? 'Rifle'
      : 'Pistol';
  return '$discipline · ${definition.totalShots} shots';
}
