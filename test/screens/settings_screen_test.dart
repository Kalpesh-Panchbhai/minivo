import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/features/settings/settings_screen.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/overflow_detector.dart';

void main() {
  for (final device in allTestDevices) {
    group('SettingsScreen on ${device.name} (${device.width}x${device.height})', () {
      setUp(() async {
        await initTestDependencies();
      });

      testWidgets('renders without overflow', (tester) async {
        await pumpScreen(tester, device, const SettingsScreen());
        expectNoOverflow(device, 'SettingsScreen');
        cleanUp(tester);
      });

      testWidgets('title visible', (tester) async {
        await pumpScreen(tester, device, const SettingsScreen());
        expect(find.text('Settings'), findsOneWidget);
        expectNoOverflow(device, 'SettingsScreen');
        cleanUp(tester);
      });

      testWidgets('back button visible', (tester) async {
        await pumpScreen(tester, device, const SettingsScreen());
        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
        expectNoOverflow(device, 'SettingsScreen');
        cleanUp(tester);
      });

      testWidgets('player name visible', (tester) async {
        await pumpScreen(tester, device, const SettingsScreen());
        expect(find.byIcon(Icons.person_rounded), findsOneWidget);
        expectNoOverflow(device, 'SettingsScreen');
        cleanUp(tester);
      });

      testWidgets('menu items visible', (tester) async {
        await pumpScreen(tester, device, const SettingsScreen());
        expect(find.text('Rate App'), findsOneWidget);
        expect(find.text('Share App'), findsOneWidget);
        expect(find.text('Privacy Policy'), findsOneWidget);
        expectNoOverflow(device, 'SettingsScreen');
        cleanUp(tester);
      });

      testWidgets('version string visible', (tester) async {
        await pumpScreen(tester, device, const SettingsScreen());
        expect(find.textContaining('Minivo'), findsOneWidget);
        expectNoOverflow(device, 'SettingsScreen');
        cleanUp(tester);
      });

      testWidgets('can scroll without overflow', (tester) async {
        await pumpScreen(tester, device, const SettingsScreen());
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -300));
          await tester.pumpAndSettle();
        }
        expectNoOverflow(device, 'SettingsScreen');
        cleanUp(tester);
      });
    });
  }
}
