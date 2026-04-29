import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/core/constants/app_theme.dart';
import '../../lib/core/services/score_service.dart';
import '../../lib/features/achievements/achievements_screen.dart';
import '../../lib/features/home/home_screen.dart';
import '../../lib/features/onboarding/onboarding_screen.dart';
import '../../lib/features/profile/profile_screen.dart';
import '../../lib/features/settings/settings_screen.dart';
import '../helpers/overflow_detector.dart';

// Verify that screens stay overflow-free when the user has bumped their
// device-wide text scale (a11y "Larger Text" iOS / "Font size" Android).
// We don't use the existing pumpScreen helper because we need to override
// MediaQuery.textScaler ourselves.

const _devices = <_Device>[
  _Device('iPhone SE 1st gen', 320, 568, 2.0, TargetPlatform.iOS),
  _Device('iPhone 13', 390, 844, 3.0, TargetPlatform.iOS),
  _Device('Pixel 6', 412, 915, 2.625, TargetPlatform.android),
];

class _Device {
  final String name;
  final double w, h, dpr;
  final TargetPlatform platform;
  const _Device(this.name, this.w, this.h, this.dpr, this.platform);
}

GoRouter _stubRouter(Widget screen) => GoRouter(
      initialLocation: '/test',
      routes: [
        GoRoute(path: '/test', builder: (_, _) => screen),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
        ),
        GoRoute(
          path: '/achievements',
          builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
        ),
      ],
    );

Future<void> _pumpAtScale(
  WidgetTester tester,
  _Device d,
  Widget screen,
  double textScale,
) async {
  await tester.binding.setSurfaceSize(Size(d.w, d.h));
  tester.view.devicePixelRatio = d.dpr;
  OverflowDetector.start();

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: Size(d.w, d.h),
        devicePixelRatio: d.dpr,
        textScaler: TextScaler.linear(textScale),
        padding: EdgeInsets.only(
          top: d.platform == TargetPlatform.iOS ? 47 : 24,
          bottom: d.platform == TargetPlatform.iOS ? 34 : 0,
        ),
      ),
      child: MaterialApp.router(
        theme: AppTheme.light.copyWith(platform: d.platform),
        routerConfig: _stubRouter(screen),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void _cleanup(WidgetTester tester) {
  OverflowDetector.stop();
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

void main() {
  group('Screens survive 1.3× text scaling without overflow', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ScoreService().init();
    });

    for (final d in _devices) {
      testWidgets('HomeScreen on ${d.name}', (tester) async {
        await _pumpAtScale(tester, d, const HomeScreen(), 1.3);
        OverflowDetector.expectNoOverflow(context: 'HomeScreen ${d.name} 1.3x');
        _cleanup(tester);
      });

      testWidgets('SettingsScreen on ${d.name}', (tester) async {
        await _pumpAtScale(tester, d, const SettingsScreen(), 1.3);
        OverflowDetector.expectNoOverflow(
          context: 'SettingsScreen ${d.name} 1.3x',
        );
        _cleanup(tester);
      });

      testWidgets('ProfileScreen on ${d.name}', (tester) async {
        await _pumpAtScale(tester, d, const ProfileScreen(), 1.3);
        OverflowDetector.expectNoOverflow(
          context: 'ProfileScreen ${d.name} 1.3x',
        );
        _cleanup(tester);
      });

      testWidgets('AchievementsScreen on ${d.name}', (tester) async {
        await _pumpAtScale(tester, d, const AchievementsScreen(), 1.3);
        OverflowDetector.expectNoOverflow(
          context: 'AchievementsScreen ${d.name} 1.3x',
        );
        _cleanup(tester);
      });

      testWidgets('OnboardingScreen on ${d.name}', (tester) async {
        await _pumpAtScale(tester, d, const OnboardingScreen(), 1.3);
        OverflowDetector.expectNoOverflow(
          context: 'OnboardingScreen ${d.name} 1.3x',
        );
        _cleanup(tester);
      });
    }
  });
}
