// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// A decimal score in Norwegian notation (spec 0107): one decimal, comma —
/// e.g. `10.4` → `'10,4'`. Shared by the scorecard and the loupe readout
/// (spec 0153).
String norDecimalScore(double value) =>
    value.toStringAsFixed(1).replaceAll('.', ',');
