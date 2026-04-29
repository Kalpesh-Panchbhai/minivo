import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/core/constants/app_theme.dart';
import '../../lib/core/services/score_service.dart';
import '../../lib/routing/app_router.dart';

Widget _app() => MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: AppRouter.router,
    );

Future<void> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(412, 915));
  tester.view.devicePixelRatio = 2.625;
  // AppRouter.router is a static singleton — reset its current location to
  // '/' so nav state from previous tests doesn't leak in.
  AppRouter.router.go('/');
  await tester.pumpWidget(_app());
  await tester.pump();
}

void main() {
  group('AppRouter end-to-end navigation', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ScoreService().init();
    });

    testWidgets('first launch routes from splash to onboarding',
        (tester) async {
      await _pump(tester);
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      // Onboarding screen exposes a Skip control.
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('returning user routes from splash to home', (tester) async {
      await ScoreService().setOnboardingSeen();
      await _pump(tester);
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      // Home shows the app title.
      expect(find.text('Minivo'), findsOneWidget);
    });

    testWidgets('home -> search via app bar icon', (tester) async {
      await ScoreService().setOnboardingSeen();
      await _pump(tester);
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      // Once on the search screen, the Home title is no longer present.
      expect(find.text('Minivo'), findsNothing);
    });

    testWidgets('/game/tic_tac_toe redirects to /play/tic_tac_toe',
        (tester) async {
      await ScoreService().setOnboardingSeen();
      await _pump(tester);
      // Drain the splash's 2 s delayed-navigate timer first so it doesn't
      // leak past the end of the test.
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      AppRouter.router.go('/game/tic_tac_toe');
      await tester.pumpAndSettle();
      expect(find.text('Play vs. AI'), findsOneWidget);
    });

    testWidgets('/game/flappy_tap renders GameDetailScreen', (tester) async {
      await ScoreService().setOnboardingSeen();
      await _pump(tester);
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      AppRouter.router.go('/game/flappy_tap');
      await tester.pumpAndSettle();
      expect(find.text('How to Play'), findsWidgets);
    });
  });
}
