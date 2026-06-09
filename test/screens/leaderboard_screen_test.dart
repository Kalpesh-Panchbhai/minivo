import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/features/leaderboard/leaderboard_screen.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('LeaderboardScreen', () {
    setUp(() async => initTestDependencies());

    for (final device in allTestDevices) {
      group('on ${device.name} (${device.width}x${device.height})', () {
        testWidgets('renders without overflow', (tester) async {
          await pumpScreen(tester, device, const LeaderboardScreen());
          expectNoOverflow(device, 'LeaderboardScreen');
          cleanUp(tester);
        });

        testWidgets('shows title', (tester) async {
          await pumpScreen(tester, device, const LeaderboardScreen());
          expect(find.text('Leaderboard'), findsOneWidget);
          cleanUp(tester);
        });
      });
    }

    testWidgets('shows tab bar with Today, This Week, All Time', (tester) async {
      await pumpScreen(tester, allTestDevices.first, const LeaderboardScreen());
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('All Time'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('shows game selector dropdown', (tester) async {
      await pumpScreen(tester, allTestDevices.first, const LeaderboardScreen());
      expect(find.byType(DropdownButton<String>), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('shows leaderboard entries', (tester) async {
      await pumpScreen(tester, allTestDevices.first, const LeaderboardScreen());
      expect(find.text('Player1'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('shows medal icons for top 3', (tester) async {
      await pumpScreen(tester, allTestDevices.first, const LeaderboardScreen());
      expect(find.byIcon(Icons.emoji_events_rounded), findsWidgets);
      cleanUp(tester);
    });

    testWidgets('scrollable list does not overflow', (tester) async {
      await pumpScreen(tester, allTestDevices.first, const LeaderboardScreen());
      final listFinder = find.byType(ListView);
      expect(listFinder, findsWidgets);
      expectNoOverflow(allTestDevices.first, 'LeaderboardScreen scroll');
      cleanUp(tester);
    });
  });
}
