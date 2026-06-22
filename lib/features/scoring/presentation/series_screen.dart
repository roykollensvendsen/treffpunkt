// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/domain/program.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/series_score.dart';
import 'package:treffpunkt/features/scoring/presentation/series_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/series_target.dart';

/// Key for the "complete series" action in the app bar.
const Key sealSeriesKey = ValueKey<String>('sealSeries');

/// Key for the series total value, used by tests.
const Key seriesTotalKey = ValueKey<String>('seriesTotal');

/// The series scoring screen: shoot a series on the target, watch each shot's
/// score and the running total, then seal the series once it is complete.
///
/// The discipline is supplied as a [program]; the screen is otherwise
/// discipline-agnostic.
class SeriesScreen extends StatelessWidget {
  /// Creates the screen for [program] with optional app-bar [actions].
  const SeriesScreen({required this.program, this.actions, super.key});

  /// The program (discipline) being shot.
  final Program program;

  /// Extra actions shown in the app bar (e.g. a sign-out button).
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      // Re-host seriesProvider in this scope so it reads the program override
      // here rather than from an enclosing scope.
      overrides: [
        currentProgramProvider.overrideWithValue(program),
        seriesProvider.overrideWith(SeriesNotifier.new),
      ],
      child: SeriesView(actions: actions),
    );
  }
}

/// The body of the series scoring screen: app bar, target, shots list and the
/// series total. It reads the current program and series from the providers in
/// scope (supplied by [SeriesScreen]).
class SeriesView extends ConsumerWidget {
  /// Creates the series view with optional app-bar [actions].
  const SeriesView({this.actions, super.key});

  /// Extra actions shown in the app bar (e.g. a sign-out button).
  final List<Widget>? actions;

  static const ScoringService _scoring = ScoringService();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recording = ref.watch(seriesProvider);
    final program = ref.watch(currentProgramProvider);
    final series = recording.series;
    final score = _scoring.scoreSeries(series);
    final canSeal = series.isComplete && !recording.sealed;

    return Scaffold(
      appBar: AppBar(
        title: Text(program.name),
        actions: [
          IconButton(
            key: sealSeriesKey,
            icon: const Icon(Icons.check),
            tooltip: 'Complete series',
            onPressed: canSeal
                ? () => ref.read(seriesProvider.notifier).seal()
                : null,
          ),
          ...?actions,
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MetaRow(program: program),
              const SizedBox(height: 12),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: const AspectRatio(
                    aspectRatio: 1,
                    child: SeriesTarget(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ShotsList(
                placed: series.placedCount,
                capacity: series.capacity,
                score: score,
              ),
              const SizedBox(height: 16),
              _SeriesTotalCard(score: score, sealed: recording.sealed),
              const SizedBox(height: 12),
              _Legend(hasInnerTen: program.geometry.hasInnerTen),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.program});

  final Program program;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final caliber = program.geometry.caliberMm;
    return Row(
      children: [
        Text(
          program.name,
          style: style?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text('  ·  $caliber mm', style: style),
      ],
    );
  }
}

class _ShotsList extends StatelessWidget {
  const _ShotsList({
    required this.placed,
    required this.capacity,
    required this.score,
  });

  final int placed;
  final int capacity;
  final SeriesScore score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final half = (capacity / 2).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Shots',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$placed / $capacity',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _column(1, half)),
            const SizedBox(width: 16),
            Expanded(child: _column(half + 1, capacity)),
          ],
        ),
      ],
    );
  }

  Widget _column(int from, int to) {
    return Column(
      children: [
        for (var i = from; i <= to; i++)
          _ShotRow(index: i, score: i <= placed ? score.shots[i - 1] : null),
      ],
    );
  }
}

class _ShotRow extends StatelessWidget {
  const _ShotRow({required this.index, required this.score});

  final int index;
  final ShotScore? score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shotScore = score;
    final pending = shotScore == null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: pending
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.primaryContainer,
            child: Text(
              '$index',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: pending
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            pending ? '–' : '${shotScore.ring}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: pending ? theme.colorScheme.onSurfaceVariant : null,
            ),
          ),
          if (shotScore?.isInnerTen ?? false) ...[
            const SizedBox(width: 6),
            const _InnerTenDot(),
          ],
        ],
      ),
    );
  }
}

class _SeriesTotalCard extends StatelessWidget {
  const _SeriesTotalCard({required this.score, required this.sealed});

  final SeriesScore score;
  final bool sealed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onColor = scheme.onPrimary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sealed ? 'SERIES TOTAL · COMPLETE' : 'SERIES TOTAL',
                style: TextStyle(
                  color: onColor,
                  fontSize: 12,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                score.innerTens > 0 ? 'Sum · ${score.innerTens}×X' : 'Sum',
                style: TextStyle(color: onColor, fontSize: 18),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${score.total}',
                key: seriesTotalKey,
                style: TextStyle(
                  color: onColor,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' / ${score.maxTotal}',
                style: TextStyle(
                  color: onColor.withValues(alpha: 0.8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.hasInnerTen});

  final bool hasInnerTen;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Row(
      children: [
        if (hasInnerTen) ...[
          const _InnerTenDot(),
          const SizedBox(width: 6),
          Text('inner ten (X)', style: style),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: Text('one target face · tap to place each shot', style: style),
        ),
      ],
    );
  }
}

class _InnerTenDot extends StatelessWidget {
  const _InnerTenDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: const BoxDecoration(
        color: Colors.amber,
        shape: BoxShape.circle,
      ),
    );
  }
}
