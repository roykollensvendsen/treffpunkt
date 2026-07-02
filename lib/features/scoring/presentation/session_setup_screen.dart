// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/data/location_service.dart';
import 'package:treffpunkt/features/scoring/domain/place.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/session_metadata.dart';
import 'package:treffpunkt/features/scoring/presentation/date_time_merge.dart';
import 'package:treffpunkt/features/scoring/presentation/series_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';
import 'package:treffpunkt/features/weapons/domain/weapon.dart';
import 'package:treffpunkt/features/weapons/presentation/weapon_picker.dart';

/// Key for the confirm ("start shooting") action, used by tests.
const Key sessionConfirmKey = ValueKey<String>('sessionConfirm');

/// Key for the "use my location" button, used by tests.
const Key useMyLocationKey = ValueKey<String>('useMyLocation');

/// Key for the place text field, used by tests.
const Key placeFieldKey = ValueKey<String>('placeField');

/// Key for the date / time field, used by tests.
const Key dateTimeKey = ValueKey<String>('dateTime');

/// Key for the "open settings" action shown when location is permanently
/// denied, used by tests.
const Key openLocationSettingsKey = ValueKey<String>('openLocationSettings');

/// Captures when and where a session is shot, before shooting starts.
///
/// Shown after the program is picked (spec 0008): the date and time default to
/// now and are editable, and the place is filled from device location ("Bruk
/// min posisjon") or typed by hand. Confirming builds a [SessionMetadata] and
/// opens the shooting screen with it attached. Manual entry is a full
/// alternative — the shooter can proceed with no location, a typed place, or a
/// GPS fix.
///
/// The form itself is the shared [SessionSetupForm] (spec 0092): this screen
/// is the ring wrapper, the felt flow wraps the same form.
class SessionSetupScreen extends StatelessWidget {
  /// Creates the setup screen for [program], seeding the date/time from [now]
  /// (defaults to the wall clock; injected in tests).
  SessionSetupScreen({
    required this.program,
    DateTime? now,
    this.competitionId,
    super.key,
  }) : now = now ?? DateTime.now();

  /// The program about to be shot.
  final ProgramDefinition program;

  /// The competition this session is shot for (spec 0012), or `null`.
  final String? competitionId;

  /// The moment used to seed the editable date and time.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(program.name)),
      body: SessionSetupForm(
        now: now,
        discipline: program.discipline,
        classLabels: program.weaponClasses,
        onConfirm: (metadata, weapon) => unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SeriesScreen(
                program: program,
                metadata: metadata,
                weapon: weapon,
                competitionId: competitionId,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one session-setup form (specs 0008/0092): date and time, place (typed
/// or from device location) and the weapon, ending in a confirm button that
/// reports the built [SessionMetadata] and chosen [Weapon] to [onConfirm].
/// The ring and felt flows both render exactly this form.
class SessionSetupForm extends ConsumerStatefulWidget {
  /// Creates the form, seeding the editable date/time from [now].
  const SessionSetupForm({
    required this.now,
    required this.discipline,
    required this.onConfirm,
    this.classLabels = const <String>[],
    super.key,
  });

  /// The moment used to seed the editable date and time.
  final DateTime now;

  /// The discipline whose weapons are offered.
  final Discipline discipline;

  /// The permitted weapon-class labels; empty offers every class of
  /// [discipline].
  final List<String> classLabels;

  /// Called on confirm with the metadata and the chosen weapon (or null).
  final void Function(SessionMetadata metadata, Weapon? weapon) onConfirm;

  @override
  ConsumerState<SessionSetupForm> createState() => _SessionSetupFormState();
}

class _SessionSetupFormState extends ConsumerState<SessionSetupForm> {
  late DateTime _capturedAt = widget.now;
  final TextEditingController _placeController = TextEditingController();
  double? _latitude;
  double? _longitude;
  bool _locating = false;
  Weapon? _weapon;

  @override
  void dispose() {
    _placeController.dispose();
    super.dispose();
  }

  String get _formattedDateTime {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${_capturedAt.year}-${two(_capturedAt.month)}-'
        '${two(_capturedAt.day)} '
        '${two(_capturedAt.hour)}:${two(_capturedAt.minute)}';
  }

  Future<void> _editDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _capturedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(_capturedAt.year + 1),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_capturedAt),
    );
    if (!mounted) return;
    setState(() {
      _capturedAt = mergeDateTime(
        _capturedAt,
        date: date,
        hour: time?.hour,
        minute: time?.minute,
      );
    });
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final result = await ref.read(locationServiceProvider).currentLocation();
    if (!mounted) return;
    if (result case LocationFix(:final location)) {
      _latitude = location.latitude;
      _longitude = location.longitude;
      // Name the place from the coordinates; fall back to the coordinates
      // themselves if the lookup can't resolve a name (spec 0076).
      final name = await ref
          .read(geocoderProvider)
          .reverseGeocode(location.latitude, location.longitude);
      if (!mounted) return;
      final coordinates =
          '${location.latitude.toStringAsFixed(4)}, '
          '${location.longitude.toStringAsFixed(4)}';
      setState(() {
        _locating = false;
        if (_placeController.text.trim().isEmpty) {
          _placeController.text = name ?? coordinates;
        }
      });
    } else {
      setState(() => _locating = false);
    }
    // Only a permanent denial is fixable from the OS settings; every other
    // non-fix outcome degrades silently to manual entry, exactly as before.
    if (result is LocationDeniedForever) _offerOpenSettings();
  }

  /// Prompts the shooter to open the OS settings, where a permanently-denied
  /// location permission is the only thing that can be re-granted.
  void _offerOpenSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Posisjon er avslått. Slå den på i innstillingene, '
          'eller skriv inn stedet selv.',
        ),
        action: SnackBarAction(
          key: openLocationSettingsKey,
          label: 'Åpne innstillinger',
          onPressed: () {
            unawaited(ref.read(locationServiceProvider).openLocationSettings());
          },
        ),
      ),
    );
  }

  Place? _buildPlace() {
    final label = _placeController.text.trim();
    if (label.isEmpty && _latitude == null) return null;
    return Place(
      label: label,
      latitude: _latitude,
      longitude: _longitude,
    );
  }

  void _confirm() {
    widget.onConfirm(
      SessionMetadata(capturedAt: _capturedAt, place: _buildPlace()),
      _weapon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Når og hvor',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _DateTimeField(
                  value: _formattedDateTime,
                  onTap: _editDateTime,
                ),
                const SizedBox(height: 16),
                TextField(
                  key: placeFieldKey,
                  controller: _placeController,
                  decoration: const InputDecoration(
                    labelText: 'Sted',
                    hintText: 'Skytebane, bane eller lag',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: useMyLocationKey,
                    onPressed: _locating ? null : _useMyLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Bruk min posisjon'),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Våpen',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                WeaponPicker.forClasses(
                  discipline: widget.discipline,
                  classLabels: widget.classLabels,
                  onSelected: (weapon) => setState(() => _weapon = weapon),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: sessionConfirmKey,
                  onPressed: _confirm,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start skyting'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: dateTimeKey,
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Dato og tid',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.edit_calendar),
        ),
        child: Text(value),
      ),
    );
  }
}
