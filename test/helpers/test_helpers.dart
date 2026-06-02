import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../lib/core/constants/app_theme.dart';
import '../../lib/core/services/score_service.dart';
import 'screen_sizes.dart';
import 'overflow_detector.dart';

Future<void> initTestDependencies() async {
  SharedPreferences.setMockInitialValues({
    'tutorial_seen_color_tap': true,
    'tutorial_seen_dino_run': true,
    'tutorial_seen_dodge_ball': true,
    'tutorial_seen_dots_and_boxes': true,
    'tutorial_seen_drop_merge': true,
    'tutorial_seen_flappy_tap': true,
    'tutorial_seen_memory_match': true,
    'tutorial_seen_number_merge': true,
    'tutorial_seen_snake_classic': true,
    'tutorial_seen_sudoku': true,
    'tutorial_seen_tic_tac_toe': true,
    'tutorial_seen_whack_a_mole': true,
    'tutorial_seen_tap_tap_dash': true,
  });
  await ScoreService().init();
}

GoRouter _buildTestRouter(Widget screen) {
  return GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(
        path: '/test',
        builder: (context, state) => screen,
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Center(child: Text('Home'))),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const Scaffold(body: Center(child: Text('Onboarding'))),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const Scaffold(body: Center(child: Text('Search'))),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const Scaffold(body: Center(child: Text('Settings'))),
      ),
      GoRoute(
        path: '/achievements',
        builder: (context, state) => const Scaffold(body: Center(child: Text('Achievements'))),
      ),
      GoRoute(
        path: '/category/:name',
        builder: (context, state) => const Scaffold(body: Center(child: Text('Category'))),
      ),
      GoRoute(
        path: '/game/:id',
        builder: (context, state) => const Scaffold(body: Center(child: Text('GameDetail'))),
      ),
      GoRoute(
        path: '/play/:id',
        builder: (context, state) => const Scaffold(body: Center(child: Text('Play'))),
      ),
    ],
  );
}

Future<void> pumpScreen(
  WidgetTester tester,
  TestDevice device,
  Widget screen, {
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(Size(device.width, device.height));
  tester.view.devicePixelRatio = device.pixelRatio;

  OverflowDetector.start();

  final router = _buildTestRouter(screen);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: Size(device.width, device.height),
        devicePixelRatio: device.pixelRatio,
        padding: EdgeInsets.only(
          top: device.platform == TargetPlatform.iOS ? 47 : 24,
          bottom: device.platform == TargetPlatform.iOS ? 34 : 0,
        ),
      ),
      child: MaterialApp.router(
        theme: AppTheme.light.copyWith(
          platform: device.platform,
        ),
        routerConfig: router,
      ),
    ),
  );

  if (settle) {
    // Some screens have indefinite animations (animated backgrounds,
    // glowing icons). pumpAndSettle never returns when an AnimationController
    // is in `.repeat()`. Try to settle briefly, then fall through to a
    // bounded pump so the test can still inspect the rendered tree.
    try {
      await tester.pumpAndSettle(const Duration(seconds: 1));
    } catch (_) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  } else {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void expectNoOverflow(TestDevice device, String screenName) {
  OverflowDetector.expectNoOverflow(
    context: '$screenName on ${device.name} (${device.width}x${device.height})',
  );
}

void cleanUp(WidgetTester tester) {
  OverflowDetector.stop();
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

void testScreenOnAllDevices({
  required String screenName,
  required Widget Function() buildScreen,
  required void Function(WidgetTester tester, TestDevice device) runElementTests,
}) {
  for (final device in allTestDevices) {
    group('$screenName on ${device.name} (${device.width}x${device.height})', () {
      setUp(() async {
        await initTestDependencies();
      });

      testWidgets('renders without overflow', (tester) async {
        await pumpScreen(tester, device, buildScreen());
        expectNoOverflow(device, screenName);
        cleanUp(tester);
      });

      testWidgets('all elements present and layout intact', (tester) async {
        await pumpScreen(tester, device, buildScreen());
        runElementTests(tester, device);
        expectNoOverflow(device, screenName);
        cleanUp(tester);
      });
    });
  }
}
