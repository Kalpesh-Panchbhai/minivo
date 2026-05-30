import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/features/splash/splash_screen.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/overflow_detector.dart';

void main() {
  for (final device in allTestDevices) {
    group('SplashScreen on ${device.name} (${device.width}x${device.height})', () {
      setUp(() async {
        await initTestDependencies();
      });

      testWidgets('renders without overflow', (tester) async {
        await pumpScreen(tester, device, const SplashScreen(), settle: false);
        expectNoOverflow(device, 'SplashScreen');
        await tester.pumpAndSettle(const Duration(seconds: 3));
        cleanUp(tester);
      });

      testWidgets('app name is visible', (tester) async {
        await pumpScreen(tester, device, const SplashScreen(), settle: false);
        expect(find.text('Minivo'), findsOneWidget);
        expectNoOverflow(device, 'SplashScreen');
        await tester.pumpAndSettle(const Duration(seconds: 3));
        cleanUp(tester);
      });

      testWidgets('app icon is visible', (tester) async {
        await pumpScreen(tester, device, const SplashScreen(), settle: false);
        // Logo is a custom-painted controller (_LogoPainter) inside a
        // 120x120 SizedBox — assert the painter is rendered.
        expect(find.byType(CustomPaint), findsWidgets);
        expectNoOverflow(device, 'SplashScreen');
        await tester.pumpAndSettle(const Duration(seconds: 3));
        cleanUp(tester);
      });

      testWidgets('tagline is visible', (tester) async {
        await pumpScreen(tester, device, const SplashScreen(), settle: false);
        expect(find.text('Your Pocket Arcade'), findsOneWidget);
        expectNoOverflow(device, 'SplashScreen');
        await tester.pumpAndSettle(const Duration(seconds: 3));
        cleanUp(tester);
      });
    });
  }
}
