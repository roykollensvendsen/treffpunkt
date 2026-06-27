// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/presentation/inner_ten_x.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/scoring_service.dart';
import 'package:treffpunkt/features/scoring/domain/series.dart';
import 'package:treffpunkt/features/scoring/domain/series_score.dart';
import 'package:treffpunkt/features/scoring/domain/session.dart';
import 'package:treffpunkt/features/scoring/domain/session_metadata.dart';
import 'package:treffpunkt/features/scoring/domain/session_score.dart';
import 'package:treffpunkt/features/scoring/domain/shot.dart';
import 'package:treffpunkt/features/scoring/presentation/scan_target_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/series_target.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';

/// Key for the "complete series" / advance action in the app bar.
const Key sealSeriesKey = ValueKey<String>('sealSeries');

/// Key for the "Skann skive" (camera scan) action in the app bar (spec 0039).
const Key scanTargetActionKey = ValueKey<String>('scanTargetAction');

/// Key for the series total value, used by tests.
const Key seriesTotalKey = ValueKey<String>('seriesTotal');

/// Key for the stage / series progress text, used by tests.
const Key stageProgressKey = ValueKey<String>('stageProgress');

/// Key for the session-complete scorecard heading, used by tests.
const Key sessionCompleteKey = ValueKey<String>('sessionComplete');

/// Key for the captured date / place caption on the scorecard, used by tests.
const Key sessionMetadataKey = ValueKey<String>('sessionMetadata');

/// Type key shared by every per-series (skive) result row on the scorecard,
/// used by tests to count the rows (spec 0023).
const Key seriesResultRowKey = ValueKey<String>('seriesResultRow');

/// Key for the per-series result row of series [seriesIndex] (0-based) under
/// stage [stageIndex] (0-based) on the scorecard, used by tests (spec 0023).
Key seriesResultRow(int stageIndex, int seriesIndex) =>
    ValueKey<String>('seriesResultRow-$stageIndex-$seriesIndex');

/// Key for the shots-list row of the most recently placed shot, used by tests.
///
/// At most one row carries this key; it moves to the new last row as each
/// further shot is placed, matching the highlight on the target (spec 0020).
const Key lastShotRowKey = ValueKey<String>('lastShotRow');

/// Width (logical px) above which the shooting screen lays the target and the
/// shot/score column out side by side instead of stacked.
const double _sideBySideBreakpoint = 900;

/// Comfortable maximum content width (logical px) so nothing stretches
/// edge-to-edge on a wide desktop, tablet or browser window. The stacked
/// layouts cap to this; the side-by-side layout is allowed a little more room.
const double _maxContentWidth = 700;

/// Maximum content width for the wide, side-by-side shooting layout.
const double _maxWideContentWidth = 960;

