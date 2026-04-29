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
  group('Flappy Tap ready-state', () {
    setUp(() async => initTestDependencies());

    testWidgets('ready overlay shows Tap to Start', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Tap to Start'), findsOneWidget);
      expect(find.byIcon(Icons.touch_app_rounded), findsOneWidget);
    });

    testWidgets('ready state has no HUD pause button', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });

    testWidgets('registry metadata is non-empty', (_) async {
      final game = GameRegistry.getById('flappy_tap')!;
      expect(game.id, 'flappy_tap');
      expect(game.name.isNotEmpty, isTrue);
      expect(game.howToPlay.isNotEmpty, isTrue);
    });
  });
}
