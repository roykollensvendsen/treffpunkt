// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for the reusable weapon picker: it lists only weapons permitted
// for the program, reports a selection, and adds a weapon from a class.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/features/scoring/domain/program_catalogue.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/weapons/data/weapons_store.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';
import 'package:treffpunkt/features/weapons/domain/weapon_class.dart';
import 'package:treffpunkt/features/weapons/presentation/weapon_picker.dart';

const ProgramDefinition _program = ProgramDefinition(
  name: '25 m',
  discipline: Discipline.pistol,
  weaponClasses: <String>['.22 LR'],
  stages: <StageDefinition>[],
);

final Weapon _permitted = Weapon.fromClass(
  const WeaponClass(
    discipline: Discipline.pistol,
    caliberLabel: '.22 LR',
    label: '.22 LR',
  ),
  id: 'p1',
  name: 'Walther',
);

final Weapon _forbidden = Weapon.fromClass(
  const WeaponClass(
    discipline: Discipline.pistol,
    caliberLabel: '7.62–9.65 mm',
    label: 'Centre-fire 7.62–9.65 mm',
  ),
  id: 'f1',
  name: 'Pardini',
);

Widget _app(
  ProviderContainer container, {
  ValueChanged<Weapon>? onSelected,
  ProgramDefinition program = _program,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: WeaponPicker(program: program, onSelected: onSelected),
      ),
    ),
  );
}

void main() {
  testWidgets('lists only the weapons permitted for the program', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(weaponsProvider.notifier)
      ..add(_permitted)
      ..add(_forbidden);

    await tester.pumpWidget(_app(container));

    expect(find.text('Walther'), findsOneWidget);
    expect(find.text('Pardini'), findsNothing);
  });

  testWidgets('tapping a weapon reports the selection', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(weaponsProvider.notifier).add(_permitted);
    Weapon? reported;

    await tester.pumpWidget(
      _app(container, onSelected: (weapon) => reported = weapon),
    );
    await tester.tap(find.text('Walther'));
    await tester.pump();

    expect(reported, _permitted);
    expect(container.read(selectedWeaponProvider), _permitted);
  });

  testWidgets('adds a weapon from a catalogue class', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));

    await tester.tap(find.byKey(addWeaponKey));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(weaponNameFieldKey), 'New gun');
    await tester.tap(find.byKey(saveWeaponKey));
    await tester.pumpAndSettle();

    expect(find.text('New gun'), findsOneWidget);
    expect(container.read(weaponsProvider), hasLength(1));

    await tester.tap(find.text('New gun'));
    await tester.pump();
    expect(container.read(selectedWeaponProvider)?.name, 'New gun');
  });

  testWidgets(
    'offers only the matching-discipline class for the air-pistol program',
    (tester) async {
      // The picker filters the catalogue by **both** discipline and label, so
      // the add list for the air-PISTOL program offers only the air-pistol
      // class. (Air rifle once shared the 'Air 4.5 mm' label across disciplines
      // and exercised the discipline tie-break; it was removed with the
      // air-rifle program, so the label is no longer shared — but the
      // discipline filter still holds.)
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _app(container, program: ProgramCatalogue.airPistol10m),
      );

      await tester.tap(find.byKey(addWeaponKey));
      await tester.pumpAndSettle();

      // Open the class dropdown and collect the distinct classes it offers.
      // Exactly one — the air-pistol class — must be offered.
      await tester.tap(find.byType(DropdownButtonFormField<WeaponClass>));
      await tester.pumpAndSettle();
      final offered = tester
          .widgetList<DropdownMenuItem<WeaponClass>>(
            find.byType(DropdownMenuItem<WeaponClass>),
          )
          .map((item) => item.value)
          .whereType<WeaponClass>()
          .toSet();
      expect(offered, hasLength(1));
      expect(offered.single.discipline, Discipline.pistol);
      expect(offered.single.label, 'Air 4.5 mm');

      // And the weapon actually produced is a pistol-discipline weapon.
      await tester.tap(find.text('Air 4.5 mm').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(weaponNameFieldKey), 'My air pistol');
      await tester.tap(find.byKey(saveWeaponKey));
      await tester.pumpAndSettle();

      final weapons = container.read(weaponsProvider);
      expect(weapons, hasLength(1));
      expect(weapons.single.discipline, Discipline.pistol);
      expect(weapons.single.classLabel, 'Air 4.5 mm');
    },
  );

  testWidgets('saving with an empty name keeps the dialog open and adds none', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));

    await tester.tap(find.byKey(addWeaponKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(saveWeaponKey));
    await tester.pumpAndSettle();

    // Dialog stays open (its name field is still on screen) and nothing added.
    expect(find.byKey(weaponNameFieldKey), findsOneWidget);
    expect(container.read(weaponsProvider), isEmpty);
  });
}
