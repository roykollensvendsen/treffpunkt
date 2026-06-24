// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/domain/session_snapshot.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/series_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/upload_queue.dart';

/// Key for the card of the saved session with the given [id], used by tests.
Key mySessionCard(String id) => ValueKey<String>('mySessionCard-$id');

/// Key for the overflow (Slett) menu on the session [id]'s card (spec 0033).
Key deleteSessionMenuKey(String id) =>
    ValueKey<String>('deleteSessionMenu-$id');

/// Key for the confirm action in the delete-session dialog (spec 0033).
const Key deleteSessionConfirmKey = ValueKey<String>('deleteSessionConfirm');

/// Key for the "not synced yet" badge on a pending session's card, used by
/// tests (spec 0026).
const Key notSyncedBadgeKey = ValueKey<String>('notSyncedBadge');

/// Key for the empty-state message when no session is saved, used by tests.
const Key noSessionsKey = ValueKey<String>('noSessions');

/// Key for the non-blocking banner shown when the cloud read fails, used by
/// tests (spec 0029).
const Key syncErrorBannerKey = ValueKey<String>('syncErrorBanner');

/// Key for the dismiss action on the sync-error banner, used by tests (spec
/// 0029).
const Key syncErrorDismissKey = ValueKey<String>('syncErrorDismiss');

/// Key for the "Velg program" call-to-action on the empty state, which returns
/// to the program picker; used by tests.
const Key pickProgramButtonKey = ValueKey<String>('pickProgramButton');

/// Key for the "cannot show this session" message in the detail view when a
/// stored payload names a program that no longer resolves, used by tests.
const Key unreadableSessionKey = ValueKey<String>('unreadableSession');

/// Comfortable maximum content width, matching the rest of the app.
const double _maxContentWidth = 700;

/// The "My sessions" screen (spec 0026): the shooter's saved sessions — synced
/// to the account (spec 0024) and waiting in the upload queue (spec 0025) —
/// most recent first, each opening its read-only scorecard.
///
/// The list is built **synchronously** so a slow or unavailable cloud read can
/// never hide a session the shooter has on the device. The **pending** (local)
/// rows come from the **live** upload queue ([uploadQueueProvider]) with no
/// await — the just-completed session is there instantly — folded with the
/// durable [storedPendingProvider] as a fallback. The **synced** rows from the
/// account ([syncedSessionsProvider]) are a pure enhancement that merges in
/// only once it resolves (`.value ?? const []`); every background source
/// contributes `const []` until ready (and stays best-effort), so the local
/// sessions always render at once and the screen never sits on a spinner
/// waiting on the network.
class MySessionsScreen extends ConsumerWidget {
  /// Creates the "My sessions" screen.
  const MySessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pending (local) sessions render immediately: the live queue is the
    // just-completed session's instant home, and the durable store is the
    // belt-and-suspenders fallback. The synced (cloud) read is layered on top
    // when it resolves — never awaited, so it can never hold up the list.
    final live = ref.watch(uploadQueueProvider);
    final stored = ref.watch(storedPendingProvider).value ?? const [];
    final syncedAsync = ref.watch(syncedSessionsProvider);
    final synced = syncedAsync.value ?? const <SessionRecord>[];
    // A cloud read that *failed* (not merely empty) — surface it, but never let
    // it hide the local sessions, which still render below (spec 0029).
    final syncFailed = syncedAsync.hasError;

    final pending = _unionById(<List<SessionRecord>>[stored, live]);
    final entries = mergeMySessions(synced: synced, pending: pending);

