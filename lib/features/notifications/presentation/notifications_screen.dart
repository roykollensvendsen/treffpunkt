// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/presentation/empty_state.dart';
import 'package:treffpunkt/core/presentation/layout.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_chat_screen.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/competitions/presentation/competitions_screen.dart';
import 'package:treffpunkt/features/forum/presentation/forum_providers.dart';
import 'package:treffpunkt/features/forum/presentation/forum_screen.dart';
import 'package:treffpunkt/features/notifications/data/notifications_repository.dart';
import 'package:treffpunkt/features/notifications/domain/app_notification.dart';

/// Key for the bell action on the front page (spec 0094), for tests.
const Key notificationsBellKey = ValueKey<String>('notificationsBell');

/// Key for the bell's unread badge, for tests.
const Key notificationsBadgeKey = ValueKey<String>('notificationsBadge');

/// Key for the "marker alle som lest" action, for tests.
const Key markAllReadKey = ValueKey<String>('markAllRead');

/// Key for the "fjern alle" action (spec 0109), for tests.
const Key clearNotificationsKey = ValueKey<String>('clearNotifications');

/// Key for the clear-all confirmation's confirm button, for tests.
const Key clearNotificationsConfirmKey = ValueKey<String>(
  'clearNotificationsConfirm',
);

/// Key for the empty state, for tests.
const Key noNotificationsKey = ValueKey<String>('noNotifications');

/// Key for the tile of notification [id], for tests.
Key notificationTileKey(String id) => ValueKey<String>('notification-$id');

/// The account's notifications backend (spec 0094). Defaults to the
/// in-memory fake; `main()` overrides it with the Supabase repository.
final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => InMemoryNotificationsRepository(),
);

/// The account's notifications, newest first (spec 0094).
final notificationsProvider = FutureProvider<List<AppNotification>>(
  (ref) => ref.watch(notificationsRepositoryProvider).list(),
);

/// How many notifications are unread — the bell badge (spec 0094).
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final list =
      ref.watch(notificationsProvider).value ?? const <AppNotification>[];
  return list.where((n) => n.unread).length;
});

/// The Varsler page (spec 0094): the notifications newest first; tapping one
/// marks it read and navigates straight to what it is about.
class NotificationsScreen extends ConsumerStatefulWidget {
  /// Creates the notifications page.
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// Ids swiped away this build cycle (spec 0109): a [Dismissible] must be
  /// out of the tree the frame its dismissal completes, but the provider
  /// keeps its previous value while it reloads — so the removal is applied
  /// locally first and the reload catches up.
  final Set<String> _removed = <String>{};

  /// Marks [notification] read and opens its target (spec 0094 req 4).
  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    final navigator = Navigator.of(context);
    await ref.read(notificationsRepositoryProvider).markRead(notification.id);
    ref.invalidate(notificationsProvider);
    switch (notification.kind) {
      case AppNotificationKind.invitation:
        ref
          ..invalidate(myInvitationsProvider)
          ..invalidate(myCompetitionsProvider);
        await navigator.push(
          MaterialPageRoute<void>(builder: (_) => const CompetitionsScreen()),
        );
      case AppNotificationKind.competitionMessage:
        // The chat screen needs the competition entity; resolve it from my
        // list and fall back to the hub when it is not there (left/deleted).
        final competitions = await ref
            .read(myCompetitionsProvider.future)
            .catchError(
              (Object _) => ref.read(myCompetitionsProvider).value ?? [],
            );
        final competition = competitions
            .where((c) => c.id == notification.competitionId)
            .firstOrNull;
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => competition == null
                ? const CompetitionsScreen()
                : CompetitionChatScreen(competition: competition),
          ),
        );
      case AppNotificationKind.forumReply:
        final threads = ref.read(forumThreadsProvider).value ?? const [];
        final thread = threads
            .where((t) => t.id == notification.threadId)
            .firstOrNull;
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => thread == null
                ? const ForumScreen()
                : ForumThreadScreen(thread: thread),
          ),
        );
    }
  }

  Future<void> _markAllRead(WidgetRef ref) async {
    await ref.read(notificationsRepositoryProvider).markAllRead();
    ref.invalidate(notificationsProvider);
  }

  /// Deletes one swiped-away notification (spec 0109): removed from the
  /// visible list at once, then from the backend.
  Future<void> _delete(WidgetRef ref, String id) async {
    setState(() => _removed.add(id));
    await ref.read(notificationsRepositoryProvider).delete(id);
    ref.invalidate(notificationsProvider);
  }

  /// Clears the whole list after a confirmation (spec 0109) — destructive,
  /// so it asks first (spec 0096).
  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fjern alle varsler?'),
        content: const Text('Handlingen kan ikke angres.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            key: clearNotificationsConfirmKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Fjern alle'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(notificationsRepositoryProvider).deleteAll();
    ref.invalidate(notificationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifications =
        (ref.watch(notificationsProvider).value ?? const <AppNotification>[])
            .where((notification) => !_removed.contains(notification.id))
            .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Varsler'),
        actions: [
          IconButton(
            key: markAllReadKey,
            tooltip: 'Marker alle som lest',
            icon: const Icon(Icons.done_all),
            onPressed: () => unawaited(_markAllRead(ref)),
          ),
          if (notifications.isNotEmpty)
            IconButton(
              key: clearNotificationsKey,
              tooltip: 'Fjern alle',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => unawaited(_clearAll(context, ref)),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: notifications.isEmpty
                ? const EmptyState(
                    icon: Icons.notifications_none,
                    title: 'Ingen varsler ennå.',
                    titleKey: noNotificationsKey,
                    hint: 'Invitasjoner, meldinger og svar dukker opp her.',
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Swipe a notification away to delete it (spec 0109).
                      for (final notification in notifications)
                        Dismissible(
                          key: notificationTileKey(notification.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: theme.colorScheme.errorContainer,
                            child: Icon(
                              Icons.delete_outline,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                          onDismissed: (_) =>
                              unawaited(_delete(ref, notification.id)),
                          child: ListTile(
                            leading: Icon(
                              switch (notification.kind) {
                                AppNotificationKind.invitation =>
                                  Icons.emoji_events_outlined,
                                AppNotificationKind.competitionMessage =>
                                  Icons.chat_bubble_outline,
                                AppNotificationKind.forumReply =>
                                  Icons.forum_outlined,
                              },
                            ),
                            title: Text(
                              notification.title,
                              style: notification.unread
                                  ? const TextStyle(fontWeight: FontWeight.w700)
                                  : null,
                            ),
                            subtitle: notification.body.isEmpty
                                ? null
                                : Text(
                                    notification.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            trailing: notification.unread
                                ? Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                            onTap: () =>
                                unawaited(_open(context, ref, notification)),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
