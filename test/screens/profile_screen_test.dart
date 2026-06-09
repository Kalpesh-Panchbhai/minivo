import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/features/profile/profile_screen.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('ProfileScreen', () {
    setUp(() async => initTestDependencies());

    for (final device in allTestDevices) {
      group('on ${device.name} (${device.width}x${device.height})', () {
        testWidgets('renders without overflow', (tester) async {
          await pumpScreen(tester, device, const ProfileScreen());
          expectNoOverflow(device, 'ProfileScreen');
          cleanUp(tester);
        });

        testWidgets('shows title and elements', (tester) async {
          await pumpScreen(tester, device, const ProfileScreen());
          expect(find.text('Profile'), findsOneWidget);
          expectNoOverflow(device, 'ProfileScreen elements');
          cleanUp(tester);
        });
      });
    }

    testWidgets('shows player name', (tester) async {
      await pumpScreen(tester, allTestDevices.first, const ProfileScreen());
      expect(find.text('Player'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('shows Game Enthusiast subtitle', (tester) async {
      await pumpScreen(tester, allTestDevices.first, const ProfileScreen());
      expect(find.text('Game Enthusiast'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('shows stats cards (Played, Coins, Favorites)', (tester) async {
      await pumpScreen(tester, allTestDevices.first, const ProfileScreen());
      expect(find.text('Played'), findsOneWidget);
      expect(find.text('Coins'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('shows Achievements section', (tester) async {
      await pumpScreen(tester, allTestDevices.first, const ProfileScreen());
      expect(find.text('Achievements'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('shows settings icon', (tester) async {
      await pumpScreen(tester, allTestDevices.first, const ProfileScreen());
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('shows achievement badges', (tester) async {
      await pumpScreen(tester, allTestDevices.first, const ProfileScreen());
      expect(find.text('First Steps'), findsOneWidget);
      expect(find.text('10 Games'), findsOneWidget);
      expect(find.text('Top Scorer'), findsOneWidget);
      expect(find.text('Star Pro'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('is scrollable without overflow', (tester) async {
      final device = allTestDevices.first;
      await pumpScreen(tester, device, const ProfileScreen());
      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);
      expectNoOverflow(device, 'ProfileScreen scroll');
      cleanUp(tester);
    });
  });
}
