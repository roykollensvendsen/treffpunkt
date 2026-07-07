// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:treffpunkt/features/felt/domain/felt_course.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art.dart';
import 'package:treffpunkt/features/felt/presentation/felt_hold_art_data.dart';

/// The composed hold art for [course] (specs 0079/0145), index-aligned with
/// `course.holds`. The domain stays Flutter-free, so the course carries no
/// art itself; this is the single place a course id picks its pictures.
List<FeltHoldArt> feltArtForCourse(FeltCourse course) =>
    course.id == askerPlusCourse.id ? askerPlusArt : norgesfelt2026Art;
