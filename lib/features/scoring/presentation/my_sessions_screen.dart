// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/presentation/inner_ten_x.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';
import 'package:treffpunkt/features/felt/presentation/felt_session_detail_screen.dart';
import 'package:treffpunkt/features/scoring/domain/month_calendar.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/domain/session_snapshot.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/series_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/statistics_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/upload_queue.dart';

/// Key for the card of the saved session with the given [id], used by tests.
Key mySessionCard(String id) => ValueKey<String>('mySessionCard-$id');

/// Key for a saved felt round's card in "Mine økter" (spec 0082), for tests.
Key feltSessionCard(String id) => ValueKey<String>('feltSessionCard-$id');

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

/// Key for the list/calendar toggle in the app bar (spec 0038).
const Key calendarToggleKey = ValueKey<String>('calendarToggle');

/// Key for the previous-month chevron on the calendar (spec 0038).
const Key calendarPrevMonthKey = ValueKey<String>('calendarPrevMonth');

/// Key for the next-month chevron on the calendar (spec 0038).
const Key calendarNextMonthKey = ValueKey<String>('calendarNextMonth');

/// Key for the month/year label on the calendar (spec 0038).
const Key calendarMonthLabelKey = ValueKey<String>('calendarMonthLabel');

/// Key for the "no sessions on this day" hint under the calendar (spec 0038).
const Key noSessionsOnDayKey = ValueKey<String>('noSessionsOnDay');

/// Key for the calendar cell of [date] (date-only), used by tests (spec 0038).
Key calendarDayKey(DateTime date) =>
    ValueKey<String>('calendarDay-${date.year}-${date.month}-${date.day}');

/// Key for the "has sessions" dot on the calendar cell of [date] (spec 0038).
Key calendarDayDotKey(DateTime date) =>
    ValueKey<String>('calendarDayDot-${date.year}-${date.month}-${date.day}');

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
class MySessionsScreen extends ConsumerStatefulWidget {
  /// Creates the "My sessions" screen.
  const MySessionsScreen({super.key});

  @override
  ConsumerState<MySessionsScreen> createState() => _MySessionsScreenState();
}

class _MySessionsScreenState extends ConsumerState<MySessionsScreen> {
  /// Whether the calendar view is shown instead of the flat list (spec 0038).
  bool _calendar = false;

  /// The visible month (first-of-month) and selected day; `null` until the user
  /// navigates, so the calendar opens on the newest session's month/day.
  DateTime? _month;
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
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
    // Finished felt rounds: the local history (spec 0082) merged with the
    // account's synced rounds (spec 0083) by id, then interleaved with the ring
    // sessions newest-first.
    final feltLocal =
        ref.watch(feltHistoryProvider).value ?? const <FeltSessionRecord>[];
    final feltSynced =
        ref.watch(feltSyncedSessionsProvider).value ??
        const <FeltSessionRecord>[];
    final feltRounds = mergeFeltRounds(local: feltLocal, synced: feltSynced);
    final items = mergeSessionItems(
      entries: entries,
      rounds: feltRounds,
      syncedFeltIds: <String>{for (final round in feltSynced) round.id},
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mine økter'),
        actions: [
          IconButton(
            key: statisticsButtonKey,
            tooltip: 'Statistikk',
            icon: const Icon(Icons.show_chart),
            onPressed: () => unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const StatisticsScreen(),
                ),
              ),
            ),
          ),
          IconButton(
            key: calendarToggleKey,
            tooltip: _calendar ? 'Vis liste' : 'Vis kalender',
            icon: Icon(
              _calendar
                  ? Icons.view_list_outlined
                  : Icons.calendar_month_outlined,
            ),
            onPressed: () => setState(() => _calendar = !_calendar),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Column(
              children: [
                if (syncFailed) const _SyncErrorBanner(),
                Expanded(
                  child: _calendar
                      ? _calendarView(items)
                      : _SessionsList(items: items),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The calendar: a month grid with the days that have sessions marked, and
  /// the selected day's sessions below it (spec 0038). Sessions with no stored
  /// date are not placed on the calendar (they stay in the list view).
  Widget _calendarView(List<MySessionItem> items) {
    final byDay = <DateTime, List<MySessionItem>>{};
    for (final item in items) {
      final at = item.capturedAt;
      if (at == null) continue;
      byDay.putIfAbsent(dateKey(at), () => <MySessionItem>[]).add(item);
    }
    // Items are sorted newest-first, so the first dated one anchors the
    // default month/day; with no dated sessions, fall back to today.
    final dated = items.where((e) => e.capturedAt != null);
    final anchor = dated.isEmpty
        ? dateKey(DateTime.now())
        : dateKey(dated.first.capturedAt!);
    final selectedDay = _selectedDay ?? anchor;
    final month = _month ?? firstOfMonth(selectedDay);
    final dayEntries = byDay[selectedDay] ?? const <MySessionItem>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SessionCalendar(
            month: month,
            selectedDay: selectedDay,
            daysWithSessions: byDay.keys.toSet(),
            onSelectDay: (day) => setState(() => _selectedDay = day),
            onPrevMonth: () =>
                setState(() => _month = DateTime(month.year, month.month - 1)),
            onNextMonth: () =>
                setState(() => _month = DateTime(month.year, month.month + 1)),
          ),
          const SizedBox(height: 8),
          if (dayEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Ingen økter denne dagen',
                key: noSessionsOnDayKey,
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final item in dayEntries) _itemRow(item),
        ],
      ),
    );
  }
}

/// Unions the [sources] of pending records, deduplicated by id; a later source
/// wins a tie, so passing `[stored, live]` keeps the freshest copy.
List<SessionRecord> _unionById(List<List<SessionRecord>> sources) {
  final byId = <String, SessionRecord>{};
  for (final source in sources) {
    for (final record in source) {
      byId[record.id] = record;
    }
  }
  return byId.values.toList();
}

