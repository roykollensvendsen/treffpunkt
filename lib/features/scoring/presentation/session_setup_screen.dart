// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/scoring/domain/place.dart';
import 'package:treffpunkt/features/scoring/domain/program_definition.dart';
import 'package:treffpunkt/features/scoring/domain/session_metadata.dart';
import 'package:treffpunkt/features/scoring/presentation/date_time_merge.dart';
import 'package:treffpunkt/features/scoring/presentation/series_screen.dart';
import 'package:treffpunkt/features/scoring/presentation/session_providers.dart';

/// Key for the confirm ("start shooting") action, used by tests.
const Key sessionConfirmKey = ValueKey<String>('sessionConfirm');

/// Key for the "use my location" button, used by tests.
const Key useMyLocationKey = ValueKey<String>('useMyLocation');

/// Key for the place text field, used by tests.
const Key placeFieldKey = ValueKey<String>('placeField');

/// Key for the date / time field, used by tests.
const Key dateTimeKey = ValueKey<String>('dateTime');

/// Captures when and where a session is shot, before shooting starts.
///
/// Shown after the program is picked (spec 0008): the date and time default to
/// now and are editable, and the place is filled from device location ("Bruk
/// min posisjon") or typed by hand. Confirming builds a [SessionMetadata] and
/// opens the shooting screen with it attached. Manual entry is a full
/// alternative — the shooter can proceed with no location, a typed place, or a
/// GPS fix.
class SessionSetupScreen extends ConsumerStatefulWidget {
  /// Creates the setup screen for [program], seeding the date/time from [now]
  /// (defaults to the wall clock; injected in tests).
  SessionSetupScreen({required this.program, DateTime? now, super.key})
    : now = now ?? DateTime.now();

  /// The program about to be shot.
  final ProgramDefinition program;

  /// The moment used to seed the editable date and time.
  final DateTime now;

  @override
  ConsumerState<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends ConsumerState<SessionSetupScreen> {
  late DateTime _capturedAt = widget.now;
  final TextEditingController _placeController = TextEditingController();
  double? _latitude;
  double? _longitude;
  bool _locating = false;

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
    final fix = await ref.read(locationServiceProvider).currentLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (fix == null) return;
      _latitude = fix.latitude;
      _longitude = fix.longitude;
      if (_placeController.text.trim().isEmpty) {
        _placeController.text =
            '${fix.latitude.toStringAsFixed(4)}, '
            '${fix.longitude.toStringAsFixed(4)}';
      }
    });
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
    final metadata = SessionMetadata(
      capturedAt: _capturedAt,
      place: _buildPlace(),
    );
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SeriesScreen(
            program: widget.program,
            metadata: metadata,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.program.name)),
      body: SafeArea(
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
