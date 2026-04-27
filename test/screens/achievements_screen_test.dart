import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/features/achievements/achievements_screen.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/overflow_detector.dart';

void main() {
  for (final device in allTestDevices) {
    group('AchievementsScreen on ${device.name} (${device.width}x${device.height})', () {
      setUp(() async {
        await initTestDependencies();
      });

      testWidgets('renders without overflow', (tester) async {
        await pumpScreen(tester, device, const AchievementsScreen());
        expectNoOverflow(device, 'AchievementsScreen');
        cleanUp(tester);
      });

      testWidgets('title visible', (tester) async {
        await pumpScreen(tester, device, const AchievementsScreen());
        expect(find.text('Achievements'), findsOneWidget);
        expectNoOverflow(device, 'AchievementsScreen');
        cleanUp(tester);
      });

      testWidgets('back button visible', (tester) async {
        await pumpScreen(tester, device, const AchievementsScreen());
        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
        expectNoOverflow(device, 'AchievementsScreen');
        cleanUp(tester);
      });

      testWidgets('counter badge visible', (tester) async {
        await pumpScreen(tester, device, const AchievementsScreen());
        expect(find.textContaining('/'), findsOneWidget);
        expectNoOverflow(device, 'AchievementsScreen');
        cleanUp(tester);
      });

      testWidgets('achievement items rendered', (tester) async {
        await pumpScreen(tester, device, const AchievementsScreen());
        expect(find.text('First Steps'), findsOneWidget);
        expect(find.text('Getting Hooked'), findsOneWidget);
        expectNoOverflow(device, 'AchievementsScreen');
        cleanUp(tester);
      });

      testWidgets('achievement descriptions visible', (tester) async {
        await pumpScreen(tester, device, const AchievementsScreen());
        expect(find.text('Play your first game'), findsOneWidget);
        expectNoOverflow(device, 'AchievementsScreen');
        cleanUp(tester);
      });

      testWidgets('lock icons shown for locked achievements', (tester) async {
        await pumpScreen(tester, device, const AchievementsScreen());
        expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
        expectNoOverflow(device, 'AchievementsScreen');
        cleanUp(tester);
      });

      testWidgets('can scroll full list without overflow', (tester) async {
        await pumpScreen(tester, device, const AchievementsScreen());
        final scrollable = find.byType(Scrollable).first;
        await tester.drag(scrollable, const Offset(0, -500));
        await tester.pumpAndSettle();
        expectNoOverflow(device, 'AchievementsScreen');
        cleanUp(tester);
      });
    });
  }
}
