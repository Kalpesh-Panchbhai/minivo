import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/games/game_registry.dart';
import '../../lib/games/game_wrapper.dart';
import '../../lib/games/shared/spinning_slider.dart';

import '../helpers/game_drivers.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

// Queens-specific responsive coverage that complements the shared sweeps:
//   - games_overflow_test         : picker + default difficulty, every device
//   - difficulty_sweep_overflow   : every difficulty at level 1 (5×5/6×6/7×7)
//   - max_board_overflow          : densest board (hard 8×8), every device
//
// This file adds two things those generic sweeps can't:
//   1. A correctness assertion that the EXPECTED board size is actually
//      generated per difficulty (the QUEENS pill reads "0/<boardSize>"), at the
//      LARGEST board each difficulty can show, across every supported device on
//      both iOS and Android.
//   2. Coverage of the queens-specific dynamic UI states (hint applied, the
//      "stuck" idle nudge) that only appear mid-game.

const _gameId = 'queens_puzzle';

// (difficulty stop index, sub-key, level forcing the largest board, board size)
const _bands = [
  (0, 'easy', 1, 5),
  (1, 'medium', 9, 7),
  (2, 'hard', 6, 8),
];

Widget _build() =>
    GameWrapper(gameId: _gameId, child: GameRegistry.buildGame(_gameId));

// Seed each difficulty onto the level that yields its largest board.
Map<String, Object> _levelPrefs() => {
      for (final b in _bands) levelCurrentKey(_gameId, b.$2): b.$3,
    };

void main() {
  group('Queens Puzzle largest-board render per difficulty', () {
    for (final device in allTestDevices) {
      for (final band in _bands) {
        final stopIndex = band.$1;
        final subKey = band.$2;
        final boardSize = band.$4;

        group('${device.name} (${device.width}x${device.height}, '
            '${device.platform.name})', () {
          setUp(() async => initGameTest(extra: _levelPrefs()));

          testWidgets('$subKey $boardSize×$boardSize grid plays without overflow',
              (tester) async {
            await pumpScreen(tester, device, _build(), settle: false);
            await selectAndPlay(tester, stopIndex, 'Play Queens');

            // Must have left the picker — else gameplay never rendered.
            expect(find.byType(SpinningSlider), findsNothing,
                reason: 'queens $subKey: still on picker, play did not start');

            // The QUEENS pill reads "0/<boardSize>" at start — confirms the
            // expected (largest) board for this difficulty was generated.
            expect(find.text('LEVEL'), findsOneWidget);
            expect(find.text('0/$boardSize'), findsOneWidget);

            expectNoOverflow(device, 'Queens $subKey $boardSize×$boardSize');
            await tester.pump(const Duration(seconds: 1));
            expectNoOverflow(device, 'Queens $subKey $boardSize×$boardSize (settled)');
            cleanUp(tester);
          });
        });
      }
    }
  });

  // Dynamic mid-game UI states, exercised on the smallest screen (320×568,
  // both platforms) where overflow is most likely.
  const tightDevices = [
    TestDevice(
        name: 'Small Android',
        width: 320,
        height: 568,
        pixelRatio: 2.0,
        platform: TargetPlatform.android),
    TestDevice(
        name: 'iPhone SE 1st gen',
        width: 320,
        height: 568,
        pixelRatio: 2.0,
        platform: TargetPlatform.iOS),
  ];

  group('Queens Puzzle dynamic states', () {
    for (final device in tightDevices) {
      group('${device.name} (${device.platform.name})', () {
        setUp(() async => initGameTest(extra: _levelPrefs()));

        testWidgets('applying a hint places a queen without overflow',
            (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          await selectAndPlay(tester, 2, 'Play Queens'); // hard 8×8

          expect(find.text('0/8'), findsOneWidget);
          await tester.tap(find.text('HINT'), warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 300));

          // A hint fills exactly one region's queen.
          expect(find.text('1/8'), findsOneWidget);
          expectNoOverflow(device, 'Queens hint applied');
          cleanUp(tester);
        });

        testWidgets('idle "stuck" nudge appears without overflow',
            (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          await selectAndPlay(tester, 2, 'Play Queens'); // hard 8×8

          // Idle timeout is 8s (queens_puzzle_screen _kIdleTimeout).
          await tester.pump(const Duration(seconds: 9));
          expect(find.text('Stuck? Try a hint!'), findsOneWidget);
          expectNoOverflow(device, 'Queens stuck nudge');
          cleanUp(tester);
        });
      });
    }
  });
}
