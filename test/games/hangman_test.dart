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
      gameId: 'hangman',
      child: GameRegistry.buildGame('hangman'),
    );

void main() {
  group('Hangman', () {
    setUp(() async => initTestDependencies());

    testWidgets('registry metadata is correct', (_) async {
      final game = GameRegistry.getById('hangman')!;
      expect(game.id, 'hangman');
      expect(game.name.isNotEmpty, isTrue);
      expect(game.howToPlay.isNotEmpty, isTrue);
      expect(game.category, isNotNull);
    });

    testWidgets('ready state shows picker with title', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Hangman'), findsWidgets);
      expect(find.text('Play Hangman'), findsOneWidget);
      expectNoOverflow(_device, 'Hangman ready');
      cleanUp(tester);
    });

    testWidgets('difficulty picker shows default MEDIUM label', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('MEDIUM'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('play button renders without overflow', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Play Hangman'), findsOneWidget);
      expectNoOverflow(_device, 'Hangman play button');
      cleanUp(tester);
    });

    testWidgets('tapping Play Hangman starts game', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Hangman'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Play Hangman'), findsNothing);
      expectNoOverflow(_device, 'Hangman playing');
      cleanUp(tester);
    });

    testWidgets('pause overlay shows correct elements', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      final wrapperState = tester.state<GameWrapperState>(find.byType(GameWrapper));
      wrapperState.startGame();
      await tester.pump(const Duration(milliseconds: 300));
      wrapperState.pauseGame();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Quit'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      cleanUp(tester);
    });
  });
}
