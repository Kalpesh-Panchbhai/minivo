import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/games/game_wrapper.dart';
import '../../lib/games/game_registry.dart';
import '../../lib/games/shared/spinning_slider.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/game_drivers.dart';

// ---------------------------------------------------------------------------
// DIFFICULTY-SWEEP overflow.
//
// games_overflow_test covers the DEFAULT difficulty; max_board_overflow_test
// covers HARD. This fills the middle: it plays EVERY difficulty stop of each
// board-size-varying game so a regression on the EASY/MEDIUM board (different
// grid dims, label widths, key counts) can't slip through. Run on the device
// extremes that historically expose layout breaks: smallest phone, short iOS
// phone, wide-short foldable, and the largest tablet.
// ---------------------------------------------------------------------------

const _devices = [
  TestDevice(
      name: 'Small Android (320x568)',
      width: 320,
      height: 568,
      pixelRatio: 2.0,
      platform: TargetPlatform.android),
  TestDevice(
      name: 'iPhone SE 3rd (375x667)',
      width: 375,
      height: 667,
      pixelRatio: 2.0,
      platform: TargetPlatform.iOS),
  TestDevice(
      name: 'Pixel Fold open (841x701)',
      width: 841,
      height: 701,
      pixelRatio: 2.0,
      platform: TargetPlatform.android),
  TestDevice(
      name: 'iPad Pro 12.9 (1024x1366)',
      width: 1024,
      height: 1366,
      pixelRatio: 2.0,
      platform: TargetPlatform.iOS),
];

// gameId -> (name, playText). 3-stop difficulty pickers where the board
// geometry differs per difficulty.
const _games = <List<String>>[
  ['minesweeper', 'Minesweeper', 'Play Minesweeper'], // 9x9 / 16x16 / 16x30
  ['memory_match', 'Memory Match', 'Play vs. AI'], // 4x4 / 5x4 / 6x4
  ['sliding_puzzle', 'Sliding Puzzle', 'Play Sliding Puzzle'], // 3x3 / 4x4 / 5x5
  ['number_sequence', 'Number Sequence', 'Play Number Sequence'], // 25 / 50 / 100
  ['dots_and_boxes', 'Dots and Boxes', 'Play vs. AI'], // 4x4 / 5x5 / 6x6
  ['hangman', 'Hangman', 'Play Hangman'], // word-length tiers
  ['queens_puzzle', 'Queens Puzzle', 'Play Queens'], // 5x5 / 6x6 / 7x7 at level 1
  ['tango', 'Tango', 'Play Tango'], // 4x4 / 6x6 / 6x6 fewer clues
  ['block_escape', 'Block Escape', 'Play Block Escape'], // 6x6 all, block count varies
];

const _diffNames = ['EASY', 'MEDIUM', 'HARD'];

void main() {
  for (final g in _games) {
    final gameId = g[0], name = g[1], playText = g[2];
    for (int stop = 0; stop < 3; stop++) {
      for (final device in _devices) {
        group('$name ${_diffNames[stop]} on ${device.name}', () {
          setUp(() async {
            await initGameTest();
          });

          testWidgets('plays without overflow', (tester) async {
            await pumpScreen(
              tester,
              device,
              GameWrapper(gameId: gameId, child: GameRegistry.buildGame(gameId)),
              settle: false,
            );
            await selectDifficultyStop(tester, stop);
            await tapPlay(tester, playText);
            expect(find.byType(SpinningSlider), findsNothing,
                reason: '$name ${_diffNames[stop]}: still on picker');
            await tester.pump(const Duration(milliseconds: 400));
            expectNoOverflow(device, '$name ${_diffNames[stop]}');
            await tester.pump(const Duration(milliseconds: 500));
            expectNoOverflow(device, '$name ${_diffNames[stop]} (settled)');
            cleanUp(tester);
          });
        });
      }
    }
  }
}
