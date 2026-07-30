// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// The pistol type a dry-fire bout was practised with (spec 0165).
///
/// A small, fixed set aligned to the catalogue's pistol classes (spec 0007):
/// Luftpistol → air 4.5 mm, Finpistol → .22 LR, Grovpistol → centre-fire. It is
/// a standalone enum, not a reference to `WeaponCatalogue`, so the pure scoring
/// domain gains no dependency on the weapons feature (ADR-0014 covers the
/// per-named-gun model, which dry-fire deliberately does not use — a type keeps
/// the entry a pure value and works without any registered guns). A unit test
/// guards that these three stay in step with the catalogue's pistol classes.
///
/// Each value carries a Norwegian [label] for display and a stable [wireName]
/// for storage that never changes even if the label does.
enum DryFireWeapon {
  /// Air pistol (4.5 mm), 10 m.
  luftpistol('Luftpistol', 'luftpistol'),

  /// Smallbore (.22 LR) sport pistol — finpistol.
  finpistol('Finpistol', 'finpistol'),

  /// Centre-fire pistol — grovpistol.
  grovpistol('Grovpistol', 'grovpistol');

  const DryFireWeapon(this.label, this.wireName);

  /// The human-readable name shown in the UI.
  final String label;

  /// The stable storage key; the inverse of [DryFireWeapon.fromWireName].
  final String wireName;

  /// The weapon whose [wireName] is [name], or `null` when [name] is `null` or
  /// unknown.
  ///
  /// Unlike `DryFireDiscipline.fromWireName`, an unknown name **degrades to
  /// `null`** rather than throwing: the weapon is an optional tag with a safe
  /// fallback (no weapon), and the list store is all-or-nothing — a single
  /// throwing entry would empty the whole persisted log. So an unreadable value
  /// costs one tag, never the log.
  static DryFireWeapon? fromWireName(String? name) {
    if (name == null) return null;
    for (final weapon in DryFireWeapon.values) {
      if (weapon.wireName == name) return weapon;
    }
    return null;
  }
}
