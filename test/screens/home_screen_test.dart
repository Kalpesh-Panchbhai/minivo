import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/features/home/home_screen.dart';
import '../../lib/core/widgets/mosaic_game_tile.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/overflow_detector.dart';

void main() {
  for (final device in allTestDevices) {
    group('HomeScreen on ${device.name} (${device.width}x${device.height})', () {
      setUp(() async {
        await initTestDependencies();
      });

      testWidgets('renders without overflow', (tester) async {
        await pumpScreen(tester, device, const HomeScreen());
        expectNoOverflow(device, 'HomeScreen');
        cleanUp(tester);
      });

      testWidgets('app bar elements visible', (tester) async {
        await pumpScreen(tester, device, const HomeScreen());
        expect(find.text('Minivo'), findsOneWidget);
        expect(find.byIcon(Icons.search_rounded), findsOneWidget);
        expectNoOverflow(device, 'HomeScreen');
        cleanUp(tester);
      });

      testWidgets('trending section exists', (tester) async {
        await pumpScreen(tester, device, const HomeScreen());
        expect(find.text('Trending'), findsOneWidget);
        expectNoOverflow(device, 'HomeScreen');
        cleanUp(tester);
      });

      testWidgets('mosaic game tiles rendered', (tester) async {
        await pumpScreen(tester, device, const HomeScreen());
        expect(find.byType(MosaicGameTile), findsWidgets);
        expectNoOverflow(device, 'HomeScreen');
        cleanUp(tester);
      });

      testWidgets('can scroll without overflow', (tester) async {
        await pumpScreen(tester, device, const HomeScreen());
        final scrollable = find.byType(Scrollable).first;
        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pumpAndSettle();
        expectNoOverflow(device, 'HomeScreen');
        cleanUp(tester);
      });

      testWidgets('category chips visible', (tester) async {
        await pumpScreen(tester, device, const HomeScreen());
        expect(find.text('Action'), findsWidgets);
        expectNoOverflow(device, 'HomeScreen');
        cleanUp(tester);
      });
    });
  }
}
