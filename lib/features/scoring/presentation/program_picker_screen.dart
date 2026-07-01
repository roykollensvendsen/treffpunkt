// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/presentation/build_version_label.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/competitions/presentation/competitions_screen.dart';
import 'package:treffpunkt/features/felt/presentation/felt_course_screen.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';
import 'package:treffpunkt/features/forum/presentation/forum_screen.dart';
import 'package:treffpunkt/features/help/presentation/help_screen.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/series_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/session_setup_screen.dart';

/// Key for the "resume saved session" card, used by tests.
const Key resumeSessionKey = ValueKey<String>('resumeSession');

/// Key for the "discard saved session" action on the resume card (for tests).
const Key discardSessionKey = ValueKey<String>('discardSession');

/// Key for the "My sessions" app-bar action, used by tests (spec 0026).
const Key mySessionsButtonKey = ValueKey<String>('mySessionsButton');

/// Lets the shooter choose which official program to shoot, then opens the
/// session setup step (date, time and place) before shooting (spec 0008).
///
/// When a saved session is stored locally (spec 0009), a "Fortsett økt" card at
/// the top reopens the shooting screen restored to the exact saved state — the
/// in-progress series included.
class ProgramPickerScreen extends ConsumerWidget {
  /// Creates the picker with optional app-bar [actions].
  const ProgramPickerScreen({this.actions, super.key});

  /// Extra actions shown in the app bar (e.g. a sign-out button).
  final List<Widget>? actions;

  /// Reopens the saved session, then refreshes the resume card on return.
  ///
  /// The card is fed by [savedRecordingProvider], a one-shot read of the store.
  /// A resumed session keeps persisting (and clears the store when complete),
  /// so on return we re-read the store to drop a finished session's card or
  /// pick up a still-in-progress one — the store is the single source of truth.
  Future<void> _resume(
    BuildContext context,
    WidgetRef ref,
    SessionRecording recording,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SeriesScreen(
          program: recording.session.program,
          metadata: recording.session.metadata,
          weapon: recording.session.weapon,
          restored: recording,
        ),
      ),
    );
    ref.invalidate(savedRecordingProvider);
  }

  /// Opens [definition]'s setup step, then refreshes the resume card on return.
  ///
  /// The setup flow may save a new in-progress recording (the shooter places a
  /// shot and leaves), so re-read the store to surface it as a resume card.
  Future<void> _startProgram(
    BuildContext context,
    WidgetRef ref,
    ProgramDefinition definition,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionSetupScreen(program: definition),
      ),
    );
    ref.invalidate(savedRecordingProvider);
  }

  /// Discards the saved session (spec 0009 req 4) and refreshes the card away.
  Future<void> _discard(WidgetRef ref) async {
    await ref.read(sessionStoreProvider).clear();
    ref.invalidate(savedRecordingProvider);
  }

  /// Opens the "My sessions" history (spec 0026), then refreshes the resume
  /// card on return (the same store re-read the other navigations do).
  ///
  /// Invalidates the background reads **before** pushing the screen so they
  /// re-run each time the history is opened: [syncedSessionsProvider] re-reads
  /// the account (`SessionRepository.list()`), surfacing sessions that have
  /// synced since it was last viewed, and [storedPendingProvider] re-reads the
  /// durable outbox. The pending half stays live on its own (the screen watches
  /// the upload queue), so the local sessions never wait on either read.
  /// Opens the competitions hub (spec 0011), refreshing its background reads
  /// first so newly created or accepted competitions show on open.
  Future<void> _openCompetitions(BuildContext context, WidgetRef ref) async {
    ref
      ..invalidate(myCompetitionsProvider)
      ..invalidate(myInvitationsProvider);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CompetitionsScreen()),
    );
  }

  Future<void> _openMySessions(BuildContext context, WidgetRef ref) async {
    ref
      ..invalidate(syncedSessionsProvider)
      ..invalidate(storedPendingProvider)
      ..invalidate(feltHistoryProvider)
      ..invalidate(feltSyncedSessionsProvider);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MySessionsScreen()),
    );
    ref.invalidate(savedRecordingProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedRecordingProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Velg program'),
        actions: [
          IconButton(
            key: competitionsButtonKey,
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'Konkurranser',
            onPressed: () => unawaited(_openCompetitions(context, ref)),
          ),
          IconButton(
            key: mySessionsButtonKey,
            icon: const Icon(Icons.history),
            tooltip: 'Mine økter',
            onPressed: () => unawaited(_openMySessions(context, ref)),
          ),
          IconButton(
            key: forumButtonKey,
            icon: const Icon(Icons.forum_outlined),
            tooltip: 'Forum',
            onPressed: () => unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ForumScreen()),
              ),
            ),
          ),
          IconButton(
            key: helpButtonKey,
            icon: const Icon(Icons.help_outline),
            tooltip: 'Brukerveiledning',
            onPressed: () => unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
              ),
            ),
          ),
          ...?actions,
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (saved != null)
                        Card(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          child: ListTile(
                            key: resumeSessionKey,
                            leading: const Icon(Icons.play_circle_outline),
                            title: const Text('Fortsett økt'),
                            subtitle: Text(_resumeSubtitle(saved)),
                            trailing: IconButton(
                              key: discardSessionKey,
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Forkast lagret økt',
                              onPressed: () => unawaited(_discard(ref)),
                            ),
                            onTap: () =>
                                unawaited(_resume(context, ref, saved)),
                          ),
                        ),
                      for (final definition in ProgramCatalogue.all)
                        Card(
                          child: Semantics(
                            button: true,
                            label:
                                'Velg program: ${definition.name}, '
                                '${_subtitle(definition)}',
                            // Carry the tap action on the SAME node as the
                            // label so a screen reader can activate the tile;
                            // `ExcludeSemantics` would otherwise drop the
                            // ListTile's own tap action.
                            onTap: () => unawaited(
                              _startProgram(context, ref, definition),
                            ),
                            child: ExcludeSemantics(
                              child: ListTile(
                                key: ValueKey<String>(
                                  'program-${definition.name}',
                                ),
                                title: Text(definition.name),
                                subtitle: Text(_subtitle(definition)),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => unawaited(
                                  _startProgram(context, ref, definition),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(4, 16, 4, 4),
                        child: Text(
                          'Feltskyting',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Card(
                        child: ListTile(
                          key: const ValueKey<String>('felt-norgesfelt-2026'),
                          title: const Text('NorgesFelt-løype 2026'),
                          subtitle: const Text(
                            'Forhåndsvis de 8 holdene og figurene',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => unawaited(
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const FeltCourseScreen(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // A discreet build-version footer below the program list so a user
            // can confirm which build they are running (spec 0028).
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: BuildVersionLabel(),
            ),
          ],
        ),
      ),
    );
  }
}

String _resumeSubtitle(SessionRecording recording) {
  final placed = recording.current?.placedCount ?? 0;
  return '${recording.session.program.name} · $placed skudd plassert';
}

String _subtitle(ProgramDefinition definition) {
  final discipline = definition.discipline == Discipline.rifle
      ? 'Rifle'
      : 'Pistol';
  return '$discipline · ${definition.totalShots} skudd';
}
