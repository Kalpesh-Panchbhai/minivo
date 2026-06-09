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
      gameId: 'whack_a_mole',
      child: GameRegistry.buildGame('whack_a_mole'),
    );

void main() {
  group('Whack-a-Mole', () {
    setUp(() async => initTestDependencies());

    testWidgets('registry metadata is correct', (_) async {
      final game = GameRegistry.getById('whack_a_mole')!;
      expect(game.id, 'whack_a_mole');
      expect(game.name.isNotEmpty, isTrue);
      expect(game.howToPlay.isNotEmpty, isTrue);
      expect(game.category, isNotNull);
    });

    testWidgets('ready state shows picker with title', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Play Whack-a-Mole'), findsOneWidget);
      expectNoOverflow(_device, 'Whack-a-Mole ready');
      cleanUp(tester);
    });

    testWidgets('difficulty picker shows default MEDIUM label', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('MEDIUM'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('tapping Play starts game', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Whack-a-Mole'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Play Whack-a-Mole'), findsNothing);
      expectNoOverflow(_device, 'Whack-a-Mole playing');
      cleanUp(tester);
    });

    testWidgets('playing state shows SCORE, BEST, and TIME HUD', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Whack-a-Mole'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('SCORE'), findsOneWidget);
      expect(find.text('BEST'), findsOneWidget);
      expect(find.text('TIME'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('pause and resume works', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Whack-a-Mole'));
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
      await tester.tap(find.text('Play Whack-a-Mole'));
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

    testWidgets('ready state shows game title', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Whack-a-Mole'), findsWidgets);
      cleanUp(tester);
    });

  });
}
