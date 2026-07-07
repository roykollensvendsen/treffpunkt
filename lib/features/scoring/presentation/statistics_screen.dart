// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/presentation/content_scaffold.dart';
import 'package:treffpunkt/core/presentation/empty_state.dart';
import 'package:treffpunkt/core/presentation/inner_ten_x.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';
import 'package:treffpunkt/features/scoring/domain/exercise_progress.dart';
import 'package:treffpunkt/features/scoring/domain/personal_best.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/personal_records_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/personal_records_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/upload_queue.dart';

/// Key for the "Statistikk" app-bar action on "Mine økter" (spec 0090).
const Key statisticsButtonKey = ValueKey<String>('statisticsButton');

/// Key for the exercise dropdown (spec 0090), for tests.
const Key exerciseDropdownKey = ValueKey<String>('exerciseDropdown');

/// Key for the progress chart (spec 0090), for tests.
const Key progressChartKey = ValueKey<String>('progressChart');

/// Key for the no-statistics empty state (spec 0090), for tests.
const Key noStatisticsKey = ValueKey<String>('noStatistics');

/// Key for the «Rekorder» app-bar action (spec 0102), for tests.
const Key statisticsRecordsKey = ValueKey<String>('statisticsRecords');

/// The felt exercise names per course and group (specs 0143/0145), in
/// course-then-group order — the same labels the Rekorder page keys records
/// by (spec 0102).
final List<String> _feltExercises = <String>[
  for (final course in feltCourses)
    for (final group in FeltShooterGroup.values) feltRecordKey(course, group),
];

/// The series colours (spec 0090), validated with the dataviz palette
/// validator against the app's light (#F9F9FF) and dark (#111318) surfaces
/// (re-run for the spec-0100 reseed). Aqua-on-light sits below 3:1 contrast,
/// so the chart always direct-labels the last value of each series in text
/// ink (the relief rule).
Color _pointsColor(Brightness brightness) => brightness == Brightness.dark
    ? const Color(0xFF3987E5)
    : const Color(0xFF2A78D6);

Color _innerColor(Brightness brightness) => brightness == Brightness.dark
    ? const Color(0xFF199E70)
    : const Color(0xFF1BAF7A);

/// Progress curves per exercise (spec 0090): the shooter picks an exercise
/// and sees poengsum and innertreff per completed session, in one coordinate
/// system — the x-axis is the sessions in chronological order, no time axis.
class StatisticsScreen extends ConsumerStatefulWidget {
  /// Creates the statistics screen.
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  /// The picked exercise, or null until the user picks (defaults to the
  /// first exercise with data).
  String? _exercise;

