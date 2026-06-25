import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/games/game_wrapper.dart';
import '../../lib/games/game_registry.dart';
import '../../lib/games/shared/spinning_slider.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/game_drivers.dart';

// ---------------------------------------------------------------------------
// LEVEL-BOUNDARY overflow.
//
// The three level-scaled games (zip, water_sort, arrow_puzzle) change grid
// dimensions at specific level thresholds, then wrap every 10,000 levels.
// max_board_overflow_test pins the single densest level; this renders a level
// SPREAD that crosses every grid-size transition (and a wrapped high level)
// so NO reachable board size on the progression can overflow.
//
// We drive HARD only: HARD has the widest grid range of each game (it
// reaches the global max), so a HARD board that fits guarantees the smaller
// EASY/MEDIUM boards fit too.
// ---------------------------------------------------------------------------

const _devices = [
  TestDevice(
      name: 'Small Android (320x568)',
      width: 320,
      height: 568,
      pixelRatio: 2.0,
      platform: TargetPlatform.android),
  TestDevice(
      name: 'iPhone 13 (390x844)',
      width: 390,
      height: 844,
      pixelRatio: 3.0,
      platform: TargetPlatform.iOS),
  TestDevice(
      name: 'iPad Pro 12.9 (1024x1366)',
      width: 1024,
      height: 1366,
      pixelRatio: 2.0,
      platform: TargetPlatform.iOS),
];

class _LevelGame {
  final String gameId;
  final String name;
  final String playText;
  final List<int> levels;
  const _LevelGame(this.gameId, this.name, this.playText, this.levels);
}

const _games = <_LevelGame>[
  // Hard grid: 7 (<=5) / 8 (<=12) / 9 (else); +wrapped.
  _LevelGame('zip', 'Zip', 'Play Zip', [1, 5, 6, 12, 13, 100, 5000, 9999, 10013]),
  // Hard colours ramp to 14 (>=11); +wrapped.
  _LevelGame('water_sort', 'Water Sort', 'Play Water Sort',
      [1, 3, 6, 11, 50, 9999, 10011]),
  // Hard box grows to 12x13 (eff>=7); densest rectangle at 19 / 8365; +wrapped.
  _LevelGame('arrow_puzzle', 'Arrow Puzzle', 'Play Arrow Puzzle',
      [1, 3, 7, 19, 100, 8365, 9999, 18365]),
  // Fixed 7x7 box, but every level is a different irregular shape; spread +
  // a wrapped level so no shape on the progression overflows.
  _LevelGame('maze_paint', 'Maze Paint', 'Play Maze Paint',
      [1, 100, 5000, 9999, 10001]),
  _LevelGame('block_escape', 'Block Escape', 'Play Block Escape',
      [1, 50, 500, 5000, 9999, 10001]),
];

void main() {
  for (final g in _games) {
    for (final level in g.levels) {
      for (final device in _devices) {
        group('${g.name} HARD level $level on ${device.name}', () {
          setUp(() async {
            await initGameTest(
                extra: {levelCurrentKey(g.gameId, 'hard'): level});
          });

          testWidgets('renders without overflow', (tester) async {
            await pumpScreen(
              tester,
              device,
              GameWrapper(
                  gameId: g.gameId, child: GameRegistry.buildGame(g.gameId)),
              settle: false,
            );
            await selectDifficultyStop(tester, 2); // HARD
            await tapPlay(tester, g.playText);
            expect(find.byType(SpinningSlider), findsNothing,
                reason: '${g.name} L$level: still on picker');
            await tester.pump(const Duration(milliseconds: 400));
            expectNoOverflow(device, '${g.name} HARD L$level');
            cleanUp(tester);
          });
        });
      }
    }
  }
}
