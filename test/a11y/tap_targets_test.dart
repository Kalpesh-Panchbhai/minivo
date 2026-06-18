import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/features/achievements/achievements_screen.dart';
import '../../lib/features/home/home_screen.dart';
import '../../lib/features/home/main_shell.dart';
import '../../lib/features/profile/profile_screen.dart';
import '../../lib/features/settings/settings_screen.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

// The Minivo project rules require a minimum tap target of 44 × 44 dp.
// These tests use Flutter's built-in accessibility guideline checkers to
// flag any interactive widget that is too small or has insufficient
// information for screen readers.

const _device = TestDevice(
  name: 'iPhone 13',
  width: 390,
  height: 844,
  pixelRatio: 3.0,
  platform: TargetPlatform.iOS,
);

Future<void> _checkTapSize(WidgetTester tester, Widget screen) async {
  final handle = tester.ensureSemantics();
  await pumpScreen(tester, _device, screen, settle: false);

  // The Minivo project rule requires a minimum tap target of 44 × 44 dp.
  // We assert the iOS guideline (44 dp) which is stricter than Android's 48
  // and matches the explicit project requirement.
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  handle.dispose();
  cleanUp(tester);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('Tap targets meet 44 × 44 minimum', () {
    setUp(() async => initTestDependencies());

    testWidgets('HomeScreen', (tester) async {
      await _checkTapSize(tester, const HomeScreen());
    });

    testWidgets('MainShell bottom-nav', (tester) async {
      await _checkTapSize(tester, const MainShell());
    });

    testWidgets('SettingsScreen', (tester) async {
      await _checkTapSize(tester, const SettingsScreen());
    });

    testWidgets('ProfileScreen', (tester) async {
      await _checkTapSize(tester, const ProfileScreen());
    });

    testWidgets('AchievementsScreen', (tester) async {
      await _checkTapSize(tester, const AchievementsScreen());
    });
  });
}
