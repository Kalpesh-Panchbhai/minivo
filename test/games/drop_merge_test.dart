import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/games/game_registry.dart';
import '../../lib/games/game_wrapper.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

// Drop Merge uses long-running drag gesture timers and shape-spawn animations
// that don't drain under fake-async time. Deep gameplay interaction is
// covered by overflow regression in `test/screens/games_overflow_test.dart`;
// this file pins the deterministic ready-state surface area.

const _device = TestDevice(
  name: 'Pixel 6',
  width: 412,
  height: 915,
  pixelRatio: 2.625,
  platform: TargetPlatform.android,
);

Widget _build() => GameWrapper(
      gameId: 'drop_merge',
      child: GameRegistry.buildGame('drop_merge'),
    );

void main() {
  group('Drop Merge', () {
    setUp(() async => initTestDependencies());

    testWidgets('registry metadata is correct', (_) async {
      final game = GameRegistry.getById('drop_merge')!;
      expect(game.id, 'drop_merge');
      expect(game.name.isNotEmpty, isTrue);
      expect(game.howToPlay.isNotEmpty, isTrue);
      expect(game.category, isNotNull);
    });

    testWidgets('ready state shows Play button', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Play Drop Merge'), findsOneWidget);
      expectNoOverflow(_device, 'Drop Merge ready');
      cleanUp(tester);
    });

    testWidgets('difficulty picker shows default MEDIUM label', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('MEDIUM'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('tapping Play starts game', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Drop Merge'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Play Drop Merge'), findsNothing);
      expectNoOverflow(_device, 'Drop Merge playing');
      await tester.pump(const Duration(seconds: 5));
      cleanUp(tester);
    });

    testWidgets('playing state shows DROP label and score', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Drop Merge'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('DROP'), findsOneWidget);
      expect(find.text('0'), findsWidgets);
      await tester.pump(const Duration(seconds: 5));
      cleanUp(tester);
    });

    testWidgets('pause and resume works', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Drop Merge'));
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
      await tester.tap(find.text('Play Drop Merge'));
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