    return Scaffold(
      appBar: AppBar(title: const Text('Mine økter')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Column(
              children: [
                if (syncFailed) const _SyncErrorBanner(),
                Expanded(child: _SessionsList(entries: entries)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Unions the [sources] of pending records, deduplicated by id; a later
  /// source wins a tie, so passing `[stored, live]` keeps the freshest copy.
  static List<SessionRecord> _unionById(List<List<SessionRecord>> sources) {
    final byId = <String, SessionRecord>{};
    for (final source in sources) {
      for (final record in source) {
        byId[record.id] = record;
      }
    }
    return byId.values.toList();
  }
}

/// The loaded list of saved sessions, or the empty state when there are none.
class _SessionsList extends StatelessWidget {
  const _SessionsList({required this.entries});

  final List<MySessionEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _EmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) => _SessionCard(entry: entries[index]),
    );
  }
}

/// The friendly empty state: a cue that nothing is saved yet, a hint on how to
/// change that, and a call-to-action back to the program picker.
///
/// The screen is pushed from the picker, so the button just pops back to it
/// ([NavigatorState.maybePop]). The whole column is announced as one block to a
/// screen reader, with the actionable button kept tappable.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_toggle_off,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Ingen lagrede økter ennå',
              key: noSessionsKey,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fullfør en økt for å se den her.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: pickProgramButtonKey,
              onPressed: () => unawaited(Navigator.of(context).maybePop()),
              icon: const Icon(Icons.add),
              label: const Text('Velg program'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A non-blocking notice that the cloud read failed (spec 0029): the local
/// sessions still render below, so this only *explains* why synced sessions may
/// be missing — it never replaces the list. Dismissible, since the local
/// sessions remain usable regardless.
class _SyncErrorBanner extends StatefulWidget {
  const _SyncErrorBanner();

  @override
  State<_SyncErrorBanner> createState() => _SyncErrorBannerState();
}

class _SyncErrorBannerState extends State<_SyncErrorBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          key: syncErrorBannerKey,
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 18,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kunne ikke hente økter fra skyen — viser lokale.',
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                key: syncErrorDismissKey,
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                color: scheme.onErrorContainer,
                tooltip: 'Lukk',
                onPressed: () => setState(() => _dismissed = true),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the per-card overflow menu can do (spec 0033).
enum _SessionCardAction { delete }

/// One saved session as a tappable card: program, date/place, score, weapon
/// and a "not synced yet" badge on a pending entry; tapping opens the
/// scorecard, and a trailing menu can delete it (spec 0033).
class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.entry});