/// The loaded list of saved sessions, or the empty state when there are none.
class _SessionsList extends StatelessWidget {
  const _SessionsList({required this.items});

  final List<MySessionItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) => _itemRow(items[index]),
    );
  }
}

/// Builds the row for a unified list [item] (spec 0082): a ring session card or
/// a finished felt round card.
Widget _itemRow(MySessionItem item) => switch (item) {
  RingSessionItem(:final entry) => _SessionCard(entry: entry),
  FeltSessionItem(:final record, :final synced) => _FeltSessionCard(
    record: record,
    synced: synced,
  ),
};

/// A finished felt round in "Mine økter" (spec 0082): its date, group and total
/// points; tapping opens the felt scorecard, and a trailing menu can delete the
/// round (spec 0089) exactly like a ring session's card (spec 0033).
class _FeltSessionCard extends ConsumerWidget {
  const _FeltSessionCard({required this.record, required this.synced});

  final FeltSessionRecord record;

  /// Whether the round is on the account, so deleting must clear it there too.
  final bool synced;

  /// The "date · group[ · place]" caption (spec 0092: the place rides along).
  String get _metaLine {
    final place = record.session.placeLabel;
    return [
      _feltDate(record.capturedAt),
      record.tally.group.label,
      if (place != null && place.isNotEmpty) place,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tally = record.tally;
    final weapon = record.session.weaponName;
    return Card(
      child: Row(
        children: [
          // The card body is one "open" button to a screen reader; the menu
          // beside it is a separate control (outside ExcludeSemantics).
          Expanded(
            child: Semantics(
              button: true,
              label:
                  'NorgesFelt-løype 2026. $_metaLine. '
                  '${tally.points} poeng, ${tally.inner} innertreff'
                  '${weapon == null ? '' : '. $weapon'}',
              onTap: () => unawaited(_open(context)),
              child: ExcludeSemantics(
                child: ListTile(
                  key: feltSessionCard(record.id),
                  leading: const Icon(Icons.my_location),
                  title: const Text('NorgesFelt-løype 2026'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _metaLine,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      // Points, then the inner-hit tiebreak count as the same
                      // ringed X the ring sessions use (specs 0085/0023).
                      innerTenScoreText(
                        context: context,
                        lead: '${tally.points} poeng',
                        innerTens: tally.inner,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // The weapon, like the ring cards (spec 0092).
                      if (weapon != null)
                        Text(
                          weapon,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
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
      builder: (_) => FeltSessionDetailScreen(record: record),
    ),
  );

  /// Confirms, then deletes the round from the account (when synced) and the
  /// device, refreshing the list (spec 0089) — the ring card's flow (spec
  /// 0033). A failed account delete leaves the card and shows a message.
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
    try {
      if (synced) {
        await ref.read(feltSessionRepositoryProvider).deleteById(record.id);
      }
      await deleteFeltRound(ref, record.id);
      ref.invalidate(feltSyncedSessionsProvider);
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke slette økta.')),
      );
    }
  }
}

/// Formats a felt round's date like the ring meta line.
String _feltDate(DateTime at) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${at.year}-${two(at.month)}-${two(at.day)} '
      '${two(at.hour)}:${two(at.minute)}';
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
                      innerTenScoreText(
                        context: context,
                        lead: '${record.total}',
                        innerTens: record.innerTens,
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

/// Norwegian weekday headers (Monday-first) and month names for the calendar.
const List<String> _weekdayLabels = <String>[
  'Man',
  'Tir',
  'Ons',
  'Tor',
  'Fre',
  'Lør',
  'Søn',
];
const List<String> _monthNames = <String>[
  'januar',
  'februar',
  'mars',
  'april',
  'mai',
  'juni',
  'juli',
  'august',
  'september',
  'oktober',
  'november',
  'desember',
];

/// A month calendar for "Mine økter" (spec 0038): a Monday-first 6-week grid
/// with a dot on days that have sessions and the selected day highlighted.
class _SessionCalendar extends StatelessWidget {
  const _SessionCalendar({
    required this.month,
    required this.selectedDay,
    required this.daysWithSessions,
    required this.onSelectDay,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  final DateTime month;
  final DateTime selectedDay;
  final Set<DateTime> daysWithSessions;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grid = monthGrid(month);
    final name = _monthNames[month.month - 1];
    final label = '${name[0].toUpperCase()}${name.substring(1)} ${month.year}';
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              key: calendarPrevMonthKey,
              onPressed: onPrevMonth,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Center(
                child: Text(
                  label,
                  key: calendarMonthLabelKey,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              key: calendarNextMonthKey,
              onPressed: onNextMonth,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          children: [
            for (final w in _weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var week = 0; week < 6; week++)
          Row(
            children: [
              for (var d = 0; d < 7; d++) _dayCell(context, grid[week * 7 + d]),
            ],
          ),
      ],
    );
  }

  Widget _dayCell(BuildContext context, DateTime date) {
    final theme = Theme.of(context);
    final inMonth = date.month == month.month;
    final isSelected = date == selectedDay;
    final hasSessions = daysWithSessions.contains(date);
    final fg = isSelected
        ? theme.colorScheme.onPrimary
        : inMonth
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: InkWell(
            key: calendarDayKey(date),
            onTap: () => onSelectDay(date),
            borderRadius: BorderRadius.circular(8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: fg,
                      fontWeight: isSelected ? FontWeight.bold : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (hasSessions)
                    Container(
                      key: calendarDayDotKey(date),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.primary,
                      ),
                    )
                  else
                    const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
      seriesByStage: session.sealedSeriesByStage,
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
