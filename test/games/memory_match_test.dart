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
      gameId: 'memory_match',
      child: GameRegistry.buildGame('memory_match'),
    );

void main() {
  group('Memory Match', () {
    setUp(() async => initTestDependencies());

    testWidgets('registry metadata is correct', (_) async {
      final game = GameRegistry.getById('memory_match')!;
      expect(game.id, 'memory_match');
      expect(game.name.isNotEmpty, isTrue);
      expect(game.howToPlay.isNotEmpty, isTrue);
      expect(game.category, isNotNull);
    });

    testWidgets('ready state shows mode picker', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Memory Match'), findsWidgets);
      expect(find.text('Play vs. AI'), findsOneWidget);
      expect(find.text('Play with a Friend'), findsOneWidget);
      expectNoOverflow(_device, 'Memory Match ready');
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
      expectNoOverflow(_device, 'Memory Match AI playing');
      await tester.pump(const Duration(seconds: 5));
      cleanUp(tester);
    });

    testWidgets('tapping Play with a Friend starts 2P game', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play with a Friend'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Play vs. AI'), findsNothing);
      expectNoOverflow(_device, 'Memory Match 2P playing');
      await tester.pump(const Duration(seconds: 5));
      cleanUp(tester);
    });

    testWidgets('AI mode shows player strips', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play vs. AI'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('You'), findsOneWidget);
      expect(find.text('AI'), findsWidgets);
      expectNoOverflow(_device, 'Memory Match AI strips');
      await tester.pump(const Duration(seconds: 5));
      cleanUp(tester);
    });

    testWidgets('2P mode shows P1 and P2 strips', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play with a Friend'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('P1'), findsWidgets);
      expect(find.text('P2'), findsWidgets);
      expectNoOverflow(_device, 'Memory Match 2P strips');
      await tester.pump(const Duration(seconds: 5));
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
      await tester.pump(const Duration(seconds: 5));
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
      await tester.pump(const Duration(seconds: 5));
      cleanUp(tester);
    });

    testWidgets('card grid renders without overflow', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play vs. AI'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GestureDetector), findsWidgets);
      expectNoOverflow(_device, 'Memory Match grid');
      await tester.pump(const Duration(seconds: 5));
      cleanUp(tester);
    });
  });
}
