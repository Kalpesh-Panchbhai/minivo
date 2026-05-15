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
  group('Drop Merge — ready state', () {
    setUp(() async => initTestDependencies());

    testWidgets('ready overlay shows Tap to Start', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Tap to Start'), findsOneWidget);
    });

    testWidgets('no HUD pause button visible in ready state', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });

    testWidgets('drop_merge is registered with a name and how-to-play text',
        (tester) async {
      final game = GameRegistry.getById('drop_merge')!;
      expect(game.id, 'drop_merge');
      expect(game.name.isNotEmpty, isTrue);
      expect(game.howToPlay.isNotEmpty, isTrue);
    });
  });
}
