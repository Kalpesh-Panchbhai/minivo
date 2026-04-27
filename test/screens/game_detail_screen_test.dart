import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/features/game_detail/game_detail_screen.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/overflow_detector.dart';

void main() {
  for (final device in allTestDevices) {
    group('GameDetailScreen on ${device.name} (${device.width}x${device.height})', () {
      setUp(() async {
        await initTestDependencies();
      });

      testWidgets('renders without overflow', (tester) async {
        await pumpScreen(tester, device, const GameDetailScreen(gameId: 'flappy_tap'));
        expectNoOverflow(device, 'GameDetailScreen');
        cleanUp(tester);
      });

      testWidgets('game name is visible', (tester) async {
        await pumpScreen(tester, device, const GameDetailScreen(gameId: 'flappy_tap'));
        expect(find.text('Flappy Tap'), findsWidgets);
        expectNoOverflow(device, 'GameDetailScreen');
        cleanUp(tester);
      });

      testWidgets('play now button visible', (tester) async {
        await pumpScreen(tester, device, const GameDetailScreen(gameId: 'flappy_tap'));
        expect(find.text('Play Now'), findsOneWidget);
        expectNoOverflow(device, 'GameDetailScreen');
        cleanUp(tester);
      });

      testWidgets('play button meets min tap target', (tester) async {
        await pumpScreen(tester, device, const GameDetailScreen(gameId: 'flappy_tap'));
        expect(find.text('Play Now'), findsOneWidget);
        final btn = find.widgetWithText(ElevatedButton, 'Play Now');
        if (btn.evaluate().isNotEmpty) {
          final size = tester.getSize(btn);
          expect(size.height, greaterThanOrEqualTo(44));
        }
        expectNoOverflow(device, 'GameDetailScreen');
        cleanUp(tester);
      });

      testWidgets('how to play section visible', (tester) async {
        await pumpScreen(tester, device, const GameDetailScreen(gameId: 'flappy_tap'));
        final scrollable = find.byType(Scrollable).first;
        await tester.drag(scrollable, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(find.text('How to Play'), findsOneWidget);
        expectNoOverflow(device, 'GameDetailScreen');
        cleanUp(tester);
      });

      testWidgets('similar games section visible', (tester) async {
        await pumpScreen(tester, device, const GameDetailScreen(gameId: 'flappy_tap'));
        final scrollable = find.byType(Scrollable).first;
        await tester.drag(scrollable, const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(find.text('Similar Games'), findsOneWidget);
        expectNoOverflow(device, 'GameDetailScreen');
        cleanUp(tester);
      });

      testWidgets('favorite button visible', (tester) async {
        await pumpScreen(tester, device, const GameDetailScreen(gameId: 'flappy_tap'));
        expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
        expectNoOverflow(device, 'GameDetailScreen');
        cleanUp(tester);
      });

      testWidgets('back button visible', (tester) async {
        await pumpScreen(tester, device, const GameDetailScreen(gameId: 'flappy_tap'));
        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
        expectNoOverflow(device, 'GameDetailScreen');
        cleanUp(tester);
      });

      testWidgets('can scroll full page without overflow', (tester) async {
        await pumpScreen(tester, device, const GameDetailScreen(gameId: 'flappy_tap'));
        final scrollable = find.byType(Scrollable).first;
        await tester.drag(scrollable, const Offset(0, -800));
        await tester.pumpAndSettle();
        expectNoOverflow(device, 'GameDetailScreen');
        cleanUp(tester);
      });

      testWidgets('number_merge game renders without overflow', (tester) async {
        await pumpScreen(tester, device, const GameDetailScreen(gameId: 'number_merge'));
        expectNoOverflow(device, 'GameDetailScreen');
        cleanUp(tester);
      });

      testWidgets('block_fit game renders without overflow', (tester) async {
        await pumpScreen(tester, device, const GameDetailScreen(gameId: 'block_fit'));
        expectNoOverflow(device, 'GameDetailScreen');
        cleanUp(tester);
      });
    });
  }
}
