// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/presentation/collapsing_fab.dart';
import 'package:treffpunkt/core/presentation/confirm_dialog.dart';
import 'package:treffpunkt/core/presentation/content_scaffold.dart';
import 'package:treffpunkt/core/presentation/empty_state.dart';
import 'package:treffpunkt/core/presentation/error_retry.dart';
import 'package:treffpunkt/core/presentation/frosted_bar.dart';
import 'package:treffpunkt/core/presentation/inner_ten_x.dart';
import 'package:treffpunkt/core/presentation/snackbar_guard.dart';
import 'package:treffpunkt/core/presentation/target_icon.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/domain/competition.dart';
import 'package:treffpunkt/features/competitions/domain/competition_invitation.dart';
import 'package:treffpunkt/features/competitions/domain/competition_result.dart';
import 'package:treffpunkt/features/competitions/domain/scoreboard.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_chat_screen.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_invite_screen.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_result_screen.dart';
import 'package:treffpunkt/features/felt/domain/felt_competition.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/presentation/felt_setup_screen.dart';
import 'package:treffpunkt/features/scoring/domain/month_calendar.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/presentation/session_setup_screen.dart';

/// Key for the "Competitions" app-bar action on the program picker (spec 0011).
const Key competitionsButtonKey = ValueKey<String>('competitionsButton');

/// Key for the "new competition" action on the competitions hub.
const Key newCompetitionButtonKey = ValueKey<String>('newCompetition');

/// Key for the empty state when the shooter has no competitions or invitations.
const Key noCompetitionsKey = ValueKey<String>('noCompetitions');

/// Key for the card of the competition with the given [id] in the list.
Key competitionCard(String id) => ValueKey<String>('competitionCard-$id');

/// Key for the per-card "archive" action on competition [id] (spec 0049).
Key archiveCompetitionKey(String id) =>
    ValueKey<String>('archiveCompetition-$id');

/// Key for the per-card "restore" action on archived competition [id].
Key unarchiveCompetitionKey(String id) =>
    ValueKey<String>('unarchiveCompetition-$id');

/// Key for the collapsible "Arkiverte" tile, shown (collapsed) only when
/// something is archived (spec 0049).
const Key archivedSectionKey = ValueKey<String>('archivedSection');

/// Key for the archive / restore toggle on the competition detail screen.
const Key toggleArchiveButtonKey = ValueKey<String>('toggleArchive');

/// Key for the "accept" action on the invitation to competition [id].
Key acceptInvitationKey(String id) => ValueKey<String>('acceptInvitation-$id');

/// Key for the competition-name field on the create form.
const Key competitionNameFieldKey = ValueKey<String>('competitionNameField');

/// Key for the program dropdown on the create form.
const Key competitionProgramFieldKey = ValueKey<String>(
  'competitionProgramField',
);

/// Key for the public/private switch on the create form.
const Key competitionPublicSwitchKey = ValueKey<String>(
  'competitionPublicSwitch',
);

/// Key for the optional event-date picker on the create form (spec 0057).
const Key competitionDateFieldKey = ValueKey<String>('competitionDate');

/// Key for the clear-date action on the create form.
const Key competitionDateClearKey = ValueKey<String>('competitionDateClear');

/// Key for the submit action on the create form.
const Key createCompetitionSubmitKey = ValueKey<String>(
  'createCompetitionSubmit',
);

/// Key for the calendar toggle in the competitions list app bar (spec 0057).
const Key competitionCalendarToggleKey = ValueKey<String>(
  'competitionCalendarToggle',
);

/// Key for the "clear date filter" action (show all competitions).
const Key competitionCalendarClearKey = ValueKey<String>(
  'competitionCalendarClear',
);

/// Key for the previous / next month actions in the competitions calendar.
const Key competitionCalendarPrevKey = ValueKey<String>(
  'competitionCalendarPrev',
);

/// Key for the next-month action in the competitions calendar.
const Key competitionCalendarNextKey = ValueKey<String>(
  'competitionCalendarNext',
);

/// Key for the calendar day cell for [date] in the competitions calendar.
Key competitionCalendarDayKey(DateTime date) => ValueKey<String>(
  'competitionCalDay-${date.year}-${date.month}-${date.day}',
);

