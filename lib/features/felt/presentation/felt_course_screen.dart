// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art_data.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art_painter.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';
import 'package:treffpunkt/features/felt/presentation/felt_record_screen.dart';
import 'package:treffpunkt/features/felt/presentation/felt_setup_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/program_picker_screen.dart'
    show confirmDestructiveKey;

/// Key for the "shoot the course" button on the preview (spec 0080), for tests.
const Key feltShootButtonKey = ValueKey<String>('feltShoot');

/// Key for the "Fortsett felt-økt" resume card (spec 0081), for tests.
const Key feltResumeCardKey = ValueKey<String>('feltResume');

/// Key for the resume card's discard button (spec 0081), for tests.
const Key feltDiscardCardKey = ValueKey<String>('feltDiscard');

/// Key for hold [number]'s card in the course preview (spec 0068), for tests.
Key feltHoldCardKey(int number) => ValueKey<String>('feltHold-$number');

/// A preview of the NorgesFelt 2026 field course (specs 0068/0079): the 8 holds
/// each drawn as one composed picture matching the official target sheet, with
/// a "Skyt løypa" recorder (spec 0080) and a "Fortsett felt-økt" card to resume
/// a saved round (spec 0081).
class FeltCourseScreen extends ConsumerWidget {
  /// Creates the course preview.
  const FeltCourseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final saved = ref.watch(feltSavedSessionProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('NorgesFelt-løype 2026')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                Card(
                  color: theme.colorScheme.secondaryContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      '8 hold · innertreff på alle figurer · 10 sek skytetid · '
                      'maks 80/47 poeng. Hvert hold er tegnet som på den '
                      'offisielle skiva.',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (saved != null && saved.totalShots > 0)
                  Card(
                    key: feltResumeCardKey,
                    color: theme.colorScheme.secondaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.play_circle_outline),
                      title: const Text('Fortsett felt-økt'),
                      subtitle: Text(
                        '${saved.group.label} · Hold ${saved.currentHold + 1} '
                        '· ${saved.totalShots} skudd plassert',
                      ),
                      trailing: IconButton(
                        key: feltDiscardCardKey,
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Forkast lagret økt',
                        onPressed: () => unawaited(_discard(context, ref)),
                      ),
                      onTap: () => unawaited(_resume(context, ref, saved)),
                    ),
                  ),
                FilledButton.icon(
                  key: feltShootButtonKey,
                  onPressed: () => unawaited(_shoot(context, ref)),
                  icon: const Icon(Icons.my_location),
                  label: const Text('Skyt løypa'),
                ),
                const SizedBox(height: 8),
                for (final hold in norgesfelt2026)
                  Card(
                    key: feltHoldCardKey(hold.number),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Hold ${hold.number}  ·  ${hold.distance}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            hold.position,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FeltHoldArtView(art: _artFor(hold.number)),
                          const SizedBox(height: 8),
                          Text(
                            'Figurer: '
                            '${hold.figures.map((f) => f.name).join(', ')}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shoot(BuildContext context, WidgetRef ref) async {
    // The setup step first (spec 0092): date/time, place and weapon —
    // the same form the ring programs use.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => FeltSetupScreen()),
    );
    ref.invalidate(feltSavedSessionProvider);
  }

  Future<void> _resume(
    BuildContext context,
    WidgetRef ref,
    FeltSessionSnapshot saved,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FeltRecordScreen(restored: saved),
      ),
    );
    ref.invalidate(feltSavedSessionProvider);
  }

  /// Discards the saved round after a confirmation (spec 0096).
  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Forkast lagret økt?'),
        content: const Text('Handlingen kan ikke angres.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            key: confirmDestructiveKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Slett'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(feltSessionStoreProvider).clear();
    ref.invalidate(feltSavedSessionProvider);
  }
}

/// The composed art for hold [number] (spec 0079).
FeltHoldArt _artFor(int number) =>
    norgesfelt2026Art.firstWhere((a) => a.number == number);
