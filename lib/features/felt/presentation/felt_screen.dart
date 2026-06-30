// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:treffpunkt/features/felt/domain/felt_session.dart';

/// Key for the running-total header (spec 0068), used by tests.
const Key feltTotalKey = ValueKey<String>('feltTotal');

/// Key for the hits value on hold [index].
Key feltHoldHitsKey(int index) => ValueKey<String>('feltHits-$index');

/// Key for the inner-hits value on hold [index].
Key feltHoldInnerKey(int index) => ValueKey<String>('feltInner-$index');

/// Key for the "+1 hit" button on hold [index].
Key feltHitsPlusKey(int index) => ValueKey<String>('feltHitsPlus-$index');

/// Key for the "−1 hit" button on hold [index].
Key feltHitsMinusKey(int index) => ValueKey<String>('feltHitsMinus-$index');

/// Key for the "+1 inner hit" button on hold [index].
Key feltInnerPlusKey(int index) => ValueKey<String>('feltInnerPlus-$index');

/// Key for the "−1 inner hit" button on hold [index].
Key feltInnerMinusKey(int index) => ValueKey<String>('feltInnerMinus-$index');

/// Records a field-shooting session (spec 0068): for each of the course's holds
/// you count the hits and inner hits, and the total updates live.
class FeltScreen extends StatefulWidget {
  /// Creates the recorder for [feltClass].
  const FeltScreen({required this.feltClass, super.key});

  /// The field class being shot.
  final FeltClass feltClass;

  @override
  State<FeltScreen> createState() => _FeltScreenState();
}

class _FeltScreenState extends State<FeltScreen> {
  late FeltSession _session = FeltSession.start(widget.feltClass);

  void _setHold(int index, {required int hits, required int innerHits}) {
    setState(() {
      _session = _session.withHold(index, hits: hits, innerHits: innerHits);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Feltpistol — ${widget.feltClass.label}')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: <Widget>[
                Card(
                  margin: const EdgeInsets.all(12),
                  color: theme.colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      'Totalt: ${_session.totalHits} / ${_session.maxHits} '
                      'treff  ·  ${_session.totalInnerHits} innertreff',
                      key: feltTotalKey,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _session.holdCount,
                    itemBuilder: (context, i) => _HoldRow(
                      index: i,
                      hold: _session.holds[i],
                      onChange: _setHold,
                    ),
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

class _HoldRow extends StatelessWidget {
  const _HoldRow({
    required this.index,
    required this.hold,
    required this.onChange,
  });

  final int index;
  final FeltHold hold;
  final void Function(int index, {required int hits, required int innerHits})
  onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 64,
              child: Text(
                'Hold ${index + 1}',
                style: theme.textTheme.titleSmall,
              ),
            ),
            Expanded(
              child: _Counter(
                label: 'Treff',
                value: hold.hits,
                valueKey: feltHoldHitsKey(index),
                minusKey: feltHitsMinusKey(index),
                plusKey: feltHitsPlusKey(index),
                onMinus: () => onChange(
                  index,
                  hits: hold.hits - 1,
                  innerHits: hold.innerHits,
                ),
                onPlus: () => onChange(
                  index,
                  hits: hold.hits + 1,
                  innerHits: hold.innerHits,
                ),
              ),
            ),
            Expanded(
              child: _Counter(
                label: 'Inner',
                value: hold.innerHits,
                valueKey: feltHoldInnerKey(index),
                minusKey: feltInnerMinusKey(index),
                plusKey: feltInnerPlusKey(index),
                onMinus: () => onChange(
                  index,
                  hits: hold.hits,
                  innerHits: hold.innerHits - 1,
                ),
                onPlus: () => onChange(
                  index,
                  hits: hold.hits,
                  innerHits: hold.innerHits + 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.label,
    required this.value,
    required this.valueKey,
    required this.minusKey,
    required this.plusKey,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final int value;
  final Key valueKey;
  final Key minusKey;
  final Key plusKey;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: theme.textTheme.labelSmall),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton(
              key: minusKey,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: onMinus,
            ),
            SizedBox(
              width: 24,
              child: Text(
                '$value',
                key: valueKey,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: plusKey,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_circle_outline),
              onPressed: onPlus,
            ),
          ],
        ),
      ],
    );
  }
}