/// Formats [date] as Norwegian `DD.MM.YYYY`.
String _formatNorDate(DateTime date) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year}';
}

/// Key for the app-bar overflow menu on the detail page (spec 0093).
const Key competitionMenuKey = ValueKey<String>('competitionMenu');

/// Key for the owner's Inviter action on the detail page (spec 0093).
const Key inviteCompetitionKey = ValueKey<String>('inviteCompetition');

/// Key for the "shoot for this competition" action on the detail screen.
const Key shootForCompetitionKey = ValueKey<String>('shootForCompetition');

/// Key for the owner's "delete competition" action on the detail screen.
const Key deleteCompetitionButtonKey = ValueKey<String>('deleteCompetition');

/// Key for the confirm action in the delete-competition dialog (spec 0034).
const Key deleteCompetitionConfirmKey = ValueKey<String>(
  'deleteCompetitionConfirm',
);

/// Key for the empty-results state on the detail scoreboard.
const Key noResultsKey = ValueKey<String>('noResults');

/// Key for the scoreboard row of the result with the given [id].
Key resultRowKey(String id) => ValueKey<String>('resultRow-$id');

/// The competitions hub (spec 0011): the shooter's pending invitations (each
/// acceptable), the competitions they own or have joined, and a way to create a
/// new one. Reads are foreground, so a failure shows a retry rather than a
/// silent empty list.
class CompetitionsScreen extends ConsumerStatefulWidget {
  /// Creates the competitions hub.
  const CompetitionsScreen({super.key});

  @override
  ConsumerState<CompetitionsScreen> createState() => _CompetitionsScreenState();
}

class _CompetitionsScreenState extends ConsumerState<CompetitionsScreen> {
  // Calendar filter (spec 0057): the selected day (null = show all), the month
  // the calendar shows, and whether the calendar is open.
  DateTime? _filterDay;
  DateTime? _calendarMonth;
  bool _calendarOpen = false;

