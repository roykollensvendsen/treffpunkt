// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for ContentScaffold, the shared screen skeleton: a frosted
// app bar over a SafeArea whose content is centered and capped at
// kMaxContentWidth, plus the behind-the-bar variant of spec 0129 where the
// body slides under the bar and reads the bar's inset from its own context.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treffpunkt/core/presentation/content_scaffold.dart';
import 'package:treffpunkt/core/presentation/frosted_bar.dart';
import 'package:treffpunkt/core/presentation/layout.dart';

void main() {
  const bodyKey = ValueKey<String>('probe-body');

  Widget app(Widget home) => MaterialApp(home: home);

  group('default variant', () {
    testWidgets('shows a FrostedAppBar with the title and actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          const ContentScaffold(
            title: Text('Tittel'),
            actions: [Icon(Icons.info_outline)],
            body: SizedBox(key: bodyKey),
          ),
        ),
      );

      expect(find.byType(FrostedAppBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FrostedAppBar),
          matching: find.text('Tittel'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(FrostedAppBar),
          matching: find.byIcon(Icons.info_outline),
        ),
        findsOneWidget,
      );
    });

    testWidgets('centers the body and caps it at kMaxContentWidth', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        app(
          const ContentScaffold(
            title: Text('Tittel'),
            body: SizedBox.expand(key: bodyKey),
          ),
        ),
      );

      // The body sits inside a SafeArea and is width-capped even though the
      // window is wider.
      expect(
        find.ancestor(of: find.byKey(bodyKey), matching: find.byType(SafeArea)),
        findsOneWidget,
      );
      expect(tester.getSize(find.byKey(bodyKey)).width, kMaxContentWidth);
      final center = tester.getCenter(find.byKey(bodyKey));
      expect(center.dx, 600);
    });

    testWidgets('does not extend the body behind the bar', (tester) async {
      await tester.pumpWidget(
        app(
          const ContentScaffold(
            title: Text('Tittel'),
            body: SizedBox(key: bodyKey),
          ),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBodyBehindAppBar, isFalse);
    });

    testWidgets('passes the floating action button through', (tester) async {
      await tester.pumpWidget(
        app(
          ContentScaffold(
            title: const Text('Tittel'),
            body: const SizedBox(key: bodyKey),
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  group('behindBar variant (spec 0129)', () {
    testWidgets('extends the body behind the frosted bar', (tester) async {
      await tester.pumpWidget(
        app(
          const ContentScaffold.behindBar(
            title: Text('Tittel'),
            body: SizedBox.expand(key: bodyKey),
          ),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBodyBehindAppBar, isTrue);
      expect(find.byType(FrostedAppBar), findsOneWidget);

      // The body genuinely reaches the top edge, under the bar.
      expect(tester.getTopLeft(find.byKey(bodyKey)).dy, 0);
    });

    testWidgets(
      'the body reads the bar inset from its own context, so '
      'frostedScrollPadding can start the content below the bar',
      (tester) async {
        late EdgeInsets seen;
        await tester.pumpWidget(
          app(
            ContentScaffold.behindBar(
              title: const Text('Tittel'),
              body: Builder(
                builder: (context) {
                  seen = MediaQuery.paddingOf(context);
                  return const SizedBox.expand(key: bodyKey);
                },
              ),
            ),
          ),
        );

        // The SafeArea leaves top and bottom to the scrollable (spec 0129):
        // the bar's height survives as MediaQuery padding inside the body.
        expect(seen.top, kToolbarHeight);
      },
    );

    testWidgets('still centers and caps the body at kMaxContentWidth', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        app(
          const ContentScaffold.behindBar(
            title: Text('Tittel'),
            body: SizedBox.expand(key: bodyKey),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(bodyKey)).width, kMaxContentWidth);
      expect(tester.getCenter(find.byKey(bodyKey)).dx, 600);
    });
  });
}
