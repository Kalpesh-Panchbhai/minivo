import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/features/achievements/achievements_screen.dart';
import '../../lib/features/category/category_screen.dart';
import '../../lib/features/home/home_screen.dart';
import '../../lib/features/home/main_shell.dart';
import '../../lib/features/leaderboard/leaderboard_screen.dart';
import '../../lib/features/onboarding/onboarding_screen.dart';
import '../../lib/features/profile/profile_screen.dart';
import '../../lib/features/search/search_screen.dart';
import '../../lib/features/settings/settings_screen.dart';
import '../../lib/features/splash/splash_screen.dart';
import '../helpers/overflow_detector.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

// Existing tests cover portrait orientation only. This file widens that
// coverage to common landscape layouts so we catch overflow in rotated
// contexts (foldables, tablets, simulator rotations).

const _landscape = <TestDevice>[
  TestDevice(
    name: 'Pixel 6 Landscape',
    width: 915,
    height: 412,
    pixelRatio: 2.625,
    platform: TargetPlatform.android,
  ),
  TestDevice(
    name: 'iPhone 14 Landscape',
    width: 844,
    height: 390,
    pixelRatio: 3.0,
    platform: TargetPlatform.iOS,
  ),
  TestDevice(
    name: 'iPad Landscape',
    width: 1366,
    height: 1024,
    pixelRatio: 2.0,
    platform: TargetPlatform.iOS,
  ),
];

typedef _Builder = Widget Function();

const _screens = <String, _Builder>{
  'SplashScreen': _splash,
  'OnboardingScreen': _onboarding,
  'HomeScreen': _home,
  'MainShell': _shell,
  'SearchScreen': _search,
  'CategoryScreen': _category,
  'LeaderboardScreen': _leaderboard,
  'ProfileScreen': _profile,
  'SettingsScreen': _settings,
  'AchievementsScreen': _achievements,
};

Widget _splash() => const SplashScreen();
Widget _onboarding() => const OnboardingScreen();
Widget _home() => const HomeScreen();
Widget _shell() => const MainShell();
Widget _search() => const SearchScreen();
Widget _category() => const CategoryScreen(categoryName: 'puzzle');
Widget _leaderboard() => const LeaderboardScreen();
Widget _profile() => const ProfileScreen();
Widget _settings() => const SettingsScreen();
Widget _achievements() => const AchievementsScreen();

void main() {
  for (final d in _landscape) {
    group('Landscape on ${d.name} (${d.width}x${d.height})', () {
      setUp(() async => initTestDependencies());

      for (final entry in _screens.entries) {
        testWidgets('${entry.key} renders without overflow', (tester) async {
          await pumpScreen(tester, d, entry.value(), settle: false);
          OverflowDetector.expectNoOverflow(
            context: '${entry.key} on ${d.name}',
          );
          // Drain any splash / animation timers before teardown.
          await tester.pump(const Duration(seconds: 3));
          OverflowDetector.stop();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
      }
    });
  }
}
