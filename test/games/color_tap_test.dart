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
      gameId: 'color_tap',
      child: GameRegistry.buildGame('color_tap'),
    );

void main() {
  group('Color Tap', () {
    setUp(() async => initTestDependencies());

    testWidgets('registry metadata is correct', (_) async {
      final game = GameRegistry.getById('color_tap')!;
      expect(game.id, 'color_tap');
      expect(game.name.isNotEmpty, isTrue);
      expect(game.howToPlay.isNotEmpty, isTrue);
      expect(game.category, isNotNull);
    });

    testWidgets('ready state shows picker with title', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Color Tap'), findsWidgets);
      expect(find.text('Play Color Tap'), findsOneWidget);
      expectNoOverflow(_device, 'Color Tap ready');
      cleanUp(tester);
    });

    testWidgets('difficulty picker shows default MEDIUM label', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('MEDIUM'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('tapping Play starts game', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Color Tap'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Play Color Tap'), findsNothing);
      expect(find.text('SCORE'), findsOneWidget);
      expectNoOverflow(_device, 'Color Tap playing');
      cleanUp(tester);
    });

    testWidgets('playing state shows target color label', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Color Tap'));
      await tester.pump(const Duration(milliseconds: 500));
      final targetFinder = find.textContaining('TAP IF:');
      expect(targetFinder, findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('playing state shows lives', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Color Tap'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('LIVES'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
      cleanUp(tester);
    });

    testWidgets('playing state shows SKIP button', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Color Tap'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('SKIP'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('playing state shows BEST HUD', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Color Tap'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('BEST'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('pause and resume works', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Color Tap'));
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
      await tester.pump(const Duration(seconds: 5));
      cleanUp(tester);
    });

    testWidgets('pause overlay shows correct icons', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Color Tap'));
      await tester.pump(const Duration(milliseconds: 500));
      final state = tester.state<GameWrapperState>(find.byType(GameWrapper));
      state.pauseGame();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
      expect(find.byIcon(Icons.refresh_rounded), findsWidgets);
      expect(find.byIcon(Icons.home_rounded), findsWidgets);
      await tester.pump(const Duration(seconds: 5));
      cleanUp(tester);
    });

  });
}
