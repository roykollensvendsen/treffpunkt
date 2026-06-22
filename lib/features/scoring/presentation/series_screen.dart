// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/series_score.dart';
import 'package:treffpunkt/features/scoring/domain/session.dart';
import 'package:treffpunkt/features/scoring/domain/session_metadata.dart';
import 'package:treffpunkt/features/scoring/domain/session_score.dart';
import 'package:treffpunkt/features/scoring/presentation/series_target.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';

/// Key for the "complete series" / advance action in the app bar.
const Key sealSeriesKey = ValueKey<String>('sealSeries');

/// Key for the series total value, used by tests.
const Key seriesTotalKey = ValueKey<String>('seriesTotal');

/// Key for the stage / series progress text, used by tests.
const Key stageProgressKey = ValueKey<String>('stageProgress');

/// Key for the session-complete scorecard heading, used by tests.
const Key sessionCompleteKey = ValueKey<String>('sessionComplete');

/// Key for the captured date / place caption on the scorecard, used by tests.
const Key sessionMetadataKey = ValueKey<String>('sessionMetadata');

/// A one-line "date · place · weapon" caption, or `null` when there is nothing
/// to show.
///
/// The date / place come from [metadata]; the chosen [weapon]'s name is
/// appended when present. A weapon alone (no metadata) still produces a
/// caption.
String? _metadataCaption(SessionMetadata? metadata, Weapon? weapon) {
  final parts = <String>[];
  if (metadata != null) {
    String two(int v) => v.toString().padLeft(2, '0');
    final date = metadata.capturedAt;
    parts.add(
      '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}',
    );
    final place = metadata.place?.label;
    if (place != null && place.isNotEmpty) parts.add(place);
  }
  if (weapon != null) parts.add(weapon.name);
  return parts.isEmpty ? null : parts.join(' · ');
}

/// The guided session screen: shoot a program through its stages and series,
/// watching the running total, then finishing to a session scorecard.
class SeriesScreen extends StatelessWidget {
  /// Creates the screen for [program], optionally tagged with the [metadata]
  /// captured at setup, the [weapon] it is shot with, and app-bar [actions].
  const SeriesScreen({
    required this.program,
    this.metadata,
    this.weapon,
    this.actions,
    super.key,
  });

  /// The program (discipline) being shot.
  final ProgramDefinition program;

  /// When and where this session was shot (spec 0008), or `null`.
  final SessionMetadata? metadata;

  /// The weapon this session is shot with, or `null` when none was chosen.
  final Weapon? weapon;

  /// Extra actions shown in the app bar (e.g. a sign-out button).
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        currentProgramDefinitionProvider.overrideWithValue(program),
        currentSessionMetadataProvider.overrideWithValue(metadata),
        currentWeaponProvider.overrideWithValue(weapon),
        sessionProvider.overrideWith(SessionNotifier.new),
      ],
      child: SessionView(actions: actions),
    );
  }
}

/// The body of the guided session screen. Reads the session from the providers
/// in scope (supplied by [SeriesScreen]).
class SessionView extends ConsumerWidget {
  /// Creates the session view with optional app-bar [actions].
  const SessionView({this.actions, super.key});

  /// Extra actions shown in the app bar (e.g. a sign-out button).
  final List<Widget>? actions;

  static const ScoringService _scoring = ScoringService();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recording = ref.watch(sessionProvider);
    final program = ref.watch(currentProgramDefinitionProvider);

    if (recording.isComplete) {
      return _SessionScorecard(
        program: program,
        score: _scoring.scoreSession(recording.session),
        metadata: recording.session.metadata,
        weapon: recording.session.weapon,
        actions: actions,
      );
    }

    final session = recording.session;
    final current = recording.current!;
    final seriesScore = _scoring.scoreSeries(current);
    final sealedScore = _scoring.scoreSession(session);
    final runningTotal = sealedScore.total + seriesScore.total;
    final runningInnerTens = sealedScore.innerTens + seriesScore.innerTens;
    final multiSeries = program.totalShots > current.capacity;

    return Scaffold(
      appBar: AppBar(
        title: Text(program.name),
        actions: [
          IconButton(
            key: sealSeriesKey,
            icon: const Icon(Icons.check),
            tooltip: 'Complete series',
            onPressed: current.isComplete
                ? () => ref.read(sessionProvider.notifier).advance()
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
              _MetaRow(
                discipline: program.discipline,
                caliberMm: current.geometry.caliberMm,
              ),
              const SizedBox(height: 8),
              _StageHeader(program: program, session: session),
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
                placed: current.placedCount,
                capacity: current.capacity,
                score: seriesScore,
              ),
              const SizedBox(height: 16),
              _SeriesTotalCard(score: seriesScore),
              if (multiSeries) ...[
                const SizedBox(height: 8),
                _SessionProgress(
                  total: runningTotal,
                  maxTotal: sealedScore.maxTotal,
                  innerTens: runningInnerTens,
                ),
              ],
              const SizedBox(height: 12),
              _Legend(hasInnerTen: current.geometry.hasInnerTen),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.discipline, required this.caliberMm});

  final Discipline discipline;
  final double caliberMm;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final label = discipline == Discipline.rifle ? 'Rifle' : 'Pistol';
    return Row(
      children: [
        Text(label, style: style?.copyWith(fontWeight: FontWeight.w600)),
        Text('  ·  $caliberMm mm', style: style),
      ],
    );
  }
}

class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.program, required this.session});

  final ProgramDefinition program;
  final Session session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stage = session.currentStage!;
    final parts = <String>[
      'serie ${session.currentSeriesNumber}/${stage.seriesCount}',
      if (program.stages.length > 1)
        'stadium ${session.currentStageIndex + 1}/${program.stages.length}',
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          stage.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          parts.join(' · '),
          key: stageProgressKey,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
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
  const _SeriesTotalCard({required this.score});

  final SeriesScore score;

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
                'SERIES TOTAL',
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

class _SessionProgress extends StatelessWidget {
  const _SessionProgress({
    required this.total,
    required this.maxTotal,
    required this.innerTens,
  });

  final int total;
  final int maxTotal;
  final int innerTens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suffix = innerTens > 0 ? ' · $innerTens×X' : '';
    return Text(
      'Session so far: $total / $maxTotal$suffix',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
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

class _SessionScorecard extends StatelessWidget {
  const _SessionScorecard({
    required this.program,
    required this.score,
    this.metadata,
    this.weapon,
    this.actions,
  });

  final ProgramDefinition program;
  final SessionScore score;
  final SessionMetadata? metadata;
  final Weapon? weapon;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = _metadataCaption(metadata, weapon);
    return Scaffold(
      appBar: AppBar(title: Text(program.name), actions: [...?actions]),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Session complete',
                key: sessionCompleteKey,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(
                  caption,
                  key: sessionMetadataKey,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              for (var i = 0; i < program.stages.length; i++)
                _StageScoreRow(
                  name: program.stages[i].name,
                  score: score.stages[i],
                ),
              const SizedBox(height: 16),
              _GrandTotalCard(score: score),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageScoreRow extends StatelessWidget {
  const _StageScoreRow({required this.name, required this.score});

  final String name;
  final StageScore score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suffix = score.innerTens > 0 ? '  ·  ${score.innerTens}×X' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: theme.textTheme.titleMedium),
          Text(
            '${score.total} / ${score.maxTotal}$suffix',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GrandTotalCard extends StatelessWidget {
  const _GrandTotalCard({required this.score});

  final SessionScore score;

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
                'SESSION TOTAL',
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
