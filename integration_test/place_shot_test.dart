// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// System test: launch the real app, place a shot, read the score.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:treffpunkt/features/scoring/presentation/target_canvas.dart';
import 'package:treffpunkt/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tapping the target centre shows the maximum score', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('Tap the target'), findsOneWidget);

    await tester.tap(find.byKey(targetGestureKey));
    await tester.pumpAndSettle();

    expect(find.text('10.9'), findsOneWidget);
  });
}
