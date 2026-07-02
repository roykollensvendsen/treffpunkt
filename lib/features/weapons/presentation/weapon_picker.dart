// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/weapons/data/weapons_store.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';
import 'package:treffpunkt/features/weapons/domain/weapon_catalogue.dart';
import 'package:treffpunkt/features/weapons/domain/weapon_class.dart';

/// Key for the "add weapon" control.
const Key addWeaponKey = ValueKey<String>('addWeapon');

/// Key for the new-weapon name field in the add dialog.
const Key weaponNameFieldKey = ValueKey<String>('weaponNameField');

/// Key for the save button in the add dialog.
const Key saveWeaponKey = ValueKey<String>('saveWeapon');

/// Lets the shooter pick the weapon for a session.
///
/// Lists the shooter's personal weapons of the permitted classes, highlights
/// the chosen one, and offers an "add" control that creates a new weapon from
/// a permitted catalogue class. The selection is written to
/// `selectedWeaponProvider` and reported via [onSelected].
class WeaponPicker extends ConsumerWidget {
  /// Creates a picker for [program]'s permitted classes.
  WeaponPicker({required ProgramDefinition program, this.onSelected, super.key})
    : discipline = program.discipline,
      classLabels = program.weaponClasses;

  /// Creates a picker for the given [discipline] and [classLabels] directly
  /// (spec 0092) — an empty [classLabels] permits every class of the
  /// discipline. Used by flows without a `ProgramDefinition` (felt).
  const WeaponPicker.forClasses({
    required this.discipline,
    this.classLabels = const <String>[],
    this.onSelected,
    super.key,
  });

  /// The discipline whose weapons are offered.
  final Discipline discipline;

  /// The permitted class labels; empty means every class of [discipline].
  final List<String> classLabels;

  /// Called with the weapon when the shooter selects one.
  final ValueChanged<Weapon>? onSelected;

  /// The permitted catalogue classes, by discipline and label.
  ///
  /// Filters by **both** discipline and label: a label such as `'Air 4.5 mm'`
  /// could be shared across disciplines (it once was, by the now-removed
  /// air-rifle class), so matching on label alone could offer a
  /// wrong-discipline class to a program.
  List<WeaponClass> get _permittedClasses => WeaponCatalogue.all
      .where(
        (weaponClass) =>
            weaponClass.discipline == discipline &&
            (classLabels.isEmpty || classLabels.contains(weaponClass.label)),
      )
      .toList();

  /// Whether [weapon] may be offered: its class is one of the permitted ones.
  bool _isPermitted(Weapon weapon) =>
      weapon.discipline == discipline &&
      (classLabels.isEmpty || classLabels.contains(weapon.classLabel));

  void _select(WidgetRef ref, Weapon weapon) {
    ref.read(selectedWeaponProvider.notifier).select(weapon);
    onSelected?.call(weapon);
  }

  Future<void> _addWeapon(BuildContext context, WidgetRef ref) async {
    final classes = _permittedClasses;
    if (classes.isEmpty) return;
    final weapon = await showDialog<Weapon>(
      context: context,
      builder: (_) => _AddWeaponDialog(classes: classes),
    );
    if (weapon == null) return;
    ref.read(weaponsProvider.notifier).add(weapon);
    _select(ref, weapon);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedWeaponProvider);
    final permitted = ref.watch(weaponsProvider).where(_isPermitted).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (permitted.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Ingen våpen for dette programmet ennå.'),
          )
        else
          for (final weapon in permitted)
            ListTile(
              key: ValueKey<String>('weapon-${weapon.id}'),
              title: Text(weapon.name),
              subtitle: Text(weapon.classLabel),
              trailing: weapon == selected
                  ? const Icon(Icons.check_circle)
                  : null,
              selected: weapon == selected,
              onTap: () => _select(ref, weapon),
            ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: addWeaponKey,
            icon: const Icon(Icons.add),
            label: const Text('Legg til våpen'),
            onPressed: () => _addWeapon(context, ref),
          ),
        ),
      ],
    );
  }
}

/// Dialog that creates a new weapon from a permitted catalogue class.
class _AddWeaponDialog extends StatefulWidget {
  const _AddWeaponDialog({required this.classes});

  final List<WeaponClass> classes;

  @override
  State<_AddWeaponDialog> createState() => _AddWeaponDialogState();
}

class _AddWeaponDialogState extends State<_AddWeaponDialog> {
  late final TextEditingController _name = TextEditingController();
  late WeaponClass _selectedClass = widget.classes.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final weapon = Weapon.fromClass(
      _selectedClass,
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
    );
    Navigator.of(context).pop(weapon);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Legg til våpen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: weaponNameFieldKey,
            controller: _name,
            decoration: const InputDecoration(labelText: 'Navn'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<WeaponClass>(
            initialValue: _selectedClass,
            decoration: const InputDecoration(labelText: 'Klasse'),
            items: <DropdownMenuItem<WeaponClass>>[
              for (final weaponClass in widget.classes)
                DropdownMenuItem<WeaponClass>(
                  value: weaponClass,
                  child: Text(weaponClass.label),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _selectedClass = value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Avbryt'),
        ),
        FilledButton(
          key: saveWeaponKey,
          onPressed: _save,
          child: const Text('Lagre'),
        ),
      ],
    );
  }
}
