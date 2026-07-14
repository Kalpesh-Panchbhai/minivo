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
      gameId: 'frame_rush',
      child: GameRegistry.buildGame('frame_rush'),
    );

void main() {
  group('Frame Rush', () {
    setUp(() async => initTestDependencies());

    testWidgets('registry metadata is correct', (_) async {
      final game = GameRegistry.getById('frame_rush')!;
      expect(game.id, 'frame_rush');
      expect(game.name, 'Frame Rush');
      expect(game.howToPlay.isNotEmpty, isTrue);
      expect(game.category, isNotNull);
    });

    testWidgets('ready state shows game title', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Frame Rush'), findsWidgets);
      cleanUp(tester);
    });

    testWidgets('ready state shows Play button without overflow', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Play Frame Rush'), findsOneWidget);
      expectNoOverflow(_device, 'Frame Rush ready');
      cleanUp(tester);
    });

    testWidgets('difficulty picker shows default MEDIUM label', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('MEDIUM'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('starting a game shows the level HUD without overflow',
        (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Frame Rush'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('LEVEL'), findsWidgets);
      expectNoOverflow(_device, 'Frame Rush playing');
      // advance the loop a little; the object should keep animating smoothly.
      await tester.pump(const Duration(milliseconds: 400));
      expectNoOverflow(_device, 'Frame Rush playing (later frame)');
      cleanUp(tester);
    });

    testWidgets('slow-mo rewarded button appears during play', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Frame Rush'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('SLOW-MO'), findsOneWidget);
      expect(find.text('AD'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('shows the "slow it down" nudge after the idle timer without overflow',
        (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Frame Rush'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Too fast? Slow it down!'), findsNothing);
      // Advance past the 15s stuck timer (no board taps → no random win).
      await tester.pump(const Duration(seconds: 16));
      expect(find.text('Too fast? Slow it down!'), findsOneWidget);
      expectNoOverflow(_device, 'Frame Rush stuck nudge');
      cleanUp(tester);
    });

    testWidgets('pause overlay shows correct elements', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      final wrapperState =
          tester.state<GameWrapperState>(find.byType(GameWrapper));
      wrapperState.startGame();
      await tester.pump(const Duration(milliseconds: 300));
      wrapperState.pauseGame();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Quit'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      cleanUp(tester);
    });
  });
}
