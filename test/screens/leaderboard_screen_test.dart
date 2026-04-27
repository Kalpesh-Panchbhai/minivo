import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/features/leaderboard/leaderboard_screen.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/overflow_detector.dart';

void main() {
  for (final device in allTestDevices) {
    group('LeaderboardScreen on ${device.name} (${device.width}x${device.height})', () {
      setUp(() async {
        await initTestDependencies();
      });

      testWidgets('renders without overflow', (tester) async {
        await pumpScreen(tester, device, const LeaderboardScreen());
        expectNoOverflow(device, 'LeaderboardScreen');
        cleanUp(tester);
      });

      testWidgets('title is visible', (tester) async {
        await pumpScreen(tester, device, const LeaderboardScreen());
        expect(find.text('Leaderboard'), findsOneWidget);
        expectNoOverflow(device, 'LeaderboardScreen');
        cleanUp(tester);
      });

      testWidgets('time filter tabs visible', (tester) async {
        await pumpScreen(tester, device, const LeaderboardScreen());
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('This Week'), findsOneWidget);
        expect(find.text('All Time'), findsOneWidget);
        expectNoOverflow(device, 'LeaderboardScreen');
        cleanUp(tester);
      });

      testWidgets('game selector visible', (tester) async {
        await pumpScreen(tester, device, const LeaderboardScreen());
        expect(find.text('Flappy Tap'), findsWidgets);
        expectNoOverflow(device, 'LeaderboardScreen');
        cleanUp(tester);
      });

      testWidgets('can switch time tabs without overflow', (tester) async {
        await pumpScreen(tester, device, const LeaderboardScreen());
        await tester.tap(find.text('This Week'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('All Time'));
        await tester.pumpAndSettle();
        expectNoOverflow(device, 'LeaderboardScreen');
        cleanUp(tester);
      });

      testWidgets('leaderboard entries visible', (tester) async {
        await pumpScreen(tester, device, const LeaderboardScreen());
        expect(find.byIcon(Icons.emoji_events_rounded), findsWidgets);
        expectNoOverflow(device, 'LeaderboardScreen');
        cleanUp(tester);
      });
    });
  }
}
