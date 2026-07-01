// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hit_test.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art_data.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art_painter.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';

/// Key for the group-picker button for [group] (spec 0080), for tests.
Key feltGroupButtonKey(FeltShooterGroup group) =>
    ValueKey<String>('feltGroup-${group.name}');

/// Key for the tappable hold recorder area (spec 0080).
const Key feltHoldRecorderKey = ValueKey<String>('feltHoldRecorder');

/// Key for the current hold's points text (spec 0080).
const Key feltHoldPointsKey = ValueKey<String>('feltHoldPoints');

/// Key for the running session total text (spec 0080).
const Key feltTotalPointsKey = ValueKey<String>('feltTotalPoints');

/// Key for the final scorecard (spec 0080).
const Key feltScorecardKey = ValueKey<String>('feltScorecard');

/// Records a NorgesFelt session (spec 0080): pick a group, then place each shot
/// on every hold and see the score, ending on a scorecard. The in-progress
/// round is saved after each change and can be [restored] (spec 0081).
class FeltRecordScreen extends ConsumerStatefulWidget {
  /// Creates the recorder, optionally resuming a saved [restored] round.
  const FeltRecordScreen({this.restored, super.key});

  /// A saved round to resume into, or null to start fresh (spec 0081).
  final FeltSessionSnapshot? restored;

  @override
  ConsumerState<FeltRecordScreen> createState() => _FeltRecordScreenState();
}

class _Placed {
  const _Placed(this.pos, this.shot);
  final Offset pos;
  final FeltShot shot;
}

class _FeltRecordScreenState extends ConsumerState<FeltRecordScreen> {
  FeltShooterGroup? _group;
  int _hold = 0;
  bool _done = false;
  late List<List<_Placed>> _shots;

  @override
  void initState() {
    super.initState();
    final restored = widget.restored;
    if (restored != null) {
      _group = restored.group;
      _hold = restored.currentHold;
      _shots = <List<_Placed>>[
        for (final hold in restored.holds)
          <_Placed>[
            for (final s in hold)
              _Placed(
                Offset(s.dx, s.dy),
                FeltShot(figureIndex: s.figureIndex, inner: s.inner),
              ),
          ],
      ];
    } else {
      _shots = List<List<_Placed>>.generate(
        norgesfelt2026Art.length,
        (_) => <_Placed>[],
      );
    }
  }

  FeltHoldTally _tally(int i) =>
      FeltHoldTally(_shots[i].map((p) => p.shot).toList());

  FeltSessionTally get _session => FeltSessionTally(
    group: _group!,
    holds: <FeltHoldTally>[for (var i = 0; i < _shots.length; i++) _tally(i)],
  );

  int get _totalShots => _shots.fold(0, (sum, h) => sum + h.length);

  FeltSessionSnapshot _snapshot() => FeltSessionSnapshot(
    group: _group!,
    currentHold: _hold,
    holds: <List<FeltPlacedShot>>[
      for (final hold in _shots)
        <FeltPlacedShot>[
          for (final p in hold)
            FeltPlacedShot(
              dx: p.pos.dx,
              dy: p.pos.dy,
              figureIndex: p.shot.figureIndex,
              inner: p.shot.inner,
            ),
        ],
    ],
  );

  /// Saves the in-progress round, or clears the store when there is nothing
  /// worth resuming (no group, no shots, or finished). Best-effort (spec 0081).
  void _persist() {
    final store = ref.read(feltSessionStoreProvider);
    final write = (_group == null || _done || _totalShots == 0)
        ? store.clear()
        : store.save(_snapshot());
    unawaited(write.catchError((Object _) {}));
  }

  void _pickGroup(FeltShooterGroup group) {
    setState(() => _group = group);
    _persist();
  }

  void _place(FeltHoldArt art, Offset holdPoint) {
    if (_shots[_hold].length >= _group!.shotsPerHold) return;
    setState(() {
      _shots[_hold].add(_Placed(holdPoint, feltHitTest(art, holdPoint)));
    });
    _persist();
  }

  void _mutate(VoidCallback change) {
    setState(change);
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    if (_group == null) {
      return _GroupPicker(onPick: _pickGroup);
    }
    if (_done) {
      return _Scorecard(
        session: _session,
        onBack: () => setState(() => _done = false),
      );
    }
    return _recording(context);
  }

