// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/platform/sharer.dart';
import 'package:treffpunkt/core/presentation/content_scaffold.dart';
import 'package:treffpunkt/core/presentation/snackbar_guard.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/domain/competition.dart';
import 'package:treffpunkt/features/competitions/domain/competition_member.dart';
import 'package:treffpunkt/features/competitions/domain/join_link.dart';
import 'package:treffpunkt/features/competitions/domain/profile.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';

/// Key for the "share invite link" action (spec 0048), used by tests.
const Key shareInviteKey = ValueKey<String>('shareInvite');

/// Key for the "copy invite link" action (spec 0048), used by tests.
const Key copyInviteLinkKey = ValueKey<String>('copyInviteLink');

/// Key for the "regenerate link" action (spec 0048), used by tests.
const Key regenerateLinkKey = ValueKey<String>('regenerateLink');

/// Key for the registered-shooter picker list (spec 0032), used by tests.
const Key shooterPickerKey = ValueKey<String>('shooterPicker');

/// Key for the picker tile of the shooter with the given [userId].
Key shooterTileKey(String userId) => ValueKey<String>('shooterTile-$userId');

/// Key for the Inviter button of the shooter with the given [userId].
Key inviteShooterButtonKey(String userId) =>
    ValueKey<String>('inviteShooter-$userId');

/// The owner's invite page (spec 0093): both invitation mechanisms, moved
/// off the detail page so the scoreboard and participants lead there —
/// *Inviter med lenke* (spec 0048) and *Inviter en registrert skytter*
/// (spec 0032), each behaving exactly as before.
class CompetitionInviteScreen extends ConsumerStatefulWidget {
  /// Creates the invite page for [competition].
  const CompetitionInviteScreen({required this.competition, super.key});

  /// The competition being invited to.
  final Competition competition;

  @override
  ConsumerState<CompetitionInviteScreen> createState() =>
      _CompetitionInviteScreenState();
}

class _CompetitionInviteScreenState
    extends ConsumerState<CompetitionInviteScreen> {
  // The shooter whose invite is in flight, so only that tile shows the pending
  // state — not every Inviter button at once (they share this screen's state).
  String? _invitingShooterId;
  // Shooters invited this visit, merged with the server's pending invitees so
  // their tile shows "Invitert" rather than an active button (spec 0032).
  final Set<String> _invitedShooterIds = <String>{};

  /// The competition's shareable join link, or null if the token can't be read
  /// (only the owner can — and this page is owner-only). Spec 0048.
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
    // Captured by hand as well as by the guard: earlier notices are cleared
    // up front, and the success notice below needs the messenger too.
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    await guardWithSnackBar<CompetitionSyncException>(
      context,
      task: () async {
        await ref
            .read(competitionRepositoryProvider)
            .regenerateJoinToken(widget.competition.id);
        ref.invalidate(competitionJoinTokenProvider(widget.competition.id));
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Ny lenke laget. Gamle lenker slutter å virke.'),
          ),
        );
      },
      failureMessage: 'Kunne ikke lage ny lenke.',
    );
  }

  /// Invites a registered shooter picked from the list (spec 0032). Their email
  /// is resolved server-side; this client only knows the user id.
  Future<void> _inviteUser(Profile shooter) async {
    if (_invitingShooterId != null) return;
    setState(() => _invitingShooterId = shooter.id);
    // Captured by hand as well as by the guard: the success notice below
    // needs the messenger too.
    final messenger = ScaffoldMessenger.of(context);
    final label = shooter.displayName ?? 'skytteren';
    try {
      await guardWithSnackBar<CompetitionSyncException>(
        context,
        task: () async {
          await ref
              .read(competitionRepositoryProvider)
              .inviteUser(widget.competition.id, shooter.id);
          if (mounted) {
            setState(() => _invitedShooterIds.add(shooter.id));
            // Refresh the server-side invitee list so the marker is
            // authoritative and survives a reopen.
            ref.invalidate(competitionInviteesProvider(widget.competition.id));
          }
          messenger.showSnackBar(SnackBar(content: Text('Invitert $label.')));
        },
        failureMessage: 'Kunne ikke invitere.',
      );
    } finally {
      if (mounted) setState(() => _invitingShooterId = null);
    }
  }

  /// The registered shooters, minus the owner, each in one of three states:
  /// not invited (an *Inviter* button), invited (a settled *Invitert*), or a
  /// member who accepted (a settled *Deltar*). Hidden while loading or on
  /// error.
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
        ];
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = ref.watch(
      competitionMembersProvider(widget.competition.id),
    );
    return ContentScaffold(
      title: const Text('Inviter'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
        ],
      ),
    );
  }
}

/// A bold little section title (matches the detail page's headers).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
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
