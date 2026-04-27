import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/features/home/main_shell.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/overflow_detector.dart';

void main() {
  for (final device in allTestDevices) {
    group('MainShell on ${device.name} (${device.width}x${device.height})', () {
      setUp(() async {
        await initTestDependencies();
      });

      testWidgets('renders without overflow', (tester) async {
        await pumpScreen(tester, device, const MainShell());
        expectNoOverflow(device, 'MainShell');
        cleanUp(tester);
      });

      testWidgets('bottom nav has 3 items', (tester) async {
        await pumpScreen(tester, device, const MainShell());
        expect(find.text('Home'), findsOneWidget);
        expect(find.byIcon(Icons.home_rounded), findsOneWidget);
        expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
        expect(find.byIcon(Icons.person_outlined), findsOneWidget);
        expectNoOverflow(device, 'MainShell');
        cleanUp(tester);
      });

      testWidgets('nav icons are visible', (tester) async {
        await pumpScreen(tester, device, const MainShell());
        expect(find.byIcon(Icons.home_rounded), findsOneWidget);
        expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
        expect(find.byIcon(Icons.person_outlined), findsOneWidget);
        expectNoOverflow(device, 'MainShell');
        cleanUp(tester);
      });

      testWidgets('can switch to Ranks tab', (tester) async {
        await pumpScreen(tester, device, const MainShell());
        await tester.tap(find.byIcon(Icons.emoji_events_outlined));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.emoji_events_rounded), findsWidgets);
        expectNoOverflow(device, 'MainShell');
        cleanUp(tester);
      });

      testWidgets('can switch to Profile tab', (tester) async {
        await pumpScreen(tester, device, const MainShell());
        await tester.tap(find.byIcon(Icons.person_outlined));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.person_rounded), findsWidgets);
        expectNoOverflow(device, 'MainShell');
        cleanUp(tester);
      });

      testWidgets('nav items meet min tap target', (tester) async {
        await pumpScreen(tester, device, const MainShell());
        final homeIcon = find.byIcon(Icons.home_rounded);
        final size = tester.getSize(homeIcon);
        expect(size.width, greaterThanOrEqualTo(24));
        expect(size.height, greaterThanOrEqualTo(24));
        expectNoOverflow(device, 'MainShell');
        cleanUp(tester);
      });
    });
  }
}
