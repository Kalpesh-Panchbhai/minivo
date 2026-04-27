import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/features/profile/profile_screen.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/overflow_detector.dart';

void main() {
  for (final device in allTestDevices) {
    group('ProfileScreen on ${device.name} (${device.width}x${device.height})', () {
      setUp(() async {
        await initTestDependencies();
      });

      testWidgets('renders without overflow', (tester) async {
        await pumpScreen(tester, device, const ProfileScreen());
        expectNoOverflow(device, 'ProfileScreen');
        cleanUp(tester);
      });

      testWidgets('profile header visible', (tester) async {
        await pumpScreen(tester, device, const ProfileScreen());
        expect(find.text('Player'), findsOneWidget);
        expectNoOverflow(device, 'ProfileScreen');
        cleanUp(tester);
      });

      testWidgets('stats section visible (Played)', (tester) async {
        await pumpScreen(tester, device, const ProfileScreen());
        expect(find.text('Played'), findsOneWidget);
        expectNoOverflow(device, 'ProfileScreen');
        cleanUp(tester);
      });

      testWidgets('favorites section visible', (tester) async {
        await pumpScreen(tester, device, const ProfileScreen());
        expect(find.text('Favorites'), findsOneWidget);
        expectNoOverflow(device, 'ProfileScreen');
        cleanUp(tester);
      });

      testWidgets('achievements section visible', (tester) async {
        await pumpScreen(tester, device, const ProfileScreen());
        expect(find.text('Achievements'), findsOneWidget);
        expectNoOverflow(device, 'ProfileScreen');
        cleanUp(tester);
      });

      testWidgets('settings icon visible', (tester) async {
        await pumpScreen(tester, device, const ProfileScreen());
        expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
        expectNoOverflow(device, 'ProfileScreen');
        cleanUp(tester);
      });

      testWidgets('can scroll without overflow', (tester) async {
        await pumpScreen(tester, device, const ProfileScreen());
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -300));
          await tester.pumpAndSettle();
        }
        expectNoOverflow(device, 'ProfileScreen');
        cleanUp(tester);
      });
    });
  }
}
