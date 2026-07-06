// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// The shared skeleton behind the app's `shared_preferences`-backed stores
/// (ADR-0016): one JSON string per key, (de)serialization injected as
/// `toJson`/`fromJson` closures, and a defensive read that treats anything
/// unreadable as never-saved so a broken value can never take the app down.
///
/// Concrete feature stores (session recording, pending uploads, felt history,
/// weapons, personal records, …) keep their own domain-facing interface and
/// in-memory fake, and delegate their SharedPreferences implementation to one
/// of these classes. Tests drive them with
/// `SharedPreferences.setMockInitialValues`, so no real platform storage is
/// touched.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A single JSON value stored under one SharedPreferences key.
///
/// [save] encodes the value through [toJson] and writes it as one JSON
/// string; [load] reads it back through [fromJson]. Anything unreadable — a
/// missing key, malformed JSON, a wrong shape (a failing cast or a throwing
/// [fromJson]) — loads as `null`, indistinguishable from never-saved.
final class PrefsJsonStore<T extends Object> {
  /// Creates a store for one value under [key], reading and writing through
  /// [SharedPreferences] with the injected [toJson]/[fromJson] codecs.
  PrefsJsonStore(
    this._prefs, {
    required this.key,
    required this.toJson,
    required this.fromJson,
  });

  final SharedPreferences _prefs;

  /// The SharedPreferences key the value lives under.
  final String key;

  /// Encodes a value into a JSON-encodable object.
  final Object? Function(T value) toJson;

  /// Rebuilds the value from decoded JSON produced by [toJson]; casts and
  /// throws freely — [load] treats any throw as an unreadable store.
  final T Function(Object? json) fromJson;

  /// Persists [value], replacing any previously saved one.
  Future<void> save(T value) async {
    await _prefs.setString(key, jsonEncode(toJson(value)));
  }

  /// The saved value, or `null` when none is stored or the stored one is
  /// unreadable.
  Future<T?> load() async {
    final stored = _prefs.getString(key);
    if (stored == null) return null;
    try {
      return fromJson(jsonDecode(stored));
    } on Object {
      return null;
    }
  }

  /// Removes the saved value, if any.
  Future<void> clear() async {
    await _prefs.remove(key);
  }
}

/// A list of values stored as one JSON array under one SharedPreferences
/// key, with the per-item codecs injected as [toJson]/[fromJson].
///
/// [save] replaces the whole list; [load] reads it back. Anything unreadable
/// — a missing key, malformed JSON, a non-array value, or any item that fails
/// to decode — loads as the empty list, so a broken store never throws and
/// never yields a silently truncated list.
final class PrefsJsonListStore<T> {
  /// Creates a store for a list under [key], reading and writing through
  /// [SharedPreferences] with the injected per-item [toJson]/[fromJson]
  /// codecs.
  PrefsJsonListStore(
    this._prefs, {
    required this.key,
    required this.toJson,
    required this.fromJson,
  });

  final SharedPreferences _prefs;

  /// The SharedPreferences key the list lives under.
  final String key;

  /// Encodes one item into a JSON-encodable object.
  final Object? Function(T item) toJson;

  /// Rebuilds one item from decoded JSON produced by [toJson]; casts and
  /// throws freely — [load] treats any throw as an unreadable store.
  final T Function(Object? json) fromJson;

  /// Persists [items] as the whole stored list, replacing any previous one.
  Future<void> save(List<T> items) async {
    await _prefs.setString(
      key,
      jsonEncode(<Object?>[for (final item in items) toJson(item)]),
    );
  }

  /// The saved items in stored order, or an empty list when none are stored
  /// or the stored value is unreadable.
  Future<List<T>> load() async {
    final stored = _prefs.getString(key);
    if (stored == null) return const [];
    try {
      final list = jsonDecode(stored) as List<dynamic>;
      return <T>[for (final item in list) fromJson(item)];
    } on Object {
      return const [];
    }
  }
}
