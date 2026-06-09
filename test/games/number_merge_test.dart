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
      gameId: 'number_merge',
      child: GameRegistry.buildGame('number_merge'),
    );

Future<void> _start(WidgetTester tester) async {
  await tester.tap(find.text('Play Classic'));
  await tester.pump(const Duration(milliseconds: 500));
}

Finder _board() {
  return find.byType(GestureDetector).first;
}

void main() {
  group('Number Merge — gameplay', () {
    setUp(() async => initTestDependencies());

    testWidgets('ready state shows Play button', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Play Classic'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('difficulty picker shows default MEDIUM label', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('MEDIUM'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('start transitions to playing', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await _start(tester);
      expect(find.text('Play Classic'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      cleanUp(tester);
    });

    testWidgets('swipe gesture does not crash and keeps game playing',
        (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await _start(tester);

      final center = tester.getCenter(_board());
      await tester.dragFrom(center, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Game Over'), findsNothing);
      cleanUp(tester);
    });

    testWidgets('pause + resume works mid-game', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await _start(tester);
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

    testWidgets('multiple swipes do not produce overflow or exceptions',
        (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await _start(tester);

      final center = tester.getCenter(_board());
      for (final dir in <Offset>[
        const Offset(0, -300),
        const Offset(300, 0),
        const Offset(0, 300),
        const Offset(-300, 0),
      ]) {
        await tester.dragFrom(center, dir);
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
      cleanUp(tester);
    });

    testWidgets('registry metadata is correct', (_) async {
      final game = GameRegistry.getById('number_merge')!;
      expect(game.id, 'number_merge');
      expect(game.name.isNotEmpty, isTrue);
      expect(game.howToPlay.isNotEmpty, isTrue);
    });
  });
}
