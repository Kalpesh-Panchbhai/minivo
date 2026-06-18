import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/games/game_wrapper.dart';
import '../../lib/games/game_registry.dart';
import '../../lib/games/shared/spinning_slider.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/game_drivers.dart';

// ---------------------------------------------------------------------------
// PLAYING-STATE overflow for the two-player / AI board games.
//
// games_overflow_test maps these games' play button to 'Tap to Start', which
// they don't have — so it taps nothing and only ever exercises their READY
// (picker) state. Their actual board (the largest fixed grids in the app:
// Gomoku 13x13, Go 9x9, Reversi/Checkers 8x8, Connect Four 6x7, Mancala 14
// pits, Tic-Tac-Toe 3x3) was never overflow-swept in the playing state.
//
// This taps 'Play vs. AI' to build the live board and asserts no overflow on
// every supported device.
// ---------------------------------------------------------------------------

const _games = <List<String>>[
  ['checkers', 'Checkers'],
  ['connect_four', 'Connect Four'],
  ['go', 'Go'],
  ['gomoku', 'Gomoku'],
  ['mancala', 'Mancala'],
  ['reversi', 'Reversi'],
  ['tic_tac_toe', 'Tic Tac Toe'],
  ['dots_and_boxes', 'Dots and Boxes'],
];

void main() {
  for (final g in _games) {
    final gameId = g[0], name = g[1];
    final playText = gamePlayButton[gameId]!;
    for (final device in allTestDevices) {
      group('$name board on ${device.name} '
          '(${device.width}x${device.height})', () {
        setUp(() async {
          await initGameTest();
        });

        testWidgets('playing state renders without overflow', (tester) async {
          await pumpScreen(
            tester,
            device,
            GameWrapper(gameId: gameId, child: GameRegistry.buildGame(gameId)),
            settle: false,
          );
          await tapPlay(tester, playText);
          expect(find.byType(SpinningSlider), findsNothing,
              reason: '$name: still on picker; Play vs. AI did not start');
          await tester.pump(const Duration(milliseconds: 400));
          expectNoOverflow(device, '$name board');
          // AI may take a turn; let any first-move animation/scheduling run.
          await tester.pump(const Duration(milliseconds: 800));
          expectNoOverflow(device, '$name board (after first move)');
          cleanUp(tester);
        });
      });
    }
  }
}
