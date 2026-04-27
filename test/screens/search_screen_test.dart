import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/features/search/search_screen.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/overflow_detector.dart';

void main() {
  for (final device in allTestDevices) {
    group('SearchScreen on ${device.name} (${device.width}x${device.height})', () {
      setUp(() async {
        await initTestDependencies();
      });

      testWidgets('renders without overflow', (tester) async {
        await pumpScreen(tester, device, const SearchScreen());
        expectNoOverflow(device, 'SearchScreen');
        cleanUp(tester);
      });

      testWidgets('search bar is visible', (tester) async {
        await pumpScreen(tester, device, const SearchScreen());
        expect(find.byType(TextField), findsOneWidget);
        expectNoOverflow(device, 'SearchScreen');
        cleanUp(tester);
      });

      testWidgets('search hint text visible', (tester) async {
        await pumpScreen(tester, device, const SearchScreen());
        expect(find.text('Search games...'), findsOneWidget);
        expectNoOverflow(device, 'SearchScreen');
        cleanUp(tester);
      });

      testWidgets('popular section visible', (tester) async {
        await pumpScreen(tester, device, const SearchScreen());
        expect(find.text('Popular'), findsOneWidget);
        expectNoOverflow(device, 'SearchScreen');
        cleanUp(tester);
      });

      testWidgets('can type in search field', (tester) async {
        await pumpScreen(tester, device, const SearchScreen());
        await tester.enterText(find.byType(TextField), 'flappy');
        await tester.pumpAndSettle();
        expectNoOverflow(device, 'SearchScreen');
        cleanUp(tester);
      });

      testWidgets('no results state works', (tester) async {
        await pumpScreen(tester, device, const SearchScreen());
        await tester.enterText(find.byType(TextField), 'zzzznonexistent');
        await tester.pumpAndSettle();
        expect(find.text('No games found'), findsOneWidget);
        expectNoOverflow(device, 'SearchScreen');
        cleanUp(tester);
      });
    });
  }
}
