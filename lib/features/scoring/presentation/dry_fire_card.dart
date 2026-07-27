// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_entry.dart';
import 'package:treffpunkt/features/scoring/domain/dry_fire_totals.dart';
import 'package:treffpunkt/features/scoring/presentation/dry_fire_providers.dart';

/// The Tørrtrening card on Hjem, and the sheet it opens (spec 0161).
const Key dryFireCardKey = ValueKey<String>('dryFireCard');

/// The «Antall avtrekk» field in the register sheet (spec 0161).
const Key dryFireCountFieldKey = ValueKey<String>('dryFireCountField');

/// The «Registrer» button in the register sheet (spec 0161).
const Key dryFireRegisterKey = ValueKey<String>('dryFireRegister');

/// A front-page card for logging dry-fire practice (spec 0161).
///
/// Shows the cumulative trigger-pull totals per discipline, or an invite when
/// nothing is recorded yet; tapping opens the register sheet.
class DryFireCard extends ConsumerWidget {
  /// Creates the Tørrtrening card.
  const DryFireCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(dryFireLogProvider).value ?? const <DryFireEntry>[];
    final totals = DryFireTotals.of(log);
    final subtitle = totals.isEmpty
        ? 'Registrer tørravtrekk'
        : 'Presisjon ${totals.forDiscipline(DryFireDiscipline.presisjon)} · '
              'Duell ${totals.forDiscipline(DryFireDiscipline.duell)}';

    return Card(
      child: ListTile(
        key: dryFireCardKey,
        // A tap-to-aim glyph for trigger training — deliberately not a target
        // face (spec 0161 keeps the discipline a label, not a drawn target).
        leading: const Icon(Icons.ads_click),
        title: const Text('Tørrtrening'),
        subtitle: Text(subtitle),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _DryFireSheet(),
        ),
      ),
    );
  }
}

class _DryFireSheet extends ConsumerStatefulWidget {
  const _DryFireSheet();

  @override
  ConsumerState<_DryFireSheet> createState() => _DryFireSheetState();
}

class _DryFireSheetState extends ConsumerState<_DryFireSheet> {
  // The sheet owns this controller and disposes it (Flutter/Riverpod gotcha:
  // a dialog-owned controller must be disposed here, not by a provider).
  final _count = TextEditingController();
  DryFireDiscipline _discipline = DryFireDiscipline.presisjon;
  String? _error;

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final pulls = int.tryParse(_count.text.trim());
    if (pulls == null || pulls <= 0) {
      setState(() => _error = 'Skriv inn et antall over 0');
      return;
    }
    await ref.read(dryFireLogProvider.notifier).register(_discipline, pulls);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Registrert: $pulls avtrekk (${_discipline.label})',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lift the sheet above the keyboard while typing the count.
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tørrtrening',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          SegmentedButton<DryFireDiscipline>(
            segments: [
              for (final discipline in DryFireDiscipline.values)
                ButtonSegment<DryFireDiscipline>(
                  value: discipline,
                  label: Text(discipline.label),
                ),
            ],
            selected: {_discipline},
            onSelectionChanged: (selection) =>
                setState(() => _discipline = selection.first),
          ),
          const SizedBox(height: 16),
          TextField(
            key: dryFireCountFieldKey,
            controller: _count,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Antall avtrekk',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _register(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: dryFireRegisterKey,
            onPressed: _register,
            child: const Text('Registrer'),
          ),
        ],
      ),
    );
  }
}
