// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/config/support_links.dart';
import 'package:treffpunkt/core/presentation/app_theme.dart';
import 'package:treffpunkt/core/presentation/build_version_label.dart';
import 'package:treffpunkt/core/presentation/category_pictograms.dart';
import 'package:treffpunkt/core/presentation/confirm_dialog.dart';
import 'package:treffpunkt/core/presentation/content_scaffold.dart';
import 'package:treffpunkt/core/presentation/frosted_bar.dart';
import 'package:treffpunkt/core/presentation/link_providers.dart';
import 'package:treffpunkt/core/presentation/target_icon.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';
import 'package:treffpunkt/features/felt/presentation/felt_record_screen.dart';
import 'package:treffpunkt/features/felt/presentation/felt_setup_screen.dart';
import 'package:treffpunkt/features/notifications/presentation/notifications_screen.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/program_category.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/program_category_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/series_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/session_setup_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/upload_queue.dart';

/// Key for the "resume saved session" card, used by tests.
const Key resumeSessionKey = ValueKey<String>('resumeSession');

/// Key for the "discard saved session" action on the resume card (for tests).
const Key discardSessionKey = ValueKey<String>('discardSession');

/// Key for the "My sessions" app-bar action, used by tests (spec 0026).
const Key mySessionsButtonKey = ValueKey<String>('mySessionsButton');

/// Key for the confirm action in destructive dialogs (spec 0096), for tests.
const Key confirmDestructiveKey = ValueKey<String>('confirmDestructive');

/// Key for the front page's "Fortsett felt-økt" card (spec 0097), for tests.
const Key feltResumeSessionKey = ValueKey<String>('feltResumeSession');

/// Key for the felt resume card's discard button (spec 0116), for tests.
const Key feltDiscardSessionKey = ValueKey<String>('feltDiscardSession');

/// Key for the «Spander en kaffe» Vipps card (spec 0146), for tests.
const Key coffeeCardKey = ValueKey<String>('coffeeCard');