  /// Whether the FAB is collapsed to its round state (spec 0138): true
  /// while the list is scrolled away from the top.
  bool _fabCollapsed = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final collapsed = notification.metrics.pixels > 64;
    if (collapsed != _fabCollapsed) setState(() => _fabCollapsed = collapsed);
    return false;
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CreateCompetitionScreen()),
    );
    ref.invalidate(myCompetitionsProvider);
  }

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    String competitionId,
  ) async {
    await guardWithSnackBar(
      context,
      task: () async {
        await ref
            .read(competitionRepositoryProvider)
            .acceptInvitation(
              competitionId,
            );
        ref
          ..invalidate(myInvitationsProvider)
          ..invalidate(myCompetitionsProvider);
      },
      failureMessage: 'Kunne ikke godta invitasjonen.',
    );
  }

  void _open(BuildContext context, Competition competition) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CompetitionDetailScreen(competition: competition),
        ),
      ),
    );
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    Competition competition,
  ) async {
    // Captured by hand as well as by the guard: the success notice below
    // needs the messenger too.
    final messenger = ScaffoldMessenger.of(context);
    await guardWithSnackBar(
      context,
      task: () async {
        await ref
            .read(competitionRepositoryProvider)
            .archiveCompetition(competition.id);
        ref.invalidate(archivedCompetitionIdsProvider);
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('«${competition.name}» arkivert'),
              // Since Flutter 3.44 a snack bar with an action stays until
              // acted on; this is a transient confirmation, so let it time
              // out.
              persist: false,
              action: SnackBarAction(
                label: 'Angre',
                onPressed: () => unawaited(_restore(ref, competition.id)),
              ),
            ),
          );
      },
      failureMessage: 'Kunne ikke arkivere konkurransen.',
    );
  }

  Future<void> _restore(WidgetRef ref, String competitionId) async {
    try {
      await ref
          .read(competitionRepositoryProvider)
          .unarchiveCompetition(competitionId);
      ref.invalidate(archivedCompetitionIdsProvider);
    } on Object {
      // Best-effort restore (e.g. an Angre tap); on failure the list is
      // unchanged.
    }
  }

  void _selectDay(DateTime day) {
    setState(() {
      // Tapping the selected day again clears the filter (show all).
      _filterDay = (_filterDay == day) ? null : day;
    });
  }

  @override
  Widget build(BuildContext context) {
    final invitations = ref.watch(myInvitationsProvider);
    final competitions = ref.watch(myCompetitionsProvider);
    final archivedIds =
        ref.watch(archivedCompetitionIdsProvider).value ?? const <String>{};

    final comps = competitions.value ?? const <Competition>[];
    final daysWithComps = <DateTime>{
      for (final c in comps)
        if (c.eventDate != null) dateKey(c.eventDate!),
    };
    final month = _calendarMonth ?? firstOfMonth(_filterDay ?? DateTime.now());

    // The behindBar variant slides the content under the frosted bars
    // (spec 0129).
    return ContentScaffold.behindBar(
      title: const Text('Konkurranser'),
      actions: <Widget>[
        IconButton(
          key: competitionCalendarToggleKey,
          tooltip: 'Kalender',
          isSelected: _calendarOpen || _filterDay != null,
          icon: const Icon(Icons.calendar_month_outlined),
          selectedIcon: const Icon(Icons.calendar_month),
          onPressed: () => setState(() => _calendarOpen = !_calendarOpen),
        ),
      ],
      // Lifted clear of the shell's frosted navigation bar (spec 0131):
      // with extendBody the tab fills the whole screen, so the FAB must
      // rise by the bar's inset itself.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom,
        ),
        child: CollapsingFab(
          buttonKey: newCompetitionButtonKey,
          collapsed: _fabCollapsed,
          icon: Icons.edit_outlined,
          label: 'Ny konkurranse',
          onPressed: () => unawaited(_create(context, ref)),
        ),
      ),
      // The Builder gives the list a context INSIDE the scaffold's body,
      // where the app-bar/nav-bar insets are injected (spec 0129).
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Builder(
          builder: (context) => ListView(
            padding: frostedScrollPadding(context),
            children: [
              if (_calendarOpen) ...[
                _CompetitionCalendar(
                  month: month,
                  selectedDay: _filterDay,
                  daysWithCompetitions: daysWithComps,
                  onSelectDay: _selectDay,
                  onPrevMonth: () => setState(
                    () => _calendarMonth = DateTime(
                      month.year,
                      month.month - 1,
                    ),
                  ),
                  onNextMonth: () => setState(
                    () => _calendarMonth = DateTime(
                      month.year,
                      month.month + 1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (_filterDay case final day?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: <Widget>[
                      Chip(
                        avatar: const Icon(Icons.event, size: 18),
                        label: Text('Viser ${_formatNorDate(day)}'),
                        onDeleted: () => setState(() => _filterDay = null),
                        deleteButtonTooltipMessage: 'Vis alle',
                      ),
                      const Spacer(),
                      TextButton(
                        key: competitionCalendarClearKey,
                        onPressed: () => setState(() => _filterDay = null),
                        child: const Text('Vis alle'),
                      ),
                    ],
                  ),
                ),
              ..._invitationsSection(context, ref, invitations),
              ..._competitionsSection(
                context,
                ref,
                invitations,
                competitions,
                archivedIds,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _invitationsSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<CompetitionInvitation>> invitations,
  ) {
    final list = invitations.value ?? const <CompetitionInvitation>[];
    if (list.isEmpty) return const <Widget>[];
    return <Widget>[
      const _SectionHeader('Invitasjoner'),
      for (final invitation in list)
        _InvitationCard(
          invitation: invitation,
          onAccept: () => unawaited(
            _accept(context, ref, invitation.competitionId),
          ),
        ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _competitionsSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<CompetitionInvitation>> invitations,
    AsyncValue<List<Competition>> competitions,
    Set<String> archivedIds,
  ) {
    return competitions.when(
      loading: () => const <Widget>[
        Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (error, _) => <Widget>[
        ErrorRetry(
          onRetry: () => ref.invalidate(myCompetitionsProvider),
        ),
      ],
      data: (list) {
        final invitationList =
            invitations.value ?? const <CompetitionInvitation>[];
        // Partition into the active list and the archived ones (spec 0049).
        // When a calendar day is selected, the active list is filtered to that
        // day's competitions (spec 0057).
        final active = <Competition>[
          for (final c in list)
            if (!archivedIds.contains(c.id) &&
                (_filterDay == null ||
                    (c.eventDate != null &&
                        dateKey(c.eventDate!) == _filterDay)))
              c,
        ];
        final archived = <Competition>[
          for (final c in list)
            if (archivedIds.contains(c.id)) c,
        ];
        if (list.isEmpty && invitationList.isEmpty) {
          return const <Widget>[
            Padding(
              padding: EdgeInsets.only(top: 32),
              child: EmptyState(
                icon: Icons.emoji_events_outlined,
                title: 'Ingen konkurranser ennå',
                titleKey: noCompetitionsKey,
                hint: 'Lag en konkurranse, eller godta en invitasjon.',
              ),
            ),
          ];
        }
        return <Widget>[
          const _SectionHeader('Mine konkurranser'),
          for (final competition in active)
            Card(
              child: ListTile(
                key: competitionCard(competition.id),
                title: Text(competition.name),
                subtitle: Text(_subtitle(competition)),
                trailing: IconButton(
                  key: archiveCompetitionKey(competition.id),
                  icon: const Icon(Icons.archive_outlined),
                  tooltip: 'Arkiver',
                  onPressed: () =>
                      unawaited(_archive(context, ref, competition)),
                ),
                onTap: () => _open(context, competition),
              ),
            ),
          if (active.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _filterDay == null
                    ? 'Ingen aktive konkurranser.'
                    : 'Ingen konkurranser på denne datoen.',
              ),
            ),
          if (archived.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Tucked away and collapsed by default, so they stay out of the way
            // until you ask for them (spec 0049).
            Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                key: archivedSectionKey,
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text('Arkiverte (${archived.length})'),
                shape: const Border(),
                collapsedShape: const Border(),
                children: <Widget>[
                  for (final competition in archived)
                    ListTile(
                      key: competitionCard(competition.id),
                      title: Text(competition.name),
                      subtitle: Text(_subtitle(competition)),
                      trailing: IconButton(
                        key: unarchiveCompetitionKey(competition.id),
                        icon: const Icon(Icons.unarchive_outlined),
                        tooltip: 'Gjenopprett',
                        onPressed: () =>
                            unawaited(_restore(ref, competition.id)),
                      ),
                      onTap: () => _open(context, competition),
                    ),
                ],
              ),
            ),
          ],
        ];
      },
    );
  }
}

String _subtitle(Competition competition) {
  final visibility = competition.isPublic ? 'Åpen' : 'Privat';
  return '${competition.program} · $visibility';
}

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

const List<String> _weekdayLabels = <String>[
  'Ma',
  'Ti',
  'On',
  'To',
  'Fr',
  'Lø',
  'Sø',
];

/// A month calendar to filter the competitions list by event date (spec 0057):
/// days with a competition get a dot; tapping a day selects it (tapping again
/// clears). Mirrors the "Mine økter" calendar, reusing the pure date helpers.
class _CompetitionCalendar extends StatelessWidget {
  const _CompetitionCalendar({
    required this.month,
    required this.selectedDay,
    required this.daysWithCompetitions,
    required this.onSelectDay,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  final DateTime month;
  final DateTime? selectedDay;
  final Set<DateTime> daysWithCompetitions;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grid = monthGrid(month);
    final name = _monthNames[month.month - 1];
    final label = '${name[0].toUpperCase()}${name.substring(1)} ${month.year}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  key: competitionCalendarPrevKey,
                  onPressed: onPrevMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(label, style: theme.textTheme.titleMedium),
                  ),
                ),
                IconButton(
                  key: competitionCalendarNextKey,
                  onPressed: onNextMonth,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Row(
              children: <Widget>[
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
                children: <Widget>[
                  for (var d = 0; d < 7; d++)
                    _dayCell(context, grid[week * 7 + d]),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(BuildContext context, DateTime date) {
    final theme = Theme.of(context);
    final inMonth = date.month == month.month;
    final isSelected = date == selectedDay;
    final hasComps = daysWithCompetitions.contains(date);
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
            key: competitionCalendarDayKey(date),
            onTap: () => onSelectDay(date),
            borderRadius: BorderRadius.circular(8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '${date.day}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: fg,
                      fontWeight: isSelected ? FontWeight.bold : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (hasComps)
                    Container(
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

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({required this.invitation, required this.onAccept});

  final CompetitionInvitation invitation;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final competition = invitation.competition;
    final title = competition?.name ?? 'Konkurranse';
    final subtitle = competition == null ? null : _subtitle(competition);
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.mail_outline),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: FilledButton(
          key: acceptInvitationKey(invitation.competitionId),
          onPressed: onAccept,
          child: const Text('Godta'),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// The create-competition form (spec 0011): a name, the program it fixes, and
/// whether it is public. Submitting mints a client id and creates it.
class CreateCompetitionScreen extends ConsumerStatefulWidget {
  /// Creates the form.
  const CreateCompetitionScreen({super.key});

  @override
  ConsumerState<CreateCompetitionScreen> createState() =>
      _CreateCompetitionScreenState();
}

class _CreateCompetitionScreenState
    extends ConsumerState<CreateCompetitionScreen> {
  final TextEditingController _name = TextEditingController();
  String _program = ProgramCatalogue.all.first.name;
  bool _isPublic = false;
  bool _saving = false;
  DateTime? _eventDate;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _eventDate = picked);
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final competition = Competition(
      id: ref.read(competitionIdGeneratorProvider)(),
      name: name,
      program: _program,
      ownerId: ref.read(currentUserIdProvider) ?? '',
      isPublic: _isPublic,
      eventDate: _eventDate,
    );
    final created = await guardWithSnackBar<CompetitionSyncException>(
      context,
      task: () async {
        await ref
            .read(competitionRepositoryProvider)
            .createCompetition(
              competition,
            );
        navigator.pop();
      },
      failureMessage: 'Kunne ikke opprette konkurransen.',
    );
    if (!created && mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return ContentScaffold(
      title: const Text('Ny konkurranse'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: competitionNameFieldKey,
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Navn',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: competitionProgramFieldKey,
            initialValue: _program,
            decoration: const InputDecoration(
              labelText: 'Program',
              border: OutlineInputBorder(),
            ),
            items: <DropdownMenuItem<String>>[
              for (final program in ProgramCatalogue.all)
                DropdownMenuItem<String>(
                  value: program.name,
                  child: Text(program.name),
                ),
              // NorgesFelt, locked to a course and group (specs 0140/0145):
              // course + group ARE the program, so the competition is fair.
              for (final course in feltCourses)
                for (final group in FeltShooterGroup.offered)
                  DropdownMenuItem<String>(
                    value: feltCompetitionProgram(course, group),
                    child: Text(feltCompetitionProgram(course, group)),
                  ),
            ],
            onChanged: (value) => setState(() => _program = value ?? _program),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: competitionPublicSwitchKey,
            value: _isPublic,
            onChanged: (value) => setState(() => _isPublic = value),
            title: const Text('Åpen konkurranse'),
            subtitle: const Text(
              'Alle innloggede kan se den. Av = kun inviterte.',
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            key: competitionDateFieldKey,
            leading: const Icon(Icons.event_outlined),
            title: Text(
              _eventDate == null
                  ? 'Velg dato (valgfritt)'
                  : 'Dato: ${_formatNorDate(_eventDate!)}',
            ),
            trailing: _eventDate == null
                ? null
                : IconButton(
                    key: competitionDateClearKey,
                    icon: const Icon(Icons.clear),
                    tooltip: 'Fjern dato',
                    onPressed: () => setState(() => _eventDate = null),
                  ),
            onTap: () => unawaited(_pickDate()),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: createCompetitionSubmitKey,
            onPressed: _saving ? null : () => unawaited(_submit()),
            icon: const Icon(Icons.check),
            label: const Text('Opprett'),
          ),
        ],
      ),
    );
  }
}

/// A competition's detail (spec 0011): its program, its participants, and — for
/// the owner — an invite-by-email control.
class CompetitionDetailScreen extends ConsumerStatefulWidget {
  /// Creates the detail view for [competition].
  const CompetitionDetailScreen({required this.competition, super.key});

  /// The competition being shown.
  final Competition competition;

  @override
  ConsumerState<CompetitionDetailScreen> createState() =>
      _CompetitionDetailScreenState();
}

class _CompetitionDetailScreenState
    extends ConsumerState<CompetitionDetailScreen> {
  /// Confirms, then deletes the competition (owner only, spec 0034); on success
  /// returns to the hub with the list refreshed. The cascade removes its
  /// members, invitations and results. A failure keeps the screen, with a
  /// notice.
  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Slett konkurranse?',
      message:
          'Alle deltakere, invitasjoner og resultater slettes. '
          'Handlingen kan ikke angres.',
      confirmLabel: 'Slett',
      confirmKey: deleteCompetitionConfirmKey,
    );
    if (!confirmed || !mounted) return;
    await guardWithSnackBar<CompetitionSyncException>(
      context,
      task: () async {
        await ref
            .read(competitionRepositoryProvider)
            .deleteCompetition(widget.competition.id);
        ref.invalidate(myCompetitionsProvider);
        navigator.pop();
      },
      failureMessage: 'Kunne ikke slette konkurransen.',
    );
  }

  /// Archives or restores this competition for the viewer (spec 0049) — open to
  /// everyone, owner or not, since archiving is personal view state. On success
  /// it pops back to the list, which re-partitions on the refreshed archives.
  Future<void> _toggleArchive({required bool archived}) async {
    final navigator = Navigator.of(context);
    final repository = ref.read(competitionRepositoryProvider);
    await guardWithSnackBar<CompetitionSyncException>(
      context,
      task: () async {
        if (archived) {
          await repository.unarchiveCompetition(widget.competition.id);
        } else {
          await repository.archiveCompetition(widget.competition.id);
        }
        ref.invalidate(archivedCompetitionIdsProvider);
        navigator.pop();
      },
      failureMessage: archived
          ? 'Kunne ikke gjenopprette konkurransen.'
          : 'Kunne ikke arkivere konkurransen.',
    );
  }

  /// Starts the competition's fixed program; the result auto-submits on
  /// completion (spec 0012). On return, the scoreboard is refreshed.
  Future<void> _shoot() async {
    // A felt competition (specs 0140/0145) opens the felt setup, locked to
    // the competition's course and group; ring competitions open the ring
    // setup.
    final felt = feltCompetitionCourseAndGroup(widget.competition.program);
    if (felt != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FeltSetupScreen(
            course: felt.course,
            competitionId: widget.competition.id,
            forcedGroup: felt.group,
          ),
        ),
      );
      ref.invalidate(competitionScoreboardProvider(widget.competition.id));
      return;
    }
    final program = ProgramCatalogue.byName(widget.competition.program);
    if (program == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionSetupScreen(
          program: program,
          competitionId: widget.competition.id,
        ),
      ),
    );
    ref.invalidate(competitionScoreboardProvider(widget.competition.id));
  }

  @override
  Widget build(BuildContext context) {
    final competition = widget.competition;
    final members = ref.watch(competitionMembersProvider(competition.id));
    final results = ref.watch(competitionScoreboardProvider(competition.id));
    final uid = ref.watch(currentUserIdProvider);
    final isOwner = uid == competition.ownerId;
    final isArchived =
        ref
            .watch(archivedCompetitionIdsProvider)
            .value
            ?.contains(
              competition.id,
            ) ??
        false;
    // Only a participant may shoot for the competition (the insert policy gates
    // it too); today the detail is reached only as a participant.
    final isParticipant =
        isOwner || (members.value?.any((m) => m.userId == uid) ?? false);
    // A program is shootable when the ring catalogue knows it OR it is a
    // felt competition (spec 0140) — _shoot() routes accordingly.
    final knownProgram =
        ProgramCatalogue.byName(competition.program) != null ||
        feltCompetitionGroup(competition.program) != null;
    final theme = Theme.of(context);

    return ContentScaffold(
      title: Text(competition.name),
      actions: [
        // Rare and destructive actions live in the overflow menu (spec
        // 0093): archive/restore for everyone, delete for the owner.
        PopupMenuButton<_DetailMenuAction>(
          key: competitionMenuKey,
          tooltip: 'Flere valg',
          onSelected: (action) => switch (action) {
            _DetailMenuAction.archive => unawaited(
              _toggleArchive(archived: isArchived),
            ),
            _DetailMenuAction.delete => unawaited(_delete()),
          },
          itemBuilder: (_) => <PopupMenuEntry<_DetailMenuAction>>[
            PopupMenuItem<_DetailMenuAction>(
              key: toggleArchiveButtonKey,
              value: _DetailMenuAction.archive,
              child: Text(
                isArchived ? 'Gjenopprett konkurranse' : 'Arkiver konkurranse',
              ),
            ),
            if (isOwner)
              const PopupMenuItem<_DetailMenuAction>(
                key: deleteCompetitionButtonKey,
                value: _DetailMenuAction.delete,
                child: Text('Slett konkurranse'),
              ),
          ],
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_subtitle(competition), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          // One compact action row (spec 0093): shoot, chat and — for
          // the owner — the invite page; the results lead below it.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (isParticipant)
                FilledButton.icon(
                  key: shootForCompetitionKey,
                  onPressed: knownProgram ? () => unawaited(_shoot()) : null,
                  icon: const TargetIcon(size: 20),
                  label: const Text('Skyt nå'),
                ),
              // The competition's chat — the shared back-channel for
              // the people in it (spec 0051).
              OutlinedButton.icon(
                key: competitionChatButtonKey,
                onPressed: () => unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CompetitionChatScreen(
                        competition: competition,
                      ),
                    ),
                  ),
                ),
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Chat'),
              ),
              if (isOwner)
                OutlinedButton.icon(
                  key: inviteCompetitionKey,
                  onPressed: () => unawaited(
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CompetitionInviteScreen(
                          competition: competition,
                        ),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Inviter'),
                ),
            ],
          ),
          if (isParticipant && !knownProgram)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Ukjent program',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 16),
          const _SectionHeader('Resultater'),
          ...results.when(
            loading: () => const <Widget>[
              Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, _) => <Widget>[
              ErrorRetry(
                onRetry: () => ref.invalidate(
                  competitionScoreboardProvider(competition.id),
                ),
              ),
            ],
            data: (raw) {
              // One row per shooter (their best), ranked best first.
              final list = rankBestPerShooter(raw);
              return list.isEmpty
                  ? const <Widget>[
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Ingen resultater ennå.',
                          key: noResultsKey,
                        ),
                      ),
                    ]
                  : <Widget>[
                      for (var i = 0; i < list.length; i++)
                        _ResultRow(rank: i + 1, result: list[i]),
                    ];
            },
          ),
          const SizedBox(height: 16),
          const _SectionHeader('Deltakere'),
          ...members.when(
            loading: () => const <Widget>[
              Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, _) => <Widget>[
              ErrorRetry(
                onRetry: () => ref.invalidate(
                  competitionMembersProvider(competition.id),
                ),
              ),
            ],
            data: (list) => <Widget>[
              for (final member in list)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(
                    member.profile?.displayName ?? 'Ukjent skytter',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the detail page's overflow menu can do (spec 0093). Archiving is
/// personal view state, so it is open to everyone — including a non-owner
/// who cannot delete (spec 0049).
enum _DetailMenuAction { archive, delete }

/// One scoreboard row: rank, the submitter's name, and the score (spec 0012).
class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.rank, required this.result});

  final int rank;
  final CompetitionResult result;

  @override
  Widget build(BuildContext context) {
    // The podium reads like a stevne result list (spec 0100): gold, silver
    // and bronze tints on the top three ranks.
    final podium = switch (rank) {
      1 => const Color(0xFFE6C15A),
      2 => const Color(0xFFC0C4CC),
      3 => const Color(0xFFC98F5E),
      _ => null,
    };
    return ListTile(
      key: resultRowKey(result.id),
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: podium,
        foregroundColor: podium == null ? null : const Color(0xFF2B2B2B),
        child: Text('$rank'),
      ),
      title: Text(result.profile?.displayName ?? 'Ukjent skytter'),
      trailing: innerTenScoreText(
        context: context,
        lead: '${result.total}',
        innerTens: result.innerTens,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      // Tap a shooter to see their full scorecard — every stage and series —
      // rebuilt from the result payload (spec 0037).
      onTap: () => unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CompetitionResultScreen(result: result),
          ),
        ),
      ),
    );
  }
}
