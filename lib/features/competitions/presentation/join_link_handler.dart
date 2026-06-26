// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/competitions/presentation/competitions_screen.dart';

/// Acts on a shared join link (spec 0048): when the app opens at
/// `?join=<cid>&token=<t>` and the viewer is signed in, it joins them once and
/// opens the competitions hub. Placed inside the signed-in branch of the auth
/// gate, so a signed-out opener signs in first (the link survives the OAuth
/// round-trip) and joins on return. It renders [child] unchanged.
class JoinLinkHandler extends ConsumerStatefulWidget {
  /// Wraps [child] (the signed-in home) with the deep-link join.
  const JoinLinkHandler({required this.child, super.key});

  /// The signed-in home to render.
  final Widget child;

  @override
  ConsumerState<JoinLinkHandler> createState() => _JoinLinkHandlerState();
}

class _JoinLinkHandlerState extends ConsumerState<JoinLinkHandler> {
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeJoin());
  }

  Future<void> _maybeJoin() async {
    if (_handled) return;
    final intent = ref.read(joinIntentProvider);
    if (intent == null) return;
    _handled = true; // Once per app open, even if the join fails.

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(competitionRepositoryProvider)
          .joinByLink(intent.competitionId, intent.token);
      ref.invalidate(myCompetitionsProvider);
      if (!mounted) return;
      // Show the confirmation first: a pushed route's future completes only
      // when it is popped, so a snackbar after `await push` would never appear.
      messenger.showSnackBar(
        const SnackBar(content: Text('Du ble med i konkurransen.')),
      );
      await navigator.push(
        MaterialPageRoute<void>(builder: (_) => const CompetitionsScreen()),
      );
    } on CompetitionSyncException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Ugyldig eller utløpt lenke.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
