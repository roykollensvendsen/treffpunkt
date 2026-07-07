// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// The developer's personal Vipps payment link (spec 0146): opens Vipps
/// with the recipient set on a phone, or the QR page in a browser. The one
/// place to change if the Vipps box is rotated.
final Uri vippsCoffeeUri = Uri.parse(
  'https://qr.vipps.no/box/aabe6bd3-f162-4abb-869a-b5b6a504486d/pay-in',
);
