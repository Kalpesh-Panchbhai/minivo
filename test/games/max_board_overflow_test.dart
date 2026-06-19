import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/games/game_wrapper.dart';
import '../../lib/games/game_registry.dart';
import '../../lib/games/shared/spinning_slider.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/game_drivers.dart';

// ---------------------------------------------------------------------------
// MAX-BOARD overflow sweep.
//
// games_overflow_test.dart already proves every game renders at its DEFAULT
// difficulty / level 1. The remaining prod risk is the DENSEST board a game
// can ever produce: HARD difficulty for difficulty-scaled games, plus the
// highest grid for level-scaled games (zip, water_sort, arrow_puzzle). Those
// boards are biggest and the layout has the least slack — exactly where small
// devices overflow.
//
// This sweep drives every board-size-varying game to its single densest
// render and asserts no overflow on ALL supported devices (iOS + Android,
// 320x568 phone up to 1024x1366 iPad).
// ---------------------------------------------------------------------------

class _MaxConfig {
  final String gameId;
  final String name;

  /// Difficulty stop to select on the SpinningSlider (2 == HARD for the
  /// 3-stop pickers; the densest board for every game in this list).
  final int stopIndex;

  /// Exact play-button label to tap once the difficulty is selected.
  final String playText;

  /// Extra SharedPreferences to seed before pump — used by level-scaled games
  /// to start directly on the level that yields the largest grid.
  final Map<String, Object> levelPrefs;

  const _MaxConfig({
    required this.gameId,
    required this.name,
    required this.playText,
    this.stopIndex = 2,
    this.levelPrefs = const {},
  });
}

// The densest config per board-size-varying game (from the render matrix).
final _configs = <_MaxConfig>[
  // Level-scaled: seed the level that maxes out the grid.
  _MaxConfig(
    gameId: 'zip',
    name: 'Zip',
    playText: 'Play Zip',
    levelPrefs: {levelCurrentKey('zip', 'hard'): 13}, // -> 9x9
  ),
  _MaxConfig(
    gameId: 'water_sort',
    name: 'Water Sort',
    playText: 'Play Water Sort',
    levelPrefs: {levelCurrentKey('water_sort', 'hard'): 11}, // -> 14 colors / 17 tubes
  ),
  _MaxConfig(
    gameId: 'arrow_puzzle',
    name: 'Arrow Puzzle',
    playText: 'Play Arrow Puzzle',
    levelPrefs: {levelCurrentKey('arrow_puzzle', 'hard'): 8365}, // -> full 12x13, 41 arrows
  ),
  _MaxConfig(
    gameId: 'queens_puzzle',
    name: 'Queens Puzzle',
    playText: 'Play Queens',
    levelPrefs: {levelCurrentKey('queens_puzzle', 'hard'): 6}, // -> 8x8 (largest board)
  ),
  const _MaxConfig(
    gameId: 'tango',
    name: 'Tango',
    playText: 'Play Tango',
  ), // -> 6x6 hard (densest clue layout)
  // Difficulty-scaled: HARD is the biggest board.
  const _MaxConfig(
    gameId: 'minesweeper',
    name: 'Minesweeper',
    playText: 'Play Minesweeper',
  ), // -> 16x30, 99 mines
  const _MaxConfig(
    gameId: 'memory_match',
    name: 'Memory Match',
    playText: 'Play vs. AI',
  ), // -> 6x4 = 24 cards
  const _MaxConfig(
    gameId: 'sliding_puzzle',
    name: 'Sliding Puzzle',
    playText: 'Play Sliding Puzzle',
  ), // -> 5x5
  const _MaxConfig(
    gameId: 'number_sequence',
    name: 'Number Sequence',
    playText: 'Play Number Sequence',
  ), // -> 100 bubbles
  const _MaxConfig(
    gameId: 'dots_and_boxes',
    name: 'Dots and Boxes',
    playText: 'Play vs. AI',
  ), // -> 6x6 boxes
  const _MaxConfig(
    gameId: 'hangman',
    name: 'Hangman',
    playText: 'Play Hangman',
  ), // -> longest words / 26-key keyboard
];

void main() {
  for (final cfg in _configs) {
    for (final device in allTestDevices) {
      group('${cfg.name} MAX board on ${device.name} '
          '(${device.width}x${device.height})', () {
        setUp(() async {
          await initGameTest(extra: cfg.levelPrefs);
        });

        testWidgets('densest render has no overflow', (tester) async {
          await pumpScreen(
            tester,
            device,
            GameWrapper(
              gameId: cfg.gameId,
              child: GameRegistry.buildGame(cfg.gameId),
            ),
            settle: false,
          );

          await selectDifficultyStop(tester, cfg.stopIndex);
          await tapPlay(tester, cfg.playText);

          // We must have left the picker — otherwise the densest board never
          // rendered and the no-overflow result is meaningless.
          expect(
            find.byType(SpinningSlider),
            findsNothing,
            reason: '${cfg.name}: still on picker; play did not start',
          );

          // Let the first playing frames build (staggered intro animations).
          await tester.pump(const Duration(milliseconds: 400));
          expectNoOverflow(device, '${cfg.name} MAX board');
          await tester.pump(const Duration(milliseconds: 600));
          expectNoOverflow(device, '${cfg.name} MAX board (settled)');
          cleanUp(tester);
        });
      });
    }
  }
}