/// Centres [child] and caps it to [maxWidth] so it never stretches full-width.
class _CenteredContent extends StatelessWidget {
  const _CenteredContent({
    required this.child,
    this.maxWidth = _maxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// The inner-ten count spoken in Norwegian (e.g. "3 indre tiere"), or an empty
/// string when there are none, so a screen reader reads the X count in words.
String _innerTensPhrase(int innerTens) {
  if (innerTens <= 0) return '';
  final noun = innerTens == 1 ? 'indre tier' : 'indre tiere';
  return ', $innerTens $noun';
}

/// A spoken score label like "Serie-sum: 87 av 100, 3 indre tiere", so a screen
/// reader announces the score in words rather than loose digits.
String _scoreSemanticsLabel({
  required String prefix,
  required int total,
  required int maxTotal,
  required int innerTens,
}) => '$prefix: $total av $maxTotal${_innerTensPhrase(innerTens)}';

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
  ///
  /// Pass [restored] to resume a saved recording (spec 0009): the session then
  /// starts from it instead of a fresh `Session.start`, with the program /
  /// metadata / weapon taken from the restored session.
  const SeriesScreen({
    required this.program,
    this.metadata,
    this.weapon,
    this.restored,
    this.actions,
    this.competitionId,
    super.key,
  });

  /// The program (discipline) being shot.
  final ProgramDefinition program;

  /// When and where this session was shot (spec 0008), or `null`.
  final SessionMetadata? metadata;

  /// The weapon this session is shot with, or `null` when none was chosen.
  final Weapon? weapon;

  /// A saved recording to resume into, or `null` to start fresh (spec 0009).
  final SessionRecording? restored;

  /// Extra actions shown in the app bar (e.g. a sign-out button).
  final List<Widget>? actions;

  /// The competition this session is shot for (spec 0012), or `null`.
  final String? competitionId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        currentProgramDefinitionProvider.overrideWithValue(program),
        currentSessionMetadataProvider.overrideWithValue(metadata),
        currentWeaponProvider.overrideWithValue(weapon),
        restoredRecordingProvider.overrideWithValue(restored),
        currentCompetitionIdProvider.overrideWithValue(competitionId),
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

  /// Opens the camera scan for [current]'s target (spec 0039) and commits the
  /// shots the shooter places on the photo into the series. Capped at the
  /// series' remaining capacity; the scan never seals the series itself.
  Future<void> _scanTarget(
    BuildContext context,
    WidgetRef ref,
    Series current,
  ) async {
    final shots = await Navigator.of(context).push<List<Shot>>(
      MaterialPageRoute<List<Shot>>(
        builder: (_) => ScanTargetScreen(
          geometry: current.geometry,
          maxShots: current.remaining,
        ),
      ),
    );
    if (shots != null && shots.isNotEmpty) {
      ref.read(sessionProvider.notifier).placeShots(shots);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recording = ref.watch(sessionProvider);
    final program = ref.watch(currentProgramDefinitionProvider);

    if (recording.isComplete) {
      return SessionScorecard(
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
            key: scanTargetActionKey,
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Skann skive',
            onPressed: current.isComplete
                ? null
                : () => _scanTarget(context, ref, current),
          ),
          IconButton(
            key: sealSeriesKey,
            icon: const Icon(Icons.check),
            tooltip: 'Fullfør serie',
            onPressed: current.isComplete
                ? () => ref.read(sessionProvider.notifier).advance()
                : null,
          ),
          ...?actions,
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _sideBySideBreakpoint;
            final header = _MetaRow(
              discipline: program.discipline,
              caliberMm: current.geometry.caliberMm,
            );
            final stageHeader = _StageHeader(
              program: program,
              session: session,
            );
            const target = AspectRatio(aspectRatio: 1, child: SeriesTarget());
            final shots = _ShotsList(
              placed: current.placedCount,
              capacity: current.capacity,
              score: seriesScore,
            );
            final totals = <Widget>[
              _SeriesTotalCard(score: seriesScore),
              if (multiSeries) ...[
                const SizedBox(height: 8),
                _SessionProgress(
                  total: runningTotal,
                  maxTotal: sealedScore.maxTotal,
                  innerTens: runningInnerTens,
                ),
              ],
            ];
            final legend = _Legend(hasInnerTen: current.geometry.hasInnerTen);

            // The target is passed through [scrollGuard] so that, while a
            // pointer hovers it (mouse/trackpad) or is pressed on it (a finger),
            // the page stops scrolling and the wheel/trackpad zoom and the
            // pinch/drag fall through to the target's InteractiveViewer instead
            // of being stolen by the page scroll (spec 0021).
            return _SessionScrollBody(
              maxWidth: wide ? _maxWideContentWidth : _maxContentWidth,
              builder: (scrollGuard) => wide
                  ? _wideLayout(
                      header: header,
                      stageHeader: stageHeader,
                      target: scrollGuard(target),
                      shots: shots,
                      totals: totals,
                      legend: legend,
                    )
                  : _stackedLayout(
                      header: header,
                      stageHeader: stageHeader,
                      target: scrollGuard(target),
                      shots: shots,
                      totals: totals,
                      legend: legend,
                    ),
            );
          },
        ),
      ),
    );
  }

  /// The narrow, single-column layout (the phone/tablet portrait view).
  Widget _stackedLayout({
    required Widget header,
    required Widget stageHeader,
    required Widget target,
    required Widget shots,
    required List<Widget> totals,
    required Widget legend,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 8),
        stageHeader,
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: target,
          ),
        ),
        const SizedBox(height: 16),
        shots,
        const SizedBox(height: 16),
        ...totals,
        const SizedBox(height: 12),
        legend,
      ],
    );
  }

  /// The wide layout: target on the left, shots + totals on the right, with the
  /// meta/stage header above and the legend below spanning the full width.
  Widget _wideLayout({
    required Widget header,
    required Widget stageHeader,
    required Widget target,
    required Widget shots,
    required List<Widget> totals,
    required Widget legend,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 8),
        stageHeader,
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: target,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  shots,
                  const SizedBox(height: 16),
                  ...totals,
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        legend,
      ],
    );
  }
}

/// The scrolling body of the session screen.
///
/// It hands the wheel/trackpad zoom and the pinch/drag to the interactive
/// target while a pointer is interacting with it: a [MouseRegion] tracks a
/// hovering mouse/trackpad pointer and a [Listener] counts fingers pressed on
/// the target. While either holds, the page [SingleChildScrollView] switches to
/// [NeverScrollableScrollPhysics], so the wheel scroll and the pinch/drag fall
/// through to the target's `InteractiveViewer` instead of being stolen by the
/// page scroll (spec 0021).
///
/// The touch case matters because a two-finger pinch with a vertical component
/// otherwise loses the gesture arena to the page's vertical scroll (the page
/// zooms only on horizontal pinches, if at all); suspending the page scroll
/// while a finger is down removes that competing recogniser so the pinch zooms
/// in any direction.
class _SessionScrollBody extends StatefulWidget {
  const _SessionScrollBody({required this.maxWidth, required this.builder});

