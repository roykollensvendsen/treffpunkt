// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/platform/sharer.dart';
import 'package:treffpunkt/core/presentation/inner_ten_x.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/domain/competition.dart';
import 'package:treffpunkt/features/competitions/domain/competition_invitation.dart';
import 'package:treffpunkt/features/competitions/domain/competition_member.dart';
import 'package:treffpunkt/features/competitions/domain/competition_result.dart';
import 'package:treffpunkt/features/competitions/domain/join_link.dart';
import 'package:treffpunkt/features/competitions/domain/profile.dart';
import 'package:treffpunkt/features/competitions/domain/scoreboard.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_result_screen.dart';
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

/// Key for the submit action on the create form.
const Key createCompetitionSubmitKey = ValueKey<String>(
  'createCompetitionSubmit',
);

/// Key for the "share join link" action on the detail screen (spec 0048).
const Key shareInviteKey = ValueKey<String>('shareInvite');

/// Key for the "copy join link" action on the detail screen.
const Key copyInviteLinkKey = ValueKey<String>('copyInviteLink');

/// Key for the "regenerate join link" action on the detail screen.
const Key regenerateLinkKey = ValueKey<String>('regenerateLink');

/// Key for the registered-shooter picker on the detail screen (spec 0032).
const Key shooterPickerKey = ValueKey<String>('shooterPicker');

/// Key for the tile of the registered shooter [userId] in the picker.
Key shooterTileKey(String userId) => ValueKey<String>('shooterTile-$userId');

/// Key for the "invite" action on the registered shooter [userId].
Key inviteShooterButtonKey(String userId) =>
    ValueKey<String>('inviteShooter-$userId');

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

const double _maxContentWidth = 700;

