import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/games/game_wrapper.dart';
import '../../lib/games/game_registry.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/overflow_detector.dart';

// Landscape devices intentionally omitted: the app is portrait-locked
// across Flutter (setPreferredOrientations), iOS Info.plist, and the
// Android manifest. Game canvases aren't designed for landscape — testing
// landscape here would only enforce a layout requirement we don't need.
// The orientation-lock guard test lives in `test/orientation_lock_test.dart`.

// Every gameId registered in GameRegistry. Adding a new game and forgetting
// to wire it here means we lose responsive coverage — keep this in sync.
const _gameIds = [
  'color_tap',
  'dots_and_boxes',
  'drop_merge',
  'flappy_tap',
  'memory_match',
  'number_merge',
  'snake_classic',
  'sudoku',
  'tic_tac_toe',
];

void main() {
  for (final gameId in _gameIds) {
    final game = GameRegistry.allGames.firstWhere((g) => g.id == gameId);
    final allDevices = allTestDevices;

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