  Widget _recording(BuildContext context) {
    final theme = Theme.of(context);
    final art = norgesfelt2026Art[_hold];
    final hold = norgesfelt2026[_hold];
    final placed = _shots[_hold];
    final tally = _tally(_hold);
    final shotsMax = _group!.shotsPerHold;
    return Scaffold(
      appBar: AppBar(
        title: Text('Hold ${hold.number}/${norgesfelt2026.length}'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                Text(
                  '${hold.distance}  ·  ${hold.position}',
                  style: theme.textTheme.labelMedium,
                ),
                Text(
                  'Skudd ${placed.length}/$shotsMax  ·  '
                  'trykk på figurene der du traff',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                _HoldRecorder(
                  key: feltHoldRecorderKey,
                  art: art,
                  shots: placed,
                  onPlace: (p) => _place(art, p),
                ),
                const SizedBox(height: 8),
                Text(
                  key: feltHoldPointsKey,
                  'Treff ${tally.treff} · Figur ${tally.figures} · '
                  'Inner ${tally.inner}  =  ${tally.points} poeng',
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  key: feltTotalPointsKey,
                  'Totalt så langt: ${_session.points} poeng',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    TextButton.icon(
                      onPressed: placed.isEmpty
                          ? null
                          : () => _mutate(placed.removeLast),
                      icon: const Icon(Icons.undo),
                      label: const Text('Angre'),
                    ),
                    TextButton.icon(
                      onPressed: placed.isEmpty
                          ? null
                          : () => _mutate(placed.clear),
                      icon: const Icon(Icons.clear),
                      label: const Text('Tøm'),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    TextButton(
                      onPressed: _hold == 0
                          ? null
                          : () => _mutate(() => _hold--),
                      child: const Text('Forrige'),
                    ),
                    if (_hold < norgesfelt2026.length - 1)
                      FilledButton(
                        onPressed: () => _mutate(() => _hold++),
                        child: const Text('Neste'),
                      )
                    else
                      FilledButton(
                        onPressed: () => _mutate(() => _done = true),
                        child: const Text('Fullfør'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Picks the shooter group before recording (spec 0080).
class _GroupPicker extends StatelessWidget {
  const _GroupPicker({required this.onPick});

  final ValueChanged<FeltShooterGroup> onPick;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Skyt NorgesFelt-løypa')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Velg gruppe — den bestemmer skudd per hold.'),
              ),
              for (final g in FeltShooterGroup.values)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: FilledButton.tonal(
                    key: feltGroupButtonKey(g),
                    onPressed: () => onPick(g),
                    child: Text('${g.label}  ·  ${g.shotsPerHold} skudd/hold'),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The composed hold with tap-to-place shot markers (spec 0080).
class _HoldRecorder extends StatelessWidget {
  const _HoldRecorder({
    required this.art,
    required this.shots,
    required this.onPlace,
    super.key,
  });

  final FeltHoldArt art;
  final List<_Placed> shots;
  final ValueChanged<Offset> onPlace;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final w = constraints.maxWidth;
      final scale = w / art.size.width;
      final h = art.size.height * scale;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => onPlace(
          Offset(d.localPosition.dx / scale, d.localPosition.dy / scale),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
            ),
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: CustomPaint(painter: FeltHoldArtPainter(art)),
                  ),
                  for (final s in shots)
                    Positioned(
                      left: s.pos.dx * scale - 7,
                      top: s.pos.dy * scale - 7,
                      child: _ShotMarker(shot: s.shot),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// A placed-shot marker, coloured by outcome (spec 0080).
class _ShotMarker extends StatelessWidget {
  const _ShotMarker({required this.shot});

  final FeltShot shot;

  @override
  Widget build(BuildContext context) {
    final color = !shot.isHit
        ? Colors.red
        : shot.inner
        ? const Color(0xFF19C37D)
        : Colors.amber;
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black45, blurRadius: 2),
        ],
      ),
    );
  }
}

/// The end-of-session scorecard (spec 0080).
class _Scorecard extends StatelessWidget {
  const _Scorecard({required this.session, required this.onBack});

  final FeltSessionTally session;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultat'),
        leading: BackButton(onPressed: onBack),
      ),
      body: SafeArea(
        key: feltScorecardKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                for (var i = 0; i < session.holds.length; i++)
                  ListTile(
                    dense: true,
                    title: Text('Hold ${i + 1}'),
                    subtitle: Text(
                      'Treff ${session.holds[i].treff} · '
                      'Figur ${session.holds[i].figures} · '
                      'Inner ${session.holds[i].inner}',
                    ),
                    trailing: Text(
                      '${session.holds[i].points}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                const Divider(),
                ListTile(
                  title: Text(
                    'Totalt (${session.group.label})',
                    style: theme.textTheme.titleMedium,
                  ),
                  trailing: Text(
                    '${session.points} poeng',
                    style: theme.textTheme.titleLarge,
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
