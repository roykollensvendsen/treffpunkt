// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/presentation/content_scaffold.dart';
import 'package:treffpunkt/core/presentation/frosted_bar.dart';
import 'package:treffpunkt/core/presentation/inner_ten_x.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';
import 'package:treffpunkt/features/scoring/domain/personal_best.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/session_record.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/personal_records_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/upload_queue.dart';

/// Key for one exercise's row on the records page (spec 0102), for tests.
Key recordRowKey(String exercise) => ValueKey<String>('record-$exercise');

/// Key for the points field in the baseline dialog, for tests.
const Key recordPointsFieldKey = ValueKey<String>('recordPointsField');

/// Key for the inner-hits field in the baseline dialog, for tests.
const Key recordInnerFieldKey = ValueKey<String>('recordInnerField');

/// Key for the save action in the baseline dialog, for tests.
const Key recordSaveKey = ValueKey<String>('recordSave');

/// Key for the remove action in the baseline dialog, for tests.
const Key recordRemoveKey = ValueKey<String>('recordRemove');

/// One exercise on the records page: its map [key], display [label] and the
/// [history] results recorded in the app.
class _RecordEntry {
  const _RecordEntry({
    required this.key,
    required this.label,
    required this.history,
  });

  final String key;
  final String label;
  final List<ExerciseResult> history;
}

/// The «Rekorder» page (spec 0102): every exercise with the shooter's
/// *effective* personal record — the best of the manual baseline ("what I
/// had before the app") and every session recorded in the app — so beating
/// a record updates it by construction, with nothing to maintain. Tapping a
/// row edits the baseline.
class PersonalRecordsScreen extends ConsumerWidget {
  /// Creates the records page.
  const PersonalRecordsScreen({super.key});

  /// The exercises shown: every catalogue program, then the felt course per
  /// group — each with its recorded-session results.
  List<_RecordEntry> _entries(WidgetRef ref) {
    final live = ref.watch(uploadQueueProvider);
    final stored = ref.watch(storedPendingProvider).value ?? const [];
    final synced =
        ref.watch(syncedSessionsProvider).value ?? const <SessionRecord>[];
    final sessions = mergeMySessions(
      synced: synced,
      pending: [...stored, ...live],
    );
    final rounds = mergeFeltRounds(
      local: ref.watch(feltHistoryProvider).value ?? const [],
      synced: ref.watch(feltSyncedSessionsProvider).value ?? const [],
    );
    return [
      for (final program in ProgramCatalogue.all)
        _RecordEntry(
          key: program.name,
          label: program.name,
          history: [
            for (final entry in sessions)
              if (entry.record.program == program.name)
                (points: entry.record.total, inner: entry.record.innerTens),
          ],
        ),
      // One row per course and group (specs 0143/0145): points only
      // compare within the same course and group.
      for (final course in feltCourses)
        for (final group in FeltShooterGroup.offered)
          _RecordEntry(
            key: feltRecordKey(course, group),
            label: feltRecordKey(course, group),
            history: [
              for (final round in rounds)
                if (round.session.group == group &&
                    feltCourseById(round.session.courseId).id == course.id)
                  (points: round.tally.points, inner: round.tally.inner),
            ],
          ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baselines = ref.watch(personalRecordsProvider);
    final entries = _entries(ref);
    return ContentScaffold.behindBar(
      title: const Text('Rekorder'),
      // The Builder gives a context INSIDE the body, where the
      // Scaffold injects the bar insets (spec 0129).
      body: Builder(
        builder: (context) => ListView(
          padding: frostedScrollPadding(
            context,
            horizontal: 0,
            top: 8,
            bottom: 8,
          ),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Rekorden er det beste av startverdien din og øktene '
                'du har skutt i appen — slår du den, oppdateres den '
                'av seg selv. Trykk på en øvelse for å sette '
                'startverdien fra før du tok appen i bruk.',
              ),
            ),
            for (final entry in entries)
              _RecordRow(
                key: recordRowKey(entry.key),
                entry: entry,
                baseline: baselines[entry.key],
              ),
          ],
        ),
      ),
    );
  }
}

class _RecordRow extends ConsumerWidget {
  const _RecordRow({required this.entry, required this.baseline, super.key});

  final _RecordEntry entry;
  final ExerciseResult? baseline;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(personalRecordsProvider.notifier);
    final result = await showDialog<_BaselineEdit>(
      context: context,
      builder: (_) => _BaselineDialog(
        exercise: entry.label,
        baseline: baseline,
      ),
    );
    switch (result) {
      case null:
        break;
      case _BaselineRemoved():
        notifier.removeRecord(entry.key);
      case _BaselineSaved(:final record):
        notifier.setRecord(entry.key, record);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effective = bestResult([?baseline, ...entry.history]);
    return ListTile(
      title: Text(entry.label),
      subtitle: effective == null
          ? const Text('Ingen rekord ennå')
          : innerTenScoreText(
              context: context,
              lead: '${effective.points} poeng',
              innerTens: effective.inner,
            ),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => unawaited(_edit(context, ref)),
    );
  }
}

/// The outcome of the baseline dialog: saved with a record, or removed.
sealed class _BaselineEdit {
  const _BaselineEdit();
}

class _BaselineSaved extends _BaselineEdit {
  const _BaselineSaved(this.record);

  final ExerciseResult record;
}

class _BaselineRemoved extends _BaselineEdit {
  const _BaselineRemoved();
}

class _BaselineDialog extends StatefulWidget {
  const _BaselineDialog({required this.exercise, required this.baseline});

  final String exercise;
  final ExerciseResult? baseline;

  @override
  State<_BaselineDialog> createState() => _BaselineDialogState();
}

class _BaselineDialogState extends State<_BaselineDialog> {
  late final TextEditingController _points = TextEditingController(
    text: widget.baseline == null ? '' : '${widget.baseline!.points}',
  );
  late final TextEditingController _inner = TextEditingController(
    text: widget.baseline == null ? '' : '${widget.baseline!.inner}',
  );

  @override
  void dispose() {
    _points.dispose();
    _inner.dispose();
    super.dispose();
  }

  void _save() {
    final points = int.tryParse(_points.text.trim());
    if (points == null || points < 0) return;
    final inner = int.tryParse(_inner.text.trim()) ?? 0;
    Navigator.of(
      context,
    ).pop(_BaselineSaved((points: points, inner: inner < 0 ? 0 : inner)));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.exercise),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: recordPointsFieldKey,
          controller: _points,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Poeng',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: recordInnerFieldKey,
          controller: _inner,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Innertreff',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    ),
    actions: [
      if (widget.baseline != null)
        TextButton(
          key: recordRemoveKey,
          onPressed: () => Navigator.of(context).pop(const _BaselineRemoved()),
          child: const Text('Fjern'),
        ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Avbryt'),
      ),
      FilledButton(
        key: recordSaveKey,
        onPressed: _save,
        child: const Text('Lagre'),
      ),
    ],
  );
}