  /// The maximum content width passed to [_CenteredContent].
  final double maxWidth;

  /// Builds the layout, wrapping the target in the supplied scroll guard — the
  /// callback that puts the target inside the [MouseRegion] + [Listener] that
  /// suspend page scrolling while a pointer hovers or presses it.
  final Widget Function(Widget Function(Widget target) scrollGuard) builder;

  @override
  State<_SessionScrollBody> createState() => _SessionScrollBodyState();
}

class _SessionScrollBodyState extends State<_SessionScrollBody> {
  /// Whether a mouse / trackpad pointer is currently hovering the target.
  bool _hovering = false;

  /// How many pointers (fingers) are currently pressed on the target.
  int _pointersDown = 0;

  /// Whether page scrolling is suspended so the target owns the gesture.
  bool get _suspendScroll => _hovering || _pointersDown > 0;

  /// Applies [change], then rebuilds only if it flipped [_suspendScroll] — so
  /// the stream of hover / pointer events does not rebuild needlessly.
  void _update(VoidCallback change) {
    final before = _suspendScroll;
    change();
    if (_suspendScroll != before) setState(() {});
  }

  /// Wraps [target] so hovering it (mouse/trackpad) or pressing it (a finger)
  /// suspends page scrolling, and leaving / releasing restores it. The
  /// [Listener] only observes pointers — it never joins the gesture arena — so
  /// the target's own tap / long-press / pinch behaviour is unchanged.
  Widget _scrollGuard(Widget target) {
    return MouseRegion(
      onEnter: (_) => _update(() => _hovering = true),
      onExit: (_) => _update(() => _hovering = false),
      child: Listener(
        onPointerDown: (_) => _update(() => _pointersDown++),
        onPointerUp: (_) => _update(() {
          if (_pointersDown > 0) _pointersDown--;
        }),
        onPointerCancel: (_) => _update(() {
          if (_pointersDown > 0) _pointersDown--;
        }),
        child: target,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: _suspendScroll ? const NeverScrollableScrollPhysics() : null,
      child: _CenteredContent(
        maxWidth: widget.maxWidth,
        child: widget.builder(_scrollGuard),
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
    return Semantics(
      header: true,
      label: '${stage.name}. ${parts.join(', ')}',
      child: ExcludeSemantics(
        child: Row(
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
        ),
      ),
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
        Semantics(
          label: 'Skudd: $placed av $capacity plassert',
          child: ExcludeSemantics(
            child: Row(
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
          ),
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
          _ShotRow(
            // The most recently placed shot is the highest placed index; it
            // carries the matching last-shot emphasis (spec 0020).
            key: placed > 0 && i == placed ? lastShotRowKey : null,
            index: i,
            score: i <= placed ? score.shots[i - 1] : null,
            highlighted: placed > 0 && i == placed,
          ),
      ],
    );
  }
}

class _ShotRow extends StatelessWidget {
  const _ShotRow({
    required this.index,
    required this.score,
    this.highlighted = false,
    super.key,
  });

  final int index;
  final ShotScore? score;

  /// Whether this is the most recently placed shot, given the matching
  /// last-shot emphasis (bold, accent) consistent with the target (spec 0020).
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shotScore = score;
    final pending = shotScore == null;
    final innerTen = shotScore?.isInnerTen ?? false;
    final label = pending
        ? 'Skudd $index: ikke plassert'
        : 'Skudd $index: ${shotScore.ring}${innerTen ? ', indre tier' : ''}';
    final Color? ringColor;
    if (highlighted) {
      ringColor = Colors.deepOrange;
    } else if (pending) {
      ringColor = theme.colorScheme.onSurfaceVariant;
    } else {
      ringColor = null;
    }
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Padding(
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
                  fontWeight: highlighted ? FontWeight.bold : FontWeight.w600,
                  color: ringColor,
                ),
              ),
              if (innerTen) ...[
                const SizedBox(width: 6),
                const _InnerTenDot(),
              ],
            ],
          ),
        ),
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
    return Semantics(
      label: _scoreSemanticsLabel(
        prefix: 'Serie-sum',
        total: score.total,
        maxTotal: score.maxTotal,
        innerTens: score.innerTens,
      ),
      child: ExcludeSemantics(
        child: Container(
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
                  innerTenScoreText(
                    context: context,
                    lead: 'Sum',
                    innerTens: score.innerTens,
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
                ],
              ),
            ],
          ),
        ),
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
    return Semantics(
      label: _scoreSemanticsLabel(
        prefix: 'Økt så langt',
        total: total,
        maxTotal: maxTotal,
        innerTens: innerTens,
      ),
      child: ExcludeSemantics(
        child: innerTenScoreText(
          context: context,
          lead: 'Session so far: $total',
          innerTens: innerTens,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
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

/// A read-only session scorecard (spec 0023): the program name, an optional
/// date/place/weapon caption, one row per stage with its per-series (skive)
/// breakdown, and the grand total.
///
/// Shared by the live completion screen ([SessionView]) and the "My sessions"
/// detail view (spec 0026), so the two can never drift apart. Pure presentation
/// — a function of the [program] and the precomputed [score] — so the history
/// detail re-scores a stored session and renders the identical card.
class SessionScorecard extends StatelessWidget {
  /// Creates a scorecard for [program] showing [score], optionally captioned
  /// with the [metadata] and [weapon] and carrying app-bar [actions].
  const SessionScorecard({
    required this.program,
    required this.score,
    this.metadata,
    this.weapon,
    this.actions,
    this.title,
    super.key,
  });

  /// The program (discipline) the session was shot in.
  final ProgramDefinition program;

  /// The rolled-up session score rendered on the card.
  final SessionScore score;

  /// When and where the session was shot, or `null` when none was recorded.
  final SessionMetadata? metadata;

  /// The weapon the session was shot with, or `null` when none was recorded.
  final Weapon? weapon;

  /// Extra actions shown in the app bar (e.g. a sign-out button).
  final List<Widget>? actions;

  /// App-bar title; defaults to the program name. Set it to show whose card
  /// this is — e.g. another shooter's name on a competition result (spec 0037).
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = _metadataCaption(metadata, weapon);
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? program.name),
        actions: [...?actions],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _CenteredContent(
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
                    stageIndex: i,
                    name: program.stages[i].name,
                    score: score.stages[i],
                  ),
                const SizedBox(height: 16),
                _GrandTotalCard(score: score),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StageScoreRow extends StatelessWidget {
  const _StageScoreRow({
    required this.stageIndex,
    required this.name,
    required this.score,
  });

  /// 0-based index of the stage, used to key its per-series rows.
  final int stageIndex;
  final String name;
  final StageScore score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: _scoreSemanticsLabel(
            prefix: name,
            total: score.total,
            maxTotal: score.maxTotal,
            innerTens: score.innerTens,
          ),
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: theme.textTheme.titleMedium),
                  innerTenScoreText(
                    context: context,
                    lead: '${score.total}',
                    innerTens: score.innerTens,
                    separator: '  ·  ',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Each series (skive) is shown subordinate to the stage subtotal, in
        // firing order, so every face's own result is visible (spec 0023).
        for (var i = 0; i < score.series.length; i++)
          _SeriesResultRow(
            key: seriesResultRow(stageIndex, i),
            number: i + 1,
            score: score.series[i],
          ),
      ],
    );
  }
}

