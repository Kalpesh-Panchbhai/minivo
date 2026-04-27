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

      testWidgets('profile section visible', (tester) async {
        await pumpScreen(tester, device, const SettingsScreen());
        expect(find.text('Display Name'), findsOneWidget);
        expectNoOverflow(device, 'SettingsScreen');
        cleanUp(tester);
      });

      testWidgets('sound toggle visible', (tester) async {
        await pumpScreen(tester, device, const SettingsScreen());
        expect(find.text('Sound'), findsOneWidget);
        expect(find.byType(Switch), findsWidgets);
        expectNoOverflow(device, 'SettingsScreen');
        cleanUp(tester);
      });

      testWidgets('vibration toggle visible', (tester) async {
        await pumpScreen(tester, device, const SettingsScreen());
        expect(find.text('Vibration'), findsOneWidget);
        expectNoOverflow(device, 'SettingsScreen');
        cleanUp(tester);
      });

      testWidgets('about section visible', (tester) async {
        await pumpScreen(tester, device, const SettingsScreen());
        expect(find.text('Rate App'), findsOneWidget);
        expect(find.text('Share App'), findsOneWidget);
        expect(find.text('Privacy Policy'), findsOneWidget);
        expect(find.text('Terms of Service'), findsOneWidget);
        expectNoOverflow(device, 'SettingsScreen');
        cleanUp(tester);
      });

      testWidgets('version string visible', (tester) async {
        await pumpScreen(tester, device, const SettingsScreen());
        expect(find.text('Minivo v1.0.0'), findsOneWidget);
        expectNoOverflow(device, 'SettingsScreen');
        cleanUp(tester);
      });

      testWidgets('can toggle sound switch', (tester) async {
        await pumpScreen(tester, device, const SettingsScreen());
        final switches = find.byType(Switch);
        await tester.tap(switches.first);
        await tester.pumpAndSettle();
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