  final MySessionEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final record = entry.record;
    return Card(
      child: Row(
        children: [
          // The card body is one "open" button to a screen reader; the
          // menu beside it is a separate control (outside ExcludeSemantics).
          Expanded(
            child: Semantics(
              button: true,
              label: _semanticsLabel(entry),
              onTap: () => unawaited(_open(context)),
              child: ExcludeSemantics(
                child: ListTile(
                  key: mySessionCard(record.id),
                  title: Text(record.program),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_metaLine(record) case final meta?)
                        Text(
                          meta,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        _scoreLine(record),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (record.weaponName case final weapon?)
                        Text(
                          weapon,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (!entry.synced) ...[
                        const SizedBox(height: 6),
                        const _NotSyncedBadge(),
                      ],
                    ],
                  ),
                  isThreeLine: true,
                  onTap: () => unawaited(_open(context)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: PopupMenuButton<_SessionCardAction>(
              key: deleteSessionMenuKey(record.id),
              tooltip: 'Flere valg',
              onSelected: (_) => unawaited(_confirmAndDelete(context, ref)),
              itemBuilder: (_) => const <PopupMenuEntry<_SessionCardAction>>[
                PopupMenuItem<_SessionCardAction>(
                  value: _SessionCardAction.delete,
                  child: Text('Slett'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SessionDetailScreen(record: entry.record),
    ),
  );

  /// Confirms, then deletes the session from the cloud (when synced) and the
  /// local queue, refreshing the list (spec 0033). A pending-only session needs
  /// no network; a failed cloud delete leaves the card and shows a message.
  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    // Captured before the await so no BuildContext is used across the gap.
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Slett økt?'),
        content: const Text('Handlingen kan ikke angres.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            key: deleteSessionConfirmKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Slett'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final id = entry.record.id;
    try {
      if (entry.synced) {
        await ref.read(sessionRepositoryProvider).deleteById(id);
      }
      await ref.read(uploadQueueProvider.notifier).deleteById(id);
      ref
        ..invalidate(syncedSessionsProvider)
        ..invalidate(storedPendingProvider);
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke slette økta.')),
      );
    }
  }

  /// A spoken label for the whole card, consistent with the app's score labels.
  static String _semanticsLabel(MySessionEntry entry) {
    final record = entry.record;
    final parts = <String>[record.program];
    final meta = _metaLine(record);
    if (meta != null) parts.add(meta);
    parts.add(_scoreSpoken(record));
    if (record.weaponName case final weapon?) parts.add(weapon);
    if (!entry.synced) parts.add('Ikke synkronisert');
    return parts.join('. ');
  }
}

/// The one-line "date · place" caption for a saved session, or `null` when no
/// date was recorded.
String? _metaLine(SessionRecord record) {
  final at = record.capturedAt;
  if (at == null) return null;
  String two(int v) => v.toString().padLeft(2, '0');
  final date =
      '${at.year}-${two(at.month)}-${two(at.day)} '
      '${two(at.hour)}:${two(at.minute)}';
  final place = record.placeLabel;
  if (place != null && place.isNotEmpty) return '$date · $place';
  return date;
}

/// The score line `total / maxTotal`, with a `· N×X` suffix when there are any
/// inner tens.
String _scoreLine(SessionRecord record) {
  final suffix = record.innerTens > 0 ? ' · ${record.innerTens}×X' : '';
  return '${record.total} / ${record.maxTotal}$suffix';
}

/// The score spoken in words for a screen reader (e.g. "90 av 100, 2 indre
/// tiere").
String _scoreSpoken(SessionRecord record) {
  final innerTens = record.innerTens;
  final String suffix;
  if (innerTens <= 0) {
    suffix = '';
  } else {
    final noun = innerTens == 1 ? 'indre tier' : 'indre tiere';
    suffix = ', $innerTens $noun';
  }
  return '${record.total} av ${record.maxTotal}$suffix';
}

/// The "not synced yet" badge shown on a pending session's card (spec 0026).
class _NotSyncedBadge extends StatelessWidget {
  const _NotSyncedBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: notSyncedBadgeKey,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 14,
            color: scheme.onTertiaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            'Ikke synkronisert',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onTertiaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The read-only detail view for one saved session (spec 0026).
///
/// Rebuilds the session from the stored [SessionRecord.payload]
/// ([SessionSnapshot.fromJson]), re-scores it ([ScoringService.scoreSession])
/// and renders the same [SessionScorecard] the live completion screen uses
/// (spec 0023). If the stored payload cannot be rebuilt — e.g. it names a
/// program that no longer resolves — a graceful message is shown instead of
/// crashing.
class SessionDetailScreen extends StatelessWidget {
  /// Creates the detail view for [record].
  const SessionDetailScreen({required this.record, super.key});

  /// The saved session to render.
  final SessionRecord record;

  static const ScoringService _scoring = ScoringService();

  @override
  Widget build(BuildContext context) {
    final SessionSnapshot snapshot;
    try {
      snapshot = SessionSnapshot.fromJson(record.payload);
    } on Object {
      return Scaffold(
        appBar: AppBar(title: Text(record.program)),
        body: const SafeArea(
          child: _CenteredMessage(
            'Kan ikke vise denne økta',
            key: unreadableSessionKey,
          ),
        ),
      );
    }
    final session = snapshot.session;
    return SessionScorecard(
      program: session.program,
      score: _scoring.scoreSession(session),
      metadata: session.metadata,
      weapon: session.weapon,
    );
  }
}

/// A centred, padded message (the empty / error / unreadable states).
class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
