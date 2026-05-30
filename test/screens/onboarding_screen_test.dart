import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/features/onboarding/onboarding_screen.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/overflow_detector.dart';

void main() {
  for (final device in allTestDevices) {
    group('OnboardingScreen on ${device.name} (${device.width}x${device.height})', () {
      setUp(() async {
        await initTestDependencies();
      });

      testWidgets('renders without overflow', (tester) async {
        await pumpScreen(tester, device, const OnboardingScreen());
        expectNoOverflow(device, 'OnboardingScreen');
        cleanUp(tester);
      });

      testWidgets('first page elements are visible', (tester) async {
        await pumpScreen(tester, device, const OnboardingScreen());
        expect(find.text('Play Anywhere'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
        expectNoOverflow(device, 'OnboardingScreen');
        cleanUp(tester);
      });

      testWidgets('can navigate to second page', (tester) async {
        await pumpScreen(tester, device, const OnboardingScreen());
        await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
        // Onboarding has indefinite repeat animations (float + particles);
        // bounded pumps drain the 400ms PageView transition + the 200ms
        // delayed title fadeIn without hanging on the never-settling
        // controllers. Pump in chunks so onPageChanged → setState runs.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Beat Your Best'), findsOneWidget);
        expectNoOverflow(device, 'OnboardingScreen');
        cleanUp(tester);
      });

      testWidgets('can navigate to third page', (tester) async {
        await pumpScreen(tester, device, const OnboardingScreen());
        await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Quick & Light'), findsOneWidget);
        expect(find.text('Get Started'), findsOneWidget);
        expectNoOverflow(device, 'OnboardingScreen');
        cleanUp(tester);
      });

      testWidgets('skip button is tappable (min 44x44)', (tester) async {
        await pumpScreen(tester, device, const OnboardingScreen());
        final skipFinder = find.text('Skip');
        expect(skipFinder, findsOneWidget);
        final size = tester.getSize(skipFinder);
        expect(size.width, greaterThanOrEqualTo(30));
        expect(size.height, greaterThanOrEqualTo(20));
        expectNoOverflow(device, 'OnboardingScreen');
        cleanUp(tester);
      });

      testWidgets('next button meets min tap target', (tester) async {
        await pumpScreen(tester, device, const OnboardingScreen());
        final nextFinder = find.byIcon(Icons.arrow_forward_rounded);
        expect(nextFinder, findsOneWidget);
        expectNoOverflow(device, 'OnboardingScreen');
        cleanUp(tester);
      });
    });
  }
}
