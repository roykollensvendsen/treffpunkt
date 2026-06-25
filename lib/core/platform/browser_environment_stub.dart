// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/core/platform/browser_environment.dart';

/// The non-web (and test) [readBrowserEnvironment]: the empty default, so no
/// browser warning is ever shown off the web (spec 0042).
BrowserEnvironment readBrowserEnvironment() => const BrowserEnvironment.empty();