/// The competitions hub (spec 0011): the shooter's pending invitations (each
/// acceptable), the competitions they own or have joined, and a way to create a
/// new one. Reads are foreground, so a failure shows a retry rather than a
/// silent empty list.
class CompetitionsScreen extends ConsumerWidget {
  /// Creates the competitions hub.
  const CompetitionsScreen({super.key});

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
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(competitionRepositoryProvider)
          .acceptInvitation(
            competitionId,
          );
      ref
        ..invalidate(myInvitationsProvider)
        ..invalidate(myCompetitionsProvider);
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke godta invitasjonen.')),
      );
    }
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(competitionRepositoryProvider)
          .archiveCompetition(competition.id);
      ref.invalidate(archivedCompetitionIdsProvider);
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('«${competition.name}» arkivert'),
            action: SnackBarAction(
              label: 'Angre',
              onPressed: () => unawaited(_restore(ref, competition.id)),
            ),
          ),
        );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke arkivere konkurransen.')),
      );
    }
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitations = ref.watch(myInvitationsProvider);
    final competitions = ref.watch(myCompetitionsProvider);
    final archivedIds =
        ref.watch(archivedCompetitionIdsProvider).value ?? const <String>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Konkurranser')),
      floatingActionButton: FloatingActionButton.extended(
        key: newCompetitionButtonKey,
        onPressed: () => unawaited(_create(context, ref)),
        icon: const Icon(Icons.add),
        label: const Text('Ny konkurranse'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
        _ErrorRetry(
          onRetry: () => ref.invalidate(myCompetitionsProvider),
        ),
      ],
      data: (list) {
        final invitationList =
            invitations.value ?? const <CompetitionInvitation>[];
        // Partition into the active list and the archived ones (spec 0049).
        final active = <Competition>[
          for (final c in list)
            if (!archivedIds.contains(c.id)) c,
        ];
        final archived = <Competition>[
          for (final c in list)
            if (archivedIds.contains(c.id)) c,
        ];
        if (list.isEmpty && invitationList.isEmpty) {
          return const <Widget>[_EmptyState()];
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Ingen aktive konkurranser.'),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Ingen konkurranser ennå',
            key: noCompetitionsKey,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lag en konkurranse, eller godta en invitasjon.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          const Text('Kunne ikke hente konkurransene.'),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('Prøv igjen')),
        ],
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

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final competition = Competition(
      id: ref.read(competitionIdGeneratorProvider)(),
      name: name,
      program: _program,
      ownerId: ref.read(currentUserIdProvider) ?? '',
      isPublic: _isPublic,
    );
    try {
      await ref
          .read(competitionRepositoryProvider)
          .createCompetition(
            competition,
          );
      navigator.pop();
    } on CompetitionSyncException {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke opprette konkurransen.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ny konkurranse')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: ListView(
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
                  ],
                  onChanged: (value) =>
                      setState(() => _program = value ?? _program),
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
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: createCompetitionSubmitKey,
                  onPressed: _saving ? null : () => unawaited(_submit()),
                  icon: const Icon(Icons.check),
                  label: const Text('Opprett'),
                ),
              ],
            ),
          ),
        ),
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
  // The shooter whose invite is in flight, so only that tile shows the pending
  // state — not every Inviter button at once (they share this screen's state).
  String? _invitingShooterId;
  // Shooters invited this visit, merged with the server's pending invitees so
  // their tile shows "Invitert" rather than an active button (spec 0032).
  final Set<String> _invitedShooterIds = <String>{};

  /// The competition's shareable join link, or null if the token can't be read
  /// (only the owner can — and this section is owner-only). Spec 0048.
  Future<Uri?> _joinLink() async {
    final token = await ref.read(
      competitionJoinTokenProvider(widget.competition.id).future,
    );
    if (token == null) return null;
    return competitionJoinLink(
      ref.read(appBaseUrlProvider),
      competitionId: widget.competition.id,
      token: token,
    );
  }

  /// Shares the join link through the OS share sheet (Messenger / SMS / … ).
  Future<void> _share() async {
    final link = await _joinLink();
    if (link == null || !mounted) return;
    await ref
        .read(sharerProvider)
        .share('Bli med i ${widget.competition.name} på Treffpunkt: $link');
  }

  /// Copies the join link — the reliable fallback where sharing is unavailable.
  Future<void> _copyLink() async {
    final link = await _joinLink();
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Lenke kopiert.')));
  }

  /// Issues a fresh token, so old links stop working.
  Future<void> _regenerateLink() async {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    try {
      await ref
          .read(competitionRepositoryProvider)
          .regenerateJoinToken(widget.competition.id);
      ref.invalidate(competitionJoinTokenProvider(widget.competition.id));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Ny lenke laget. Gamle lenker slutter å virke.'),
        ),
      );
    } on CompetitionSyncException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke lage ny lenke.')),
      );
    }
  }

  /// Invites a registered shooter picked from the list (spec 0032). Their email
  /// is resolved server-side; this client only knows the user id.
  Future<void> _inviteUser(Profile shooter) async {
    if (_invitingShooterId != null) return;
    setState(() => _invitingShooterId = shooter.id);
    final messenger = ScaffoldMessenger.of(context);
    final label = shooter.displayName ?? 'skytteren';
    try {
      await ref
          .read(competitionRepositoryProvider)
          .inviteUser(widget.competition.id, shooter.id);
      if (mounted) {
        setState(() => _invitedShooterIds.add(shooter.id));
        // Refresh the server-side invitee list so the marker is authoritative
        // and survives a reopen.
        ref.invalidate(competitionInviteesProvider(widget.competition.id));
      }
      messenger.showSnackBar(SnackBar(content: Text('Invitert $label.')));
    } on CompetitionSyncException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke invitere.')),
      );
    } finally {
      if (mounted) setState(() => _invitingShooterId = null);
    }
  }

  /// Confirms, then deletes the competition (owner only, spec 0034); on success
  /// returns to the hub with the list refreshed. The cascade removes its
  /// members, invitations and results. A failure keeps the screen, with a
  /// notice.
  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Slett konkurranse?'),
        content: const Text(
          'Alle deltakere, invitasjoner og resultater slettes. '
          'Handlingen kan ikke angres.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            key: deleteCompetitionConfirmKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Slett'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(competitionRepositoryProvider)
          .deleteCompetition(widget.competition.id);
      ref.invalidate(myCompetitionsProvider);
      navigator.pop();
    } on CompetitionSyncException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke slette konkurransen.')),
      );
    }
  }

  /// Archives or restores this competition for the viewer (spec 0049) — open to
  /// everyone, owner or not, since archiving is personal view state. On success
  /// it pops back to the list, which re-partitions on the refreshed archives.
  Future<void> _toggleArchive({required bool archived}) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final repository = ref.read(competitionRepositoryProvider);
    try {
      if (archived) {
        await repository.unarchiveCompetition(widget.competition.id);
      } else {
        await repository.archiveCompetition(widget.competition.id);
      }
      ref.invalidate(archivedCompetitionIdsProvider);
      navigator.pop();
    } on CompetitionSyncException {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            archived
                ? 'Kunne ikke gjenopprette konkurransen.'
                : 'Kunne ikke arkivere konkurransen.',
          ),
        ),
      );
    }
  }

  /// Starts the competition's fixed program; the result auto-submits on
  /// completion (spec 0012). On return, the scoreboard is refreshed.
  Future<void> _shoot() async {
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

  /// The registered shooters the owner can invite (spec 0032): everyone with a
  /// The registered shooters, minus the owner, each in one of three states:
  /// not invited (an *Inviter* button), invited (a settled *Invitert*), or a
  /// member who accepted (a settled *Deltar*). Hidden while loading or on error
  /// — the email field stays as the fallback.
  List<Widget> _shooterPicker(List<CompetitionMember>? members) {
    final shooters = ref.watch(shootersProvider);
    final uid = ref.watch(currentUserIdProvider);
    // Shooters with a pending invitation from an earlier visit (owner-only,
    // server-resolved) — merged with this visit's invites so the marker
    // persists across reopen.
    final invitees =
        ref.watch(competitionInviteesProvider(widget.competition.id)).value ??
        const <String>[];
    final memberIds = <String>{...?members?.map((m) => m.userId)};
    return shooters.maybeWhen(
      orElse: () => const <Widget>[],
      data: (all) {
        // Only the owner is dropped; members stay, shown as "Deltar".
        final listed = all.where((p) => p.id != uid).toList(growable: false);
        if (listed.isEmpty) return const <Widget>[];
        return <Widget>[
          const _SectionHeader('Inviter en registrert skytter'),
          Column(
            key: shooterPickerKey,
            children: <Widget>[
              for (final shooter in listed)
                _ShooterTile(
                  shooter: shooter,
                  inviting: _invitingShooterId == shooter.id,
                  invited:
                      _invitedShooterIds.contains(shooter.id) ||
                      invitees.contains(shooter.id),
                  joined: memberIds.contains(shooter.id),
                  onInvite: () => unawaited(_inviteUser(shooter)),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ];
      },
    );
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
    final program = ProgramCatalogue.byName(competition.program);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(competition.name)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(_subtitle(competition), style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                if (isParticipant) ...[
                  FilledButton.icon(
                    key: shootForCompetitionKey,
                    onPressed: program == null
                        ? null
                        : () => unawaited(_shoot()),
                    icon: const Icon(Icons.gps_fixed),
                    label: const Text('Skyt nå'),
                  ),
                  if (program == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Ukjent program',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
                if (isOwner) ...[
                  const _SectionHeader('Inviter med lenke'),
                  Text(
                    'Del en lenke; den som åpner den blir med.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.icon(
                        key: shareInviteKey,
                        onPressed: () => unawaited(_share()),
                        icon: const Icon(Icons.share),
                        label: const Text('Del lenke'),
                      ),
                      OutlinedButton.icon(
                        key: copyInviteLinkKey,
                        onPressed: () => unawaited(_copyLink()),
                        icon: const Icon(Icons.link),
                        label: const Text('Kopier lenke'),
                      ),
                      TextButton.icon(
                        key: regenerateLinkKey,
                        onPressed: () => unawaited(_regenerateLink()),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Lag ny lenke'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._shooterPicker(members.value),
                  OutlinedButton.icon(
                    key: deleteCompetitionButtonKey,
                    onPressed: () => unawaited(_delete()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Slett konkurranse'),
                  ),
                  const SizedBox(height: 16),
                ],
                const _SectionHeader('Resultater'),
                ...results.when(
                  loading: () => const <Widget>[
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (error, _) => <Widget>[
                    _ErrorRetry(
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
                    _ErrorRetry(
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
                const SizedBox(height: 24),
                // Archiving is personal view state, so it is open to everyone —
                // including a non-owner who cannot delete (spec 0049).
                OutlinedButton.icon(
                  key: toggleArchiveButtonKey,
                  onPressed: () =>
                      unawaited(_toggleArchive(archived: isArchived)),
                  icon: Icon(
                    isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  label: Text(
                    isArchived
                        ? 'Gjenopprett konkurranse'
                        : 'Arkiver konkurranse',
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

/// One scoreboard row: rank, the submitter's name, and the score (spec 0012).
class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.rank, required this.result});

  final int rank;
  final CompetitionResult result;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: resultRowKey(result.id),
      leading: CircleAvatar(radius: 14, child: Text('$rank')),
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

/// One row in the registered-shooter picker: name + avatar and an Inviter
/// button. Shows only the name/avatar — never the shooter's email (spec 0032).
class _ShooterTile extends StatelessWidget {
  const _ShooterTile({
    required this.shooter,
    required this.inviting,
    required this.invited,
    required this.joined,
    required this.onInvite,
  });

  final Profile shooter;
  final bool inviting;

  /// Whether this shooter has a pending invitation — the tile then shows a
  /// settled "Invitert" state instead of an active button.
  final bool invited;

  /// Whether this shooter accepted and is now a member — a settled "Deltar"
  /// state that takes precedence over [invited].
  final bool joined;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = shooter.avatarUrl;
    return ListTile(
      key: shooterTileKey(shooter.id),
      leading: CircleAvatar(
        backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
        child: avatarUrl == null ? const Icon(Icons.person_outline) : null,
      ),
      title: Text(shooter.displayName ?? 'Ukjent skytter'),
      // Three settled states: a member who accepted reads "Deltar"; a pending
      // invitee reads "Invitert"; both are disabled so no no-op invite fires.
      // Otherwise an active "Inviter" button.
      trailing: _trailing(),
    );
  }

  Widget _trailing() {
    if (joined) {
      return TextButton.icon(
        key: inviteShooterButtonKey(shooter.id),
        onPressed: null,
        icon: const Icon(Icons.how_to_reg),
        label: const Text('Deltar'),
      );
    }
    if (invited) {
      return TextButton.icon(
        key: inviteShooterButtonKey(shooter.id),
        onPressed: null,
        icon: const Icon(Icons.check),
        label: const Text('Invitert'),
      );
    }
    return FilledButton.tonal(
      key: inviteShooterButtonKey(shooter.id),
      onPressed: inviting ? null : onInvite,
      child: const Text('Inviter'),
    );
  }
}
