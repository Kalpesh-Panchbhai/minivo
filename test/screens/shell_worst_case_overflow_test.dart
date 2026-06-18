import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/core/services/score_service.dart';
import '../../lib/core/services/level_progress_service.dart';
import '../../lib/features/profile/profile_screen.dart';
import '../../lib/features/leaderboard/leaderboard_screen.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

// ---------------------------------------------------------------------------
// Worst-case DATA overflow for the app-shell screens whose existing tests only
// exercise the default (empty / short) state. These render the screens with
// the most extreme values a real player can reach:
//   • Profile  — 7-digit coins / games-played (the stat-card values have no
//                ellipsis and live in Expanded ~1/3-width cards).
//   • Leaderboard — the game-picker dropdown OPENED, so its menu items (a Row
//                with an un-ellipsised game name) actually render.
// Run on the narrowest phones where these are tightest.
// ---------------------------------------------------------------------------

const _narrow = [
  TestDevice(
      name: 'Small (320x568)',
      width: 320,
      height: 568,
      pixelRatio: 2.0,
      platform: TargetPlatform.android),
  TestDevice(
      name: 'Nexus 5 (360x640)',
      width: 360,
      height: 640,
      pixelRatio: 3.0,
      platform: TargetPlatform.android),
  TestDevice(
      name: 'iPhone SE 3rd (375x667)',
      width: 375,
      height: 667,
      pixelRatio: 2.0,
      platform: TargetPlatform.iOS),
];

Future<void> _initWithPrefs(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  await ScoreService().init();
  await LevelProgressService().init();
}

void main() {
  group('Profile huge-number stat cards', () {
    for (final device in _narrow) {
      testWidgets('no overflow with 7-digit coins/played on ${device.name}',
          (tester) async {
        await _initWithPrefs({
          'total_coins': 9999999,
          'total_games_played': 8888888,
        });
        await pumpScreen(tester, device, const ProfileScreen());
        expect(find.text('9999999'), findsOneWidget);
        expectNoOverflow(device, 'ProfileScreen huge numbers');
        cleanUp(tester);
      });
    }
  });

  group('Leaderboard dropdown opened', () {
    for (final device in _narrow) {
      testWidgets('menu items render without overflow on ${device.name}',
          (tester) async {
        await _initWithPrefs({});
        await pumpScreen(tester, device, const LeaderboardScreen());
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pumpAndSettle();
        expectNoOverflow(device, 'Leaderboard dropdown menu');
        cleanUp(tester);
      });
    }
  });
}
