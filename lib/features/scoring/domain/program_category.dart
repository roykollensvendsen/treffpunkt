// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// The four top-level categories of the program picker (spec 0084).
///
/// This models the picker taxonomy the NSF domain expert sketched — not the
/// ring catalogue: [mil] has no seeded programs yet, and [felt]'s content is
/// the felt feature's courses rather than `ProgramDefinition`s. The picker
/// shows the categories in declaration order.
enum ProgramCategory {
  /// The air-pistol programs, shot at 10 m (or 5,5 m at home).
  nsfLuft('NSF Luft', 'Luftpistol – 10 m og 5,5 m'),

  /// The fin- and grovpistol cartridge programs at 25 m and 50 m.
  nsfFinGrov('NSF Fin/Grov', 'Fin- og grovpistol – 25 m og 50 m'),

  /// Military programs — none seeded yet (spec 0084 open question).
  mil('MIL', 'Militære programmer'),

  /// Field shooting: the NorgesFelt courses (spec 0068).
  felt('Felt', 'Feltskyting – NorgesFelt');

  const ProgramCategory(this.label, this.description);

  /// The Norwegian display name shown on the category card and page title.
  final String label;

  /// A one-line description shown under the label on the category card.
  final String description;
}