/// Key for the «Skyt igjen» quick-start card (spec 0097), for tests.
const Key shootAgainKey = ValueKey<String>('shootAgain');

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
    _refreshHome(ref);
  }

  /// Refreshes everything the front page derives from stored state (spec
  /// 0108): the resume cards AND the «Skyt igjen» history — a flow may have
  /// completed a session or saved a felt round, and the cached background
  /// reads would otherwise show it only after a tab switch or full reload.
  void _refreshHome(WidgetRef ref) {
    ref
      ..invalidate(savedRecordingProvider)
      ..invalidate(feltSavedSessionProvider)
      ..invalidate(storedPendingProvider)
      ..invalidate(syncedSessionsProvider)
      ..invalidate(feltHistoryProvider)
      ..invalidate(feltSyncedSessionsProvider);
  }

  /// Opens [category]'s page, then refreshes the resume cards on return.
  ///
  /// The flow below may save a new in-progress recording (the shooter places a
  /// shot and leaves), so re-read the stores to surface it as a resume card.
  /// With two felt courses (spec 0145) the Felt category opens its course
  /// list like every other category.
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
    _refreshHome(ref);
  }

  /// Resumes the saved felt round straight from the front page (spec 0097).
  Future<void> _resumeFelt(
    BuildContext context,
    WidgetRef ref,
    FeltSessionSnapshot saved,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FeltRecordScreen(restored: saved),
      ),
    );
    _refreshHome(ref);
  }

  /// The most recent completed exercise, for the «Skyt igjen» card (spec
  /// 0097): the newest dated ring session (resolvable by name) or felt round
  /// across the same merged history Mine økter shows. Null with no history.
  _LastExercise? _lastExercise(WidgetRef ref) {
    DateTime? bestAt;
    _LastExercise? best;
    final ring = <SessionRecord>[
      // The live queue first (spec 0108): a session that completed seconds
      // ago is here before any store or server read — the card follows the
      // moment it lands, with no refresh.
      ...ref.watch(uploadQueueProvider),
      ...?ref.watch(storedPendingProvider).value,
      ...?ref.watch(syncedSessionsProvider).value,
    ];
    for (final record in ring) {
      final at = record.capturedAt;
      if (at == null || ProgramCatalogue.byName(record.program) == null) {
        continue;
      }
      if (bestAt == null || at.isAfter(bestAt)) {
        bestAt = at;
        best = _LastExercise(label: record.program, isFelt: false);
      }
    }
    final felt = <FeltSessionRecord>[
      ...?ref.watch(feltHistoryProvider).value,
      ...?ref.watch(feltSyncedSessionsProvider).value,
    ];
    for (final round in felt) {
      if (bestAt == null || round.capturedAt.isAfter(bestAt)) {
        bestAt = round.capturedAt;
        final course = feltCourseById(round.session.courseId);
        best = _LastExercise(
          label: '${course.name} (${round.session.group.label})',
          isFelt: true,
          feltCourse: course,
          feltGroup: round.session.group,
        );
      }
    }
    return best;
  }

  /// Opens [last]'s setup step in one tap (spec 0097 req 2).
  Future<void> _shootAgain(
    BuildContext context,
    WidgetRef ref,
    _LastExercise last,
  ) async {
    if (last.isFelt) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FeltSetupScreen(
            course: last.feltCourse,
            group: last.feltGroup ?? FeltShooterGroup.one,
          ),
        ),
      );
    } else {
      final program = ProgramCatalogue.byName(last.label);
      if (program == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SessionSetupScreen(program: program),
        ),
      );
    }
    _refreshHome(ref);
  }

  /// Discards the saved session (spec 0009 req 4) after a confirmation
  /// (spec 0096 — the trash sits beside the resume tap target) and refreshes
  /// the card away.
  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    if (!await showConfirmDialog(
      context,
      title: 'Forkast lagret økt?',
      message: 'Handlingen kan ikke angres.',
      confirmLabel: 'Slett',
      confirmKey: confirmDestructiveKey,
    )) {
      return;
    }
    await ref.read(sessionStoreProvider).clear();
    ref.invalidate(savedRecordingProvider);
  }

  /// Opens the developer's Vipps link (spec 0146); an unavailable handler
  /// degrades to a hint, never a crash.
  Future<void> _openCoffee(BuildContext context, WidgetRef ref) async {
    // Captured before the await so no BuildContext is used across the gap.
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(linkOpenerProvider).open(vippsCoffeeUri);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke åpne Vipps-lenken.')),
      );
    }
  }

  /// Discards the saved felt round (spec 0116) after the same confirmation.
  Future<void> _discardFelt(BuildContext context, WidgetRef ref) async {
    if (!await showConfirmDialog(
      context,
      title: 'Forkast lagret økt?',
      message: 'Handlingen kan ikke angres.',
      confirmLabel: 'Slett',
      confirmKey: confirmDestructiveKey,
    )) {
      return;
    }
    await ref.read(feltSessionStoreProvider).clear();
    ref.invalidate(feltSavedSessionProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedRecordingProvider).value;
    final feltSaved = ref.watch(feltSavedSessionProvider).value;
    final last = _lastExercise(ref);
    return ContentScaffold.behindBar(
      // The logo mark (spec 0101): the target beside the wordmark, its
      // bull in the signal red of a hit (spec 0100).
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TargetIcon(
            size: 22,
            color: Theme.of(context).colorScheme.primary,
            bullColor: TreffColors.of(context).lastShot,
          ),
          const SizedBox(width: 8),
          const Text('Treffpunkt'),
        ],
      ),
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
        ...?actions,
      ],
      // The Builder gives a context INSIDE the body, where the Scaffold
      // injects the app-bar/nav-bar insets (spec 0129).
      // One full-height scrollable (spec 0129): the list itself extends
      // behind the frosted nav bar, so the last items — the coffee card and
      // the version footer — shine through the glass while scrolling and
      // rest clear of it at the end (frostedScrollPadding pads past it).
      body: Builder(
        builder: (context) => ListView(
          padding: frostedScrollPadding(context),
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
                    onPressed: () => unawaited(_discard(context, ref)),
                  ),
                  onTap: () => unawaited(_resume(context, ref, saved)),
                ),
              ),
            if (feltSaved != null)
              Card(
                color: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                child: ListTile(
                  key: feltResumeSessionKey,
                  leading: const Icon(Icons.play_circle_outline),
                  title: const Text('Fortsett felt-økt'),
                  subtitle: Text(
                    '${feltCourseById(feltSaved.courseId).name} · '
                    '${feltSaved.totalShots} skudd plassert',
                  ),
                  trailing: IconButton(
                    key: feltDiscardSessionKey,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Forkast lagret økt',
                    onPressed: () => unawaited(_discardFelt(context, ref)),
                  ),
                  onTap: () => unawaited(
                    _resumeFelt(context, ref, feltSaved),
                  ),
                ),
              ),
            if (last != null)
              Card(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer,
                child: Semantics(
                  button: true,
                  label: 'Skyt igjen: ${last.label}',
                  onTap: () => unawaited(_shootAgain(context, ref, last)),
                  child: ExcludeSemantics(
                    child: ListTile(
                      key: shootAgainKey,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      leading: const TargetIcon(size: 30),
                      title: const Text(
                        'Skyt igjen',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(last.label),
                      onTap: () => unawaited(
                        _shootAgain(context, ref, last),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 4,
              crossAxisSpacing: 8,
              childAspectRatio: 2,
              children: [
                for (final category in ProgramCategory.values)
                  _CategoryTile(
                    category: category,
                    // MIL has nothing yet (spec 0097 req 4).
                    onTap: category == ProgramCategory.mil
                        ? null
                        : () => unawaited(
                            _openCategory(context, ref, category),
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // «Spander en kaffe» (spec 0146): last, below the
            // shooting flows — a thank-you, never a nag.
            Card(
              child: ListTile(
                key: coffeeCardKey,
                leading: const Icon(Icons.coffee_outlined),
                title: const Text('Spander en kaffe'),
                subtitle: const Text(
                  'Liker du Treffpunkt? '
                  'Vipps en kaffe til utviklerne.',
                ),
                onTap: () => unawaited(_openCoffee(context, ref)),
              ),
            ),
            const SizedBox(height: 12),
            // A discreet build-version footer below the program list so a
            // user can confirm which build they are running (spec 0028).
            const BuildVersionLabel(),
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

/// The grid tile's subtitle (spec 0097): only MIL carries one («Kommer
/// senere» — a state, not a description); the shooters know their
/// disciplines, so the tiles stay clean. The full description stays in the
/// tile's semantics label.
String? _categoryTileSubtitle(ProgramCategory category) =>
    category == ProgramCategory.mil ? 'Kommer senere' : null;

String _categorySubtitle(ProgramCategory category) {
  final count = ProgramCatalogue.inCategory(category).length;
  if (category == ProgramCategory.mil) {
    // Disabled until the military programs are seeded (spec 0097 req 5).
    return '${category.description} · kommer senere';
  }
  if (count == 0) return category.description;
  final programs = count == 1 ? '1 program' : '$count programmer';
  return '${category.description} · $programs';
}

/// The «Skyt igjen» card's target (spec 0097).
class _LastExercise {
  const _LastExercise({
    required this.label,
    required this.isFelt,
    this.feltCourse,
    this.feltGroup,
  });

  /// The exercise name shown on the card.
  final String label;

  /// Whether the target is a felt course (opens the felt setup).
  final bool isFelt;

  /// The felt course to reopen (spec 0145), when [isFelt].
  final FeltCourse? feltCourse;

  /// The last round's group — the program variant to reopen (spec 0147).
  final FeltShooterGroup? feltGroup;
}

/// The category's pictogram (spec 0101): what its programs are shot at —
/// fine rings for air, the heavy 25 m bull for fin/grov, the silhouette for
/// MIL and felt's square-and-circle figure pair.
Widget _categoryPictogram(ProgramCategory category) => switch (category) {
  ProgramCategory.nsfLuft => const TargetIcon(),
  ProgramCategory.nsfFinGrov => const TargetIcon(bullFraction: 0.45),
  ProgramCategory.mil => const SilhouettePictogram(),
  ProgramCategory.felt => const FeltFiguresPictogram(),
};

/// One compact category tile in the 2×2 grid (spec 0097): the label on top,
/// the description under, disabled (muted) when [onTap] is null (MIL).
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final ProgramCategory category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final disabled = onTap == null;
    final subtitle = _categoryTileSubtitle(category);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        button: !disabled,
        label:
            'Velg kategori: ${category.label}, '
            '${_categorySubtitle(category)}',
        onTap: onTap,
        child: ExcludeSemantics(
          child: InkWell(
            key: ValueKey<String>('category-${category.label}'),
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // The category's pictogram (spec 0101).
                  IconTheme(
                    data: IconThemeData(
                      size: 26,
                      color: disabled ? muted.withValues(alpha: 0.6) : muted,
                    ),
                    child: _categoryPictogram(category),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: disabled
                                ? muted.withValues(alpha: 0.6)
                                : null,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
