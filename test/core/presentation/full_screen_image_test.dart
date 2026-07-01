// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget test for the full-screen image viewer (spec 0073): tapping a thumbnail
// opens a zoomable InteractiveViewer, and the close action dismisses it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/full_screen_image.dart';

void main() {
  const thumb = ValueKey<String>('thumb');

  testWidgets(
    'tapping the thumbnail opens a zoomable viewer, close dismisses',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TappableNetworkImage(
                url: 'https://example.test/target.png',
                heroTag: 'img-1',
                thumbnailKey: thumb,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(thumb), findsOneWidget);
      expect(find.byKey(fullScreenImageKey), findsNothing);

      await tester.tap(find.byKey(thumb));
      await tester.pumpAndSettle();

      // A zoom/pan viewer is shown.
      expect(find.byKey(fullScreenImageKey), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);

      await tester.tap(find.byKey(fullScreenImageCloseKey));
      await tester.pumpAndSettle();
      expect(find.byKey(fullScreenImageKey), findsNothing);
    },
  );
}
