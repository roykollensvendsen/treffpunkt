// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/presentation/frosted_bar.dart';
import 'package:treffpunkt/core/presentation/inner_ten_x.dart';
import 'package:treffpunkt/core/presentation/zoom_controls.dart';
import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/domain/felt_scoring.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_record.dart';
import 'package:treffpunkt/features/felt/domain/felt_session_snapshot.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hit_test.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art_data.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art_painter.dart';
import 'package:treffpunkt/features/felt/presentation/felt_providers.dart';
import 'package:treffpunkt/features/felt/presentation/felt_scorecard.dart';
import 'package:treffpunkt/features/scoring/domain/personal_best.dart';
import 'package:treffpunkt/features/scoring/domain/session_metadata.dart';
import 'package:treffpunkt/features/scoring/presentation/my_sessions_providers.dart';
import 'package:treffpunkt/features/scoring/presentation/personal_records_providers.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';

/// Key for the group-picker button for [group] (spec 0080), for tests.
Key feltGroupButtonKey(FeltShooterGroup group) =>
    ValueKey<String>('feltGroup-${group.name}');

/// Key for the tappable hold recorder area (spec 0080).
const Key feltHoldRecorderKey = ValueKey<String>('feltHoldRecorder');

/// Key for the current hold's points text (spec 0080).
const Key feltHoldPointsKey = ValueKey<String>('feltHoldPoints');

/// Key for the running session total text (spec 0080).
const Key feltTotalPointsKey = ValueKey<String>('feltTotalPoints');

/// Key for the "Bytt gruppe" action while no shots are placed (spec 0099).
const Key feltChangeGroupKey = ValueKey<String>('feltChangeGroup');

/// Key for the scorecard's "Lagre økt" button (spec 0091), for tests.
const Key feltSaveRoundKey = ValueKey<String>('feltSaveRound');

/// Records a NorgesFelt session (spec 0080): pick a group, then place each shot
/// on every hold and see the score, ending on a scorecard. The in-progress
/// round is saved after each change and can be [restored] (spec 0081). The
/// setup step's [metadata] and [weapon] (spec 0092) ride along on every
/// snapshot and the saved record.
class FeltRecordScreen extends ConsumerStatefulWidget {
  /// Creates the recorder, optionally resuming a saved [restored] round.
  const FeltRecordScreen({
    this.restored,
    this.metadata,
    this.weapon,
    this.competitionId,
    this.forcedGroup,
    super.key,
  });

  /// A saved round to resume into, or null to start fresh (spec 0081).
  final FeltSessionSnapshot? restored;

  /// The setup step's date/time and place (spec 0092), or null. A resumed
  /// round carries its own metadata in [restored].
  final SessionMetadata? metadata;

  /// The weapon chosen in the setup step (spec 0092), or null.
  final Weapon? weapon;

  /// The competition this round is shot for (spec 0140), or `null`.
  final String? competitionId;

  /// The competition's locked group (spec 0140): skips the group picker
  /// and hides the group switch.
  final FeltShooterGroup? forcedGroup;

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

  /// Whether a mouse hovers or a finger presses the hold picture — while it
  /// does, the page scroll is suspended so the pinch/pan reaches the
  /// recorder's InteractiveViewer whole (specs 0021/0128).
  bool _hoveringRecorder = false;
  int _pointersOnRecorder = 0;

  bool get _suspendScroll => _hoveringRecorder || _pointersOnRecorder > 0;

  void _updateGuard(VoidCallback change) {
    final before = _suspendScroll;
    change();
    if (_suspendScroll != before) setState(() {});
  }

  /// Wraps the recorder so hovering/pressing it suspends page scrolling.
  /// The [Listener] only observes pointers — it never joins the gesture
  /// arena — so taps, pinches and pans behave exactly as without it.
  Widget _scrollGuard(Widget recorder) => MouseRegion(
    onEnter: (_) => _updateGuard(() => _hoveringRecorder = true),
    onExit: (_) => _updateGuard(() => _hoveringRecorder = false),
    child: Listener(
      onPointerDown: (_) => _updateGuard(() => _pointersOnRecorder++),
      onPointerUp: (_) => _updateGuard(() {
        if (_pointersOnRecorder > 0) _pointersOnRecorder--;
      }),
      onPointerCancel: (_) => _updateGuard(() {
        if (_pointersOnRecorder > 0) _pointersOnRecorder--;
      }),
      child: recorder,
    ),
  );
  int _hold = 0;
  bool _done = false;
  late List<List<_Placed>> _shots;

  /// The round's id, minted **once** per recorder (spec 0091): however many
  /// times the shooter walks Fullfør → tilbake → Fullfør, the saved record
  /// keeps one identity and the history upsert keeps one copy.
  late final String _roundId;

  /// Guards the save button against double-taps while the save runs.
  bool _saving = false;

