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
      gameId: 'sliding_puzzle',
      child: GameRegistry.buildGame('sliding_puzzle'),
    );

void main() {
  group('Sliding Puzzle', () {
    setUp(() async => initTestDependencies());

    testWidgets('registry metadata is correct', (_) async {
      final game = GameRegistry.getById('sliding_puzzle')!;
      expect(game.id, 'sliding_puzzle');
      expect(game.name.isNotEmpty, isTrue);
      expect(game.howToPlay.isNotEmpty, isTrue);
      expect(game.category, isNotNull);
    });

    testWidgets('ready state shows picker with title', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Sliding Puzzle'), findsWidgets);
      expect(find.text('Play Sliding Puzzle'), findsOneWidget);
      expectNoOverflow(_device, 'Sliding Puzzle ready');
      cleanUp(tester);
    });

    testWidgets('shows theme picker', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Numbers'), findsOneWidget);
      expect(find.text('Animals'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('shows grid size options', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('4×4'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('tapping Play starts game', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Sliding Puzzle'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Play Sliding Puzzle'), findsNothing);
      expect(find.textContaining('Moves:'), findsOneWidget);
      expectNoOverflow(_device, 'Sliding Puzzle playing');
      cleanUp(tester);
    });

    testWidgets('pause and resume works', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Sliding Puzzle'));
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
      await tester.tap(find.text('Play Sliding Puzzle'));
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