  @override
  Widget build(BuildContext context) {
    // The same union "Mine økter" shows (spec 0026/0082/0083): pending (live
    // queue + durable outbox) merged with the synced sessions by id, plus
    // the felt rounds, local merged with synced.
    final live = ref.watch(uploadQueueProvider);
    final stored = ref.watch(storedPendingProvider).value ?? const [];
    final synced =
        ref.watch(syncedSessionsProvider).value ?? const <SessionRecord>[];
    final pending = <String, SessionRecord>{
      for (final record in stored) record.id: record,
      for (final record in live) record.id: record,
    }.values.toList();
    final entries = mergeMySessions(synced: synced, pending: pending);
    final feltRounds = mergeFeltRounds(
      local: ref.watch(feltHistoryProvider).value ?? const [],
      synced: ref.watch(feltSyncedSessionsProvider).value ?? const [],
    );

    // Group into per-exercise samples; only dated sessions can be ordered.
    final byExercise = <String, List<ProgressSample>>{};
    for (final entry in entries) {
      final record = entry.record;
      byExercise
          .putIfAbsent(record.program, () => <ProgressSample>[])
          .add(
            ProgressSample(
              capturedAt: record.capturedAt,
              points: record.total,
              inner: record.innerTens,
            ),
          );
    }
    for (final round in feltRounds) {
      final tally = round.tally;
      // One exercise per felt group (spec 0143): the groups shoot different
      // figures, so their points only compare within the group.
      byExercise
          .putIfAbsent(
            feltRecordKey(
              feltCourseById(round.session.courseId),
              round.session.group,
            ),
            () => <ProgressSample>[],
          )
          .add(
            ProgressSample(
              capturedAt: round.capturedAt,
              points: tally.points,
              inner: tally.inner,
            ),
          );
    }
    final series = <String, List<ProgressEntry>>{
      for (final exercise in byExercise.keys)
        exercise: progressSeries(byExercise[exercise]!),
    }..removeWhere((_, entries) => entries.isEmpty);

    // Offer the exercises in catalogue order, the felt groups last, then any
    // legacy names (a stored program no longer in the catalogue) at the end.
    final exercises = <String>[
      for (final program in ProgramCatalogue.all)
        if (series.containsKey(program.name)) program.name,
      for (final felt in _feltExercises)
        if (series.containsKey(felt)) felt,
      for (final name in series.keys)
        if (ProgramCatalogue.byName(name) == null &&
            !_feltExercises.contains(name))
          name,
    ];

    final selected = exercises.contains(_exercise)
        ? _exercise!
        : (exercises.isEmpty ? null : exercises.first);

    // The selected exercise's *effective* record (spec 0142): the best of
    // the manual baseline and every recorded session — dated or not — so
    // the line always agrees with the Rekorder page. A felt exercise IS a
    // group (spec 0143), keyed exactly like its record, so both paths are
    // the same shape.
    final baselines = ref.watch(personalRecordsProvider);
    ExerciseResult? pers;
    if (selected != null) {
      final history = _feltExercises.contains(selected)
          ? <ExerciseResult>[
              for (final round in feltRounds)
                if (feltRecordKey(
                      feltCourseById(round.session.courseId),
                      round.session.group,
                    ) ==
                    selected)
                  (points: round.tally.points, inner: round.tally.inner),
            ]
          : <ExerciseResult>[
              for (final entry in entries)
                if (entry.record.program == selected)
                  (points: entry.record.total, inner: entry.record.innerTens),
            ];
      pers = bestResult(<ExerciseResult>[?baselines[selected], ...history]);
    }

    return ContentScaffold(
      title: const Text('Statistikk'),
      actions: [
        // The records page (spec 0102): startverdier and current pers.
        IconButton(
          key: statisticsRecordsKey,
          icon: const Icon(Icons.emoji_events_outlined),
          tooltip: 'Rekorder',
          onPressed: () => unawaited(
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PersonalRecordsScreen(),
              ),
            ),
          ),
        ),
      ],
      body: selected == null
          ? const EmptyState(
              icon: Icons.show_chart,
              title: 'Ingen fullførte økter med dato ennå.',
              titleKey: noStatisticsKey,
              hint: 'Fullfør en økt, så dukker kurvene opp her.',
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    key: exerciseDropdownKey,
                    initialValue: selected,
                    decoration: const InputDecoration(
                      labelText: 'Øvelse',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final exercise in exercises)
                        DropdownMenuItem<String>(
                          value: exercise,
                          child: Text(
                            exercise,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => _exercise = value),
                  ),
                  const SizedBox(height: 12),
                  _Legend(brightness: Theme.of(context).brightness),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ProgressChart(
                      exercise: selected,
                      entries: series[selected]!,
                      persPoints: pers?.points,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// The legend (spec 0090): both series named beside their colour chip, so
/// colour is never the only carrier of identity. Text wears text colours.
class _Legend extends StatelessWidget {
  const _Legend({required this.brightness});

  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    Widget chip(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
    return Row(
      children: [
        chip(_pointsColor(brightness), 'Poengsum'),
        const SizedBox(width: 16),
        chip(_innerColor(brightness), 'Innertreff'),
      ],
    );
  }
}

/// The two curves in one coordinate system (spec 0090): poengsum and
/// innertreff per session, x = session order. Tap or drag to inspect the
/// nearest session; the last value of each series is directly labelled.
/// The personal record is a dashed reference line (spec 0142).
class ProgressChart extends StatefulWidget {
  /// Creates the chart for [exercise]'s [entries].
  const ProgressChart({
    required this.exercise,
    required this.entries,
    this.persPoints,
    super.key,
  });

  /// The exercise name, spoken in the accessibility summary.
  final String exercise;

  /// The sessions in chronological order.
  final List<ProgressEntry> entries;

  /// The effective personal record's points (spec 0142), the «Pers» line;
  /// null draws no line.
  final int? persPoints;

  @override
  State<ProgressChart> createState() => _ProgressChartState();
}

class _ProgressChartState extends State<ProgressChart> {
  /// Index of the inspected session, or null.
  int? _inspected;

  @override
  void didUpdateWidget(ProgressChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise != widget.exercise) _inspected = null;
  }

  void _inspectAt(Offset local, double width) {
    final n = widget.entries.length;
    final x = (local.dx - _ProgressChartPainter.leftPad).clamp(
      0.0,
      math.max(1.0, width - _ProgressChartPainter.horizontalPad),
    );
    final plotWidth = width - _ProgressChartPainter.horizontalPad;
    final index = n == 1
        ? 0
        : (x / plotWidth * (n - 1)).round().clamp(0, n - 1);
    setState(() => _inspected = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final entries = widget.entries;
    final inspected = _inspected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 28,
          child: inspected == null
              ? Text(
                  'Trykk på kurven for å se en økt.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : innerTenScoreText(
                  context: context,
                  lead:
                      'Økt ${inspected + 1}: '
                      '${entries[inspected].points} poeng',
                  innerTens: entries[inspected].inner,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
        Expanded(
          child: Semantics(
            label: _summary(),
            child: ExcludeSemantics(
              child: LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  onTapDown: (details) =>
                      _inspectAt(details.localPosition, constraints.maxWidth),
                  onHorizontalDragUpdate: (details) =>
                      _inspectAt(details.localPosition, constraints.maxWidth),
                  child: CustomPaint(
                    key: progressChartKey,
                    size: Size.infinite,
                    painter: _ProgressChartPainter(
                      entries: entries,
                      pointsColor: _pointsColor(brightness),
                      innerColor: _innerColor(brightness),
                      inkColor: theme.colorScheme.onSurface,
                      mutedColor: theme.colorScheme.onSurfaceVariant,
                      gridColor: theme.colorScheme.outlineVariant,
                      // Inherit the app's font so the painted labels match
                      // the widget text around the chart.
                      fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                      inspected: inspected,
                      persPoints: widget.persPoints,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The text summary a screen reader gets instead of the pixels (req 7),
  /// with the personal record when there is one (spec 0142 req 6).
  String _summary() {
    final entries = widget.entries;
    final best = entries.map((e) => e.points).reduce(math.max);
    final pers = widget.persPoints;
    return 'Statistikk for ${widget.exercise}: ${entries.length} økter. '
        'Første ${entries.first.points} poeng, '
        'siste ${entries.last.points} poeng, beste $best poeng. '
        'Innertreff siste økt: ${entries.last.inner}.'
        '${pers == null ? '' : ' Pers: $pers poeng.'}';
  }
}

/// Paints the two polylines with markers, recessive gridlines, axis labels,
/// the direct labels on the last values and the inspector guide (spec 0090).
class _ProgressChartPainter extends CustomPainter {
  _ProgressChartPainter({
    required this.entries,
    required this.pointsColor,
    required this.innerColor,
    required this.inkColor,
    required this.mutedColor,
    required this.gridColor,
    required this.fontFamily,
    required this.inspected,
    required this.persPoints,
  });

  final List<ProgressEntry> entries;
  final Color pointsColor;
  final Color innerColor;
  final Color inkColor;
  final Color mutedColor;
  final Color gridColor;
  final String? fontFamily;
  final int? inspected;
  final int? persPoints;

  /// Room for the y-axis labels (left) and the last-value labels (right).
  static const double leftPad = 40;

  /// Room to the right of the plot for the direct value labels.
  static const double rightPad = 44;

  /// [leftPad] + [rightPad], the total horizontal padding.
  static const double horizontalPad = leftPad + rightPad;

  static const double _topPad = 10;
  static const double _bottomPad = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      leftPad,
      _topPad,
      size.width - rightPad,
      size.height - _bottomPad,
    );
    final n = entries.length;
    // The record is part of the scale (spec 0142 req 4): a startverdi above
    // every plotted session must stay visible, not clip off the top.
    final maxValue = math.max(
      math.max(1, persPoints ?? 0),
      entries.map((e) => math.max(e.points, e.inner)).reduce(math.max),
    );
    final step = _niceStep(maxValue / 4);
    final yMax = ((maxValue + step - 1) ~/ step) * step;

    double x(int index) =>
        n == 1 ? plot.center.dx : plot.left + plot.width * index / (n - 1);
    double y(num value) => plot.bottom - plot.height * value / yMax;

    _grid(canvas, plot, yMax, step);
    _persLine(canvas, plot, y);
    _xLabels(canvas, plot, x);
    _guide(canvas, plot, x);
    _series(canvas, entries.map((e) => e.points).toList(), pointsColor, x, y);
    _series(canvas, entries.map((e) => e.inner).toList(), innerColor, x, y);
    _lastValueLabel(canvas, entries.last.points, x(n - 1), y, above: true);
    _lastValueLabel(canvas, entries.last.inner, x(n - 1), y, above: false);
  }

  /// Recessive horizontal gridlines with muted y labels at nice ticks.
  void _grid(Canvas canvas, Rect plot, int yMax, int step) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var value = 0; value <= yMax; value += step) {
      final dy = plot.bottom - plot.height * value / yMax;
      canvas.drawLine(Offset(plot.left, dy), Offset(plot.right, dy), paint);
      _text(
        canvas,
        '$value',
        Offset(plot.left - 6, dy),
        color: mutedColor,
        align: _Align.rightCenter,
      );
    }
  }

  /// The personal-record annotation (spec 0142): a dashed hairline in the
  /// muted ink — visibly not a gridline (those are solid) and quieter than
  /// the 2 px data lines — direct-labelled «Pers N» in text ink, so it
  /// needs no legend entry.
  void _persLine(Canvas canvas, Rect plot, double Function(num) y) {
    final pers = persPoints;
    if (pers == null) return;
    final dy = y(pers);
    final paint = Paint()
      ..color = mutedColor
      ..strokeWidth = 1;
    const dash = 4.0;
    for (var dx = plot.left; dx < plot.right; dx += dash * 2) {
      canvas.drawLine(
        Offset(dx, dy),
        Offset(math.min(dx + dash, plot.right), dy),
        paint,
      );
    }
    // Label above the line, except when the line hugs the top of the plot.
    final above = dy - plot.top > 16;
    _text(
      canvas,
      'Pers $pers',
      Offset(plot.left + 4, dy + (above ? -3 : 3)),
      color: inkColor,
      bold: true,
      align: above ? _Align.bottomLeft : _Align.topLeft,
    );
  }

  /// Session numbers under the axis: all of them when few, subsampled when
  /// many so the labels never collide.
  void _xLabels(Canvas canvas, Rect plot, double Function(int) x) {
    final n = entries.length;
    final every = math.max(1, (n / 10).ceil());
    for (var i = 0; i < n; i += every) {
      _text(
        canvas,
        '${i + 1}',
        Offset(x(i), plot.bottom + 4),
        color: mutedColor,
        align: _Align.topCenter,
      );
    }
  }

  /// The inspected session's vertical guide, under the series.
  void _guide(Canvas canvas, Rect plot, double Function(int) x) {
    final index = inspected;
    if (index == null || index >= entries.length) return;
    canvas.drawLine(
      Offset(x(index), plot.top),
      Offset(x(index), plot.bottom),
      Paint()
        ..color = mutedColor
        ..strokeWidth = 1,
    );
  }

  /// One series: a 2 px polyline with 8 px markers (spec 0090 mark specs).
  void _series(
    Canvas canvas,
    List<int> values,
    Color color,
    double Function(int) x,
    double Function(num) y,
  ) {
    final line = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final p = Offset(x(i), y(values[i]));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    if (values.length > 1) canvas.drawPath(path, line);
    final dot = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final radius = i == inspected ? 5.0 : 4.0;
      canvas.drawCircle(Offset(x(i), y(values[i])), radius, dot);
    }
  }

  /// The direct label on a series' last value, in text ink — the relief for
  /// the low-contrast aqua on the light surface (spec 0090).
  void _lastValueLabel(
    Canvas canvas,
    int value,
    double lastX,
    double Function(num) y, {
    // Points above their marker, inner below, so the two never collide.
    required bool above,
  }) {
    _text(
      canvas,
      '$value',
      Offset(lastX + 8, y(value) + (above ? -2 : 2)),
      color: inkColor,
      bold: true,
      align: above ? _Align.bottomLeft : _Align.topLeft,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset anchor, {
    required Color color,
    required _Align align,
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontFamily: fontFamily,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final offset = switch (align) {
      _Align.rightCenter => anchor - Offset(painter.width, painter.height / 2),
      _Align.topCenter => anchor - Offset(painter.width / 2, 0),
      _Align.bottomLeft => anchor - Offset(0, painter.height),
      _Align.topLeft => anchor,
    };
    painter.paint(canvas, offset);
  }

  /// The smallest 1/2/5 × 10^k at or above [rough] — a nice tick step, so
  /// the axis tops out just above the data instead of at the next decade.
  static int _niceStep(double rough) {
    var magnitude = 1;
    while (magnitude * 10 <= rough) {
      magnitude *= 10;
    }
    for (final factor in <int>[1, 2, 5]) {
      if (factor * magnitude >= rough) return factor * magnitude;
    }
    return 10 * magnitude;
  }

  @override
  bool shouldRepaint(_ProgressChartPainter old) =>
      old.entries != entries ||
      old.inspected != inspected ||
      old.persPoints != persPoints ||
      old.pointsColor != pointsColor ||
      old.innerColor != innerColor;
}

enum _Align { rightCenter, topCenter, bottomLeft, topLeft }