  /// The round's metadata (spec 0092): the chosen date/time, place and
  /// weapon — from the setup step, or from the restored snapshot on resume.
  DateTime? _capturedAt;
  String? _placeLabel;
  double? _latitude;
  double? _longitude;
  String? _weaponName;

  @override
  void initState() {
    super.initState();
    _roundId = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final restored = widget.restored;
    if (restored != null) {
      _group = restored.group;
      _hold = restored.currentHold;
      _capturedAt = restored.capturedAt;
      _placeLabel = restored.placeLabel;
      _latitude = restored.latitude;
      _longitude = restored.longitude;
      _weaponName = restored.weaponName;
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
      final metadata = widget.metadata;
      _capturedAt = metadata?.capturedAt;
      _placeLabel = metadata?.place?.label;
      _latitude = metadata?.place?.latitude;
      _longitude = metadata?.place?.longitude;
      _weaponName = widget.weapon?.name;
      // The group is a stable property of the shooter: start on hold 1 with
      // the remembered group and skip the picker (spec 0099). A competition
      // locks its own group (spec 0140).
      _group = widget.forcedGroup ?? ref.read(initialFeltGroupProvider);
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
    capturedAt: _capturedAt,
    placeLabel: _placeLabel,
    latitude: _latitude,
    longitude: _longitude,
    weaponName: _weaponName,
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
  /// worth resuming (no group or no shots). A **finished** round stays in the
  /// store until it is explicitly saved (spec 0091), so an unsaved round is
  /// never lost. Best-effort (spec 0081).
  void _persist() {
    final store = ref.read(feltSessionStoreProvider);
    final write = (_group == null || _totalShots == 0)
        ? store.clear()
        : store.save(_snapshot());
    unawaited(write.catchError((Object _) {}));
  }

  void _pickGroup(FeltShooterGroup group) {
    setState(() => _group = group);
    // Remember the choice for the next round (spec 0099); best-effort.
    unawaited(
      ref.read(feltGroupStoreProvider).save(group).catchError((Object _) {}),
    );
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

  /// Finishes the round: shows the scorecard. Nothing is saved to history
  /// here — the save is the scorecard's explicit «Lagre økt» button (spec
  /// 0091), so walking Fullfør → tilbake → Fullfør can never duplicate.
  void _finish() {
    setState(() => _done = true);
    _persist();
  }

  /// Saves the finished round — exactly once (spec 0091): the record keeps
  /// the recorder's stable [_roundId] and the history save upserts by id.
  /// Uploads best-effort (spec 0083), clears the in-progress store and pops
  /// back to the course page with a confirmation.
  Future<void> _save() async {
    if (_saving || _totalShots == 0) return;
    setState(() => _saving = true);
    // Captured before the awaits so no BuildContext is used across the gaps.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    // The record's capturedAt is the setup step's chosen date (spec 0092);
    // a round without one (pre-0092 resume) falls back to the save moment.
    final record = FeltSessionRecord(
      id: _roundId,
      capturedAt: _capturedAt ?? DateTime.now(),
      session: _snapshot(),
      competitionId: widget.competitionId,
    );
    await saveFeltRound(ref, record).catchError((Object _) {});
    unawaited(
      ref
          .read(feltSyncProvider.notifier)
          .uploadOne(record)
          .catchError((Object _) {}),
    );
    await ref.read(feltSessionStoreProvider).clear().catchError((Object _) {});
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(const SnackBar(content: Text('Økta er lagret.')));
    unawaited(navigator.maybePop());
  }

  /// Whether the finished round is a new personal best (spec 0101): compared
  /// against the shooter's other felt rounds *of the same group* — local and
  /// synced merged as «Mine økter» does — with this round's own id excluded
  /// (a re-save of the same round must not beat itself). A manual record
  /// baseline for the group counts as one more prior result (spec 0102).
  bool _isPersonalBest() {
    final tally = _session;
    final rounds = mergeFeltRounds(
      local: ref.watch(feltHistoryProvider).value ?? const [],
      synced: ref.watch(feltSyncedSessionsProvider).value ?? const [],
    );
    final baseline = ref.watch(
      personalRecordsProvider,
    )[feltRecordKey(tally.group)];
    return isNewPersonalBest(
      result: (points: tally.points, inner: tally.inner),
      prior: [
        ?baseline,
        for (final round in rounds)
          if (round.id != _roundId && round.session.group == tally.group)
            (points: round.tally.points, inner: round.tally.inner),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_group == null) {
      return _GroupPicker(onPick: _pickGroup);
    }
    if (_done) {
      return Scaffold(
        appBar: FrostedAppBar(
          title: const Text('Resultat'),
          leading: BackButton(onPressed: () => setState(() => _done = false)),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: FeltScorecard(
                  session: _session,
                  personalBest: _isPersonalBest(),
                  holds: _snapshot().holds,
                ),
              ),
              // The explicit save (spec 0091): the round only reaches "Mine
              // økter" through this button — deliberate, and exactly once.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: feltSaveRoundKey,
                    onPressed: _saving ? null : () => unawaited(_save()),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Lagre økt'),
                  ),
                ),
              ),
            ],
          ),
        ),
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
      appBar: FrostedAppBar(
        title: Text('Hold ${hold.number}/${norgesfelt2026.length}'),
        actions: [
          // A remembered group skipped the picker (spec 0099); offer a way
          // back while a change is still safe (no shots placed yet). A
          // competition's group is locked (spec 0140) — no way back.
          if (_totalShots == 0 && widget.forcedGroup == null)
            TextButton.icon(
              key: feltChangeGroupKey,
              onPressed: () => setState(() => _group = null),
              icon: const Icon(Icons.group_outlined),
              label: Text(_group!.label),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(12),
              physics: _suspendScroll
                  ? const NeverScrollableScrollPhysics()
                  : null,
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
                _scrollGuard(
                  _HoldRecorder(
                    key: feltHoldRecorderKey,
                    art: art,
                    shots: placed,
                    onPlace: (p) => _place(art, p),
                  ),
                ),
                const SizedBox(height: 8),
                // Inner hits give no points (spec 0085): the hold line shows
                // the treff + figur breakdown, then the inner count as the
                // ringed X the ring programs use for inner tens (spec 0023).
                KeyedSubtree(
                  key: feltHoldPointsKey,
                  child: innerTenScoreText(
                    context: context,
                    lead:
                        'Treff ${tally.treff} · Figur ${tally.figures}'
                        '  =  ${tally.points} poeng',
                    innerTens: tally.inner,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                KeyedSubtree(
                  key: feltTotalPointsKey,
                  child: innerTenScoreText(
                    context: context,
                    lead: 'Totalt så langt: ${_session.points} poeng',
                    innerTens: _session.inner,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
                        onPressed: _finish,
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
    appBar: const FrostedAppBar(title: Text('Skyt NorgesFelt-løypa')),
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
              for (final g in FeltShooterGroup.offered)
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
class _HoldRecorder extends StatefulWidget {
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
  State<_HoldRecorder> createState() => _HoldRecorderState();
}

class _HoldRecorderState extends State<_HoldRecorder> {
  // The ring target's zoom range (spec 0125): shared feel across targets.
  static const double _minScale = 1;
  static const double _maxScale = 6;

  final TransformationController _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  double get _currentScale => _transform.value.getMaxScaleOnAxis();

  /// Sets a centred zoom level, clamped to [_minScale]..[_maxScale]. The
  /// hold picture is not square, so the centre translate is per axis:
  /// scaling by `s` about `c` gives `x' = s·x + c·(1 - s)`.
  void _zoomTo(double target, Size viewport) {
    final clamped = target.clamp(_minScale, _maxScale);
    _transform.value = Matrix4.identity()
      ..setEntry(0, 0, clamped)
      ..setEntry(1, 1, clamped)
      ..setEntry(0, 3, (viewport.width / 2) * (1 - clamped))
      ..setEntry(1, 3, (viewport.height / 2) * (1 - clamped));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final art = widget.art;
      final w = constraints.maxWidth;
      final scale = w / art.size.width;
      final h = art.size.height * scale;
      final viewport = Size(w, h);
      return SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: <Widget>[
            // Zoom and pan like the ring target (spec 0125): the tap
            // gesture sits INSIDE the viewer, so its localPosition is
            // already in picture space and the fraction maths is
            // untouched by the zoom.
            InteractiveViewer(
              transformationController: _transform,
              minScale: _minScale,
              maxScale: _maxScale,
              trackpadScrollCausesScale: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Tap-UP, not tap-down (spec 0128): tap-down fires before
                // the arena knows a second finger is coming, so the first
                // finger of every pinch planted a shot.
                onTapUp: (d) => widget.onPlace(
                  Offset(
                    d.localPosition.dx / scale,
                    d.localPosition.dy / scale,
                  ),
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
                            child: CustomPaint(
                              painter: FeltHoldArtPainter(art),
                            ),
                          ),
                          for (final s in widget.shots)
                            Positioned(
                              left:
                                  s.pos.dx * scale -
                                  FeltShotMarker.diameter / 2,
                              top:
                                  s.pos.dy * scale -
                                  FeltShotMarker.diameter / 2,
                              child: FeltShotMarker(
                                hit: s.shot.isHit,
                                inner: s.shot.inner,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: ZoomControls(
                onZoomIn: () => _zoomTo(_currentScale * 1.6, viewport),
                onZoomOut: () => _zoomTo(_currentScale / 1.6, viewport),
                onReset: () => _zoomTo(1, viewport),
              ),
            ),
          ],
        ),
      );
    },
  );
}
