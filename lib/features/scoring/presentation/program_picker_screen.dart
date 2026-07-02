// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/presentation/build_version_label.dart';
import 'package:treffpunkt/core/presentation/layout.dart';
import 'package:treffpunkt/core/presentation/tappable_card_tile.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/competitions/presentation/competitions_screen.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';
import 'package:treffpunkt/features/forum/presentation/forum_screen.dart';
import 'package:treffpunkt/features/help/presentation/help_screen.dart';
import 'package:treffpunkt/features/notifications/presentation/notifications_screen.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/program_category.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/program_category_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/series_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

/// Key for the "resume saved session" card, used by tests.
const Key resumeSessionKey = ValueKey<String>('resumeSession');

/// Key for the "discard saved session" action on the resume card (for tests).
const Key discardSessionKey = ValueKey<String>('discardSession');

/// Key for the "My sessions" app-bar action, used by tests (spec 0026).
const Key mySessionsButtonKey = ValueKey<String>('mySessionsButton');

/// Key for the confirm action in destructive dialogs (spec 0096), for tests.
const Key confirmDestructiveKey = ValueKey<String>('confirmDestructive');

/// The front page of the picker: the four program categories (spec 0084) —
/// NSF Luft, NSF Fin/Grov, MIL and Felt. Tapping a category opens its
/// [ProgramCategoryScreen], where the shooter picks the program (spec 0008).
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

  /// Opens [category]'s page, then refreshes the resume card on return.
  ///
  /// The flow below may save a new in-progress recording (the shooter places a
  /// shot and leaves), so re-read the store to surface it as a resume card.
  Future<void> _openCategory(
    BuildContext context,
    WidgetRef ref,
    ProgramCategory category,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProgramCategoryScreen(category: category),
      ),
    );
    ref.invalidate(savedRecordingProvider);
  }

  /// Discards the saved session (spec 0009 req 4) after a confirmation
  /// (spec 0096 — the trash sits beside the resume tap target) and refreshes
  /// the card away.
  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    if (!await _confirmDestructive(context, title: 'Forkast lagret økt?')) {
      return;
    }
    await ref.read(sessionStoreProvider).clear();
    ref.invalidate(savedRecordingProvider);
  }

  /// The app's standard destructive-action confirmation (spec 0096).
  Future<bool> _confirmDestructive(
    BuildContext context, {
    required String title,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
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
    return confirmed ?? false;
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
          // The bell (spec 0094): a live unread badge; tapping opens Varsler.
          IconButton(
            key: notificationsBellKey,
            icon: Badge.count(
              key: notificationsBadgeKey,
              count: ref.watch(unreadNotificationsCountProvider),
              isLabelVisible: ref.watch(unreadNotificationsCountProvider) > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Varsler',
            onPressed: () => unawaited(
              Navigator.of(context)
                  .push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  )
                  .then((_) => ref.invalidate(notificationsProvider)),
            ),
          ),
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
                  constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
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
                              onPressed: () =>
                                  unawaited(_discard(context, ref)),
                            ),
                            onTap: () =>
                                unawaited(_resume(context, ref, saved)),
                          ),
                        ),
                      for (final category in ProgramCategory.values)
                        TappableCardTile(
                          tileKey: ValueKey<String>(
                            'category-${category.label}',
                          ),
                          title: category.label,
                          subtitle: _categorySubtitle(category),
                          semanticsLabel:
                              'Velg kategori: ${category.label}, '
                              '${_categorySubtitle(category)}',
                          onTap: () => unawaited(
                            _openCategory(context, ref, category),
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

String _categorySubtitle(ProgramCategory category) {
  final count = ProgramCatalogue.inCategory(category).length;
  if (count == 0) return category.description;
  final programs = count == 1 ? '1 program' : '$count programmer';
  return '${category.description} · $programs';
}
