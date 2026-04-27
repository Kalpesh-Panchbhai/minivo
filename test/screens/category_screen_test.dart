import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/features/category/category_screen.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/overflow_detector.dart';

void main() {
  for (final device in allTestDevices) {
    group('CategoryScreen on ${device.name} (${device.width}x${device.height})', () {
      setUp(() async {
        await initTestDependencies();
      });

      testWidgets('renders Puzzle category without overflow', (tester) async {
        await pumpScreen(tester, device, const CategoryScreen(categoryName: 'puzzle'));
        expectNoOverflow(device, 'CategoryScreen');
        cleanUp(tester);
      });

      testWidgets('category title visible', (tester) async {
        await pumpScreen(tester, device, const CategoryScreen(categoryName: 'puzzle'));
        expect(find.text('Puzzle'), findsWidgets);
        expectNoOverflow(device, 'CategoryScreen');
        cleanUp(tester);
      });

      testWidgets('back button visible', (tester) async {
        await pumpScreen(tester, device, const CategoryScreen(categoryName: 'puzzle'));
        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
        expectNoOverflow(device, 'CategoryScreen');
        cleanUp(tester);
      });

      testWidgets('renders Arcade category without overflow', (tester) async {
        await pumpScreen(tester, device, const CategoryScreen(categoryName: 'arcade'));
        expectNoOverflow(device, 'CategoryScreen');
        cleanUp(tester);
      });

      testWidgets('renders Board category without overflow', (tester) async {
        await pumpScreen(tester, device, const CategoryScreen(categoryName: 'board'));
        expectNoOverflow(device, 'CategoryScreen');
        cleanUp(tester);
      });

      testWidgets('can scroll game grid', (tester) async {
        await pumpScreen(tester, device, const CategoryScreen(categoryName: 'puzzle'));
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
        }
        expectNoOverflow(device, 'CategoryScreen');
        cleanUp(tester);
      });
    });
  }
}
