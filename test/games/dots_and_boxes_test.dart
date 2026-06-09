import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/games/game_registry.dart';
import '../../lib/games/game_wrapper.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

const _device = TestDevice(
  name: 'Pixel 6',
  width: 412,
  height: 915,
  pixelRatio: 2.625,
  platform: TargetPlatform.android,
);

Widget _build() => GameWrapper(
      gameId: 'dots_and_boxes',
      child: GameRegistry.buildGame('dots_and_boxes'),
    );

void main() {
  group('Dots & Boxes', () {
    setUp(() async => initTestDependencies());

    testWidgets('registry metadata is correct', (_) async {
      final game = GameRegistry.getById('dots_and_boxes')!;
      expect(game.id, 'dots_and_boxes');
      expect(game.name.isNotEmpty, isTrue);
      expect(game.howToPlay.isNotEmpty, isTrue);
      expect(game.category, isNotNull);
    });

    testWidgets('ready state shows mode picker', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Dots & Boxes'), findsWidgets);
      expect(find.text('Play vs. AI'), findsOneWidget);
      expect(find.text('Play with a Friend'), findsOneWidget);
      expectNoOverflow(_device, 'Dots & Boxes ready');
      cleanUp(tester);
    });

    testWidgets('difficulty picker shows default MEDIUM label', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('MEDIUM'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('tapping Play vs. AI starts game', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play vs. AI'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Play vs. AI'), findsNothing);
      expect(find.text('Play with a Friend'), findsNothing);
      expectNoOverflow(_device, 'Dots & Boxes AI playing');
      cleanUp(tester);
    });

    testWidgets('tapping Play with a Friend starts 2P game', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play with a Friend'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Play vs. AI'), findsNothing);
      expect(find.text('Play with a Friend'), findsNothing);
      expectNoOverflow(_device, 'Dots & Boxes 2P playing');
      cleanUp(tester);
    });

    testWidgets('AI mode shows player strips', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play vs. AI'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('You'), findsOneWidget);
      expect(find.text('AI'), findsWidgets);
      expectNoOverflow(_device, 'Dots & Boxes AI strips');
      cleanUp(tester);
    });

    testWidgets('2P mode shows P1 and P2 strips', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play with a Friend'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('P1'), findsWidgets);
      expect(find.text('P2'), findsWidgets);
      expectNoOverflow(_device, 'Dots & Boxes 2P strips');
      cleanUp(tester);
    });

    testWidgets('pause and resume works in AI mode', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play vs. AI'));
      await tester.pump(const Duration(milliseconds: 500));
      final state = tester.state<GameWrapperState>(find.byType(GameWrapper));
      state.pauseGame();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Quit'), findsOneWidget);
      await tester.tap(find.text('Resume'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Paused'), findsNothing);
      cleanUp(tester);
    });

    testWidgets('pause and resume works in 2P mode', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play with a Friend'));
      await tester.pump(const Duration(milliseconds: 500));
      final state = tester.state<GameWrapperState>(find.byType(GameWrapper));
      state.pauseGame();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Paused'), findsOneWidget);
      await tester.tap(find.text('Resume'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Paused'), findsNothing);
      cleanUp(tester);
    });

    testWidgets('board renders without overflow in AI mode', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play vs. AI'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GestureDetector), findsWidgets);
      expectNoOverflow(_device, 'Dots & Boxes board AI');
      cleanUp(tester);
    });

    testWidgets('board renders without overflow in 2P mode', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play with a Friend'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GestureDetector), findsWidgets);
      expectNoOverflow(_device, 'Dots & Boxes board 2P');
      cleanUp(tester);
    });
  });
}
