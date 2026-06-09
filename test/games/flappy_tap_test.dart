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
      gameId: 'flappy_tap',
      child: GameRegistry.buildGame('flappy_tap'),
    );

void main() {
  group('Flappy Tap', () {
    setUp(() async => initTestDependencies());

    testWidgets('registry metadata is correct', (_) async {
      final game = GameRegistry.getById('flappy_tap')!;
      expect(game.id, 'flappy_tap');
      expect(game.name.isNotEmpty, isTrue);
      expect(game.howToPlay.isNotEmpty, isTrue);
      expect(game.category, isNotNull);
    });

    testWidgets('ready state shows Play button', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Play Flappy Tap'), findsOneWidget);
      expectNoOverflow(_device, 'Flappy Tap ready');
      cleanUp(tester);
    });

    testWidgets('difficulty picker shows default MEDIUM label', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('MEDIUM'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('ready state shows title', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Flappy Tap'), findsWidgets);
      cleanUp(tester);
    });

    testWidgets('tapping Play starts game', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Flappy Tap'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Play Flappy Tap'), findsNothing);
      expectNoOverflow(_device, 'Flappy Tap playing');
      cleanUp(tester);
    });

    testWidgets('playing state shows SCORE and BEST HUD', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Flappy Tap'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('SCORE'), findsOneWidget);
      expect(find.text('BEST'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('pause and resume works', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Flappy Tap'));
      await tester.pump(const Duration(milliseconds: 500));
      final state = tester.state<GameWrapperState>(find.byType(GameWrapper));
      state.pauseGame();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      await tester.tap(find.text('Resume'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Paused'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      cleanUp(tester);
    });

    testWidgets('pause overlay has Restart and Quit', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Flappy Tap'));
      await tester.pump(const Duration(milliseconds: 500));
      final state = tester.state<GameWrapperState>(find.byType(GameWrapper));
      state.pauseGame();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Quit'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      cleanUp(tester);
    });
  });
}
