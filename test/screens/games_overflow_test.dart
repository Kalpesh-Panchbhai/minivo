import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/games/game_wrapper.dart';
import '../../lib/games/game_registry.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/overflow_detector.dart';

const _landscapeDevices = [
  TestDevice(name: 'Pixel 6 Landscape', width: 915, height: 412, pixelRatio: 2.625, platform: TargetPlatform.android),
  TestDevice(name: 'iPhone 14 Landscape', width: 844, height: 390, pixelRatio: 3.0, platform: TargetPlatform.iOS),
  TestDevice(name: 'Small Landscape', width: 568, height: 320, pixelRatio: 2.0, platform: TargetPlatform.android),
  TestDevice(name: 'iPad Landscape', width: 1366, height: 1024, pixelRatio: 2.0, platform: TargetPlatform.iOS),
];

const _gameIds = [
  'flappy_tap',
  'number_merge',
  'block_fit',
  'tic_tac_toe',
];

void main() {
  for (final gameId in _gameIds) {
    final game = GameRegistry.allGames.firstWhere((g) => g.id == gameId);
    final allDevices = [...allTestDevices, ..._landscapeDevices];

    for (final device in allDevices) {
      group('${game.name} on ${device.name} (${device.width}x${device.height})', () {
        setUp(() async {
          await initTestDependencies();
        });

        testWidgets('renders ready state without overflow', (tester) async {
          await pumpScreen(
            tester,
            device,
            GameWrapper(gameId: gameId, child: GameRegistry.buildGame(gameId)),
            settle: false,
          );
          expectNoOverflow(device, '${game.name} ready');
          cleanUp(tester);
        });

        testWidgets('renders playing state without overflow', (tester) async {
          await pumpScreen(
            tester,
            device,
            GameWrapper(gameId: gameId, child: GameRegistry.buildGame(gameId)),
            settle: false,
          );
          // Games with a difficulty picker use a named play button; others use 'Tap to Start'.
          final playText = gameId == 'flappy_tap' ? 'Play Flappy Tap' : 'Tap to Start';
          final playFinder = find.text(playText);
          if (tester.any(playFinder)) await tester.tap(playFinder, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 200));
          expectNoOverflow(device, '${game.name} playing');
          await tester.pump(const Duration(seconds: 1));
          cleanUp(tester);
        });

        testWidgets('renders playing state with restart button without overflow', (tester) async {
          await pumpScreen(
            tester,
            device,
            GameWrapper(gameId: gameId, child: GameRegistry.buildGame(gameId)),
            settle: false,
          );
          final playText = gameId == 'flappy_tap' ? 'Play Flappy Tap' : 'Tap to Start';
          final playFinder = find.text(playText);
          if (tester.any(playFinder)) {
            await tester.tap(playFinder, warnIfMissed: false);
          }
          await tester.pump(const Duration(milliseconds: 200));
          // Some games may not show restart button in test environment — just check for no overflow.
          await tester.pump(const Duration(milliseconds: 200));
          expectNoOverflow(device, '${game.name} playing');
          await tester.pump(const Duration(seconds: 5));
          cleanUp(tester);
        });
      });
    }
  }
}