/// One series (skive) result on the scorecard, subordinate to its stage
/// subtotal: a `Serie N` label and the series total over its maximum, with a
/// `· N Ⓧ` inner-ten suffix (a ringed X) when present (spec 0023).
class _SeriesResultRow extends StatelessWidget {
  const _SeriesResultRow({
    required this.number,
    required this.score,
    super.key,
  });

  /// 1-based series number within its stage (the skive number).
  final int number;
  final SeriesScore score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = 'Serie $number';
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Semantics(
      label: _scoreSemanticsLabel(
        prefix: label,
        total: score.total,
        maxTotal: score.maxTotal,
        innerTens: score.innerTens,
      ),
      child: ExcludeSemantics(
        child: Padding(
          // Indented from the left so the skive rows sit under the stage row.
          padding: const EdgeInsets.only(left: 16, top: 2, bottom: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: style),
              innerTenScoreText(
                context: context,
                lead: '${score.total}',
                innerTens: score.innerTens,
                separator: '  ·  ',
                style: style,
              ),
            ],
          ),
        ),
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
    return Semantics(
      label: _scoreSemanticsLabel(
        prefix: 'Økt-sum',
        total: score.total,
        maxTotal: score.maxTotal,
        innerTens: score.innerTens,
      ),
      child: ExcludeSemantics(
        child: Container(
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
                  innerTenScoreText(
                    context: context,
                    lead: 'Sum',
                    innerTens: score.innerTens,
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
                ],
              ),
            ],
          ),
        ),
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
