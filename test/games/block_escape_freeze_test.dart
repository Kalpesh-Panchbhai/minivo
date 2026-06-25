import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/games/game_registry.dart';
import '../../lib/games/game_wrapper.dart';
import '../../lib/games/block_escape/block_escape_level_gen.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/game_drivers.dart';
import '../helpers/test_helpers.dart';

// ---------------------------------------------------------------------------
// FREEZE regression guard for the _maxDelta bound.
//
// Original bug: grabbing the red TARGET piece froze the screen. onPanStart
// calls _maxDelta(target.id, +1), whose old `while (_canMoveBlock(...))` loop
// never terminated — _canMoveBlock intentionally lets the horizontal target
// slide PAST the exit wall (off-board cells are skipped), so the unbounded
// scan spun forever on the UI thread. The fix bounds the scan to the board
// span: `while (delta.abs() < math.max(rows, cols) && _canMoveBlock(...))`.
//
// This test reproduces the exact trigger: it grabs the target and drags it a
// huge distance (well past the board), in both directions, on EASY and the
// dense HARD board. If _maxDelta ever loses its bound the synchronous scan in
// onPanStart hangs the isolate and these tests time out (the tight per-test
// Timeout turns the freeze into a fast, clear failure instead of a CI hang).
// ---------------------------------------------------------------------------

const _device = TestDevice(
  name: 'Pixel 6',
  width: 412,
  height: 915,
  pixelRatio: 2.625,
  platform: TargetPlatform.android,
);

const _boardKey = Key('block_escape_board');

Widget _build() =>
    GameWrapper(gameId: 'block_escape', child: GameRegistry.buildGame('block_escape'));

/// Selects [diff] (0=EASY..2=HARD), taps Play and waits for the board to mount.
Future<Finder> _start(WidgetTester tester, int diff) async {
  await selectDifficultyStop(tester, diff);
  final play = find.text('Play Block Escape');
  final board = find.byKey(_boardKey);
  for (int i = 0; i < 10 && !tester.any(board); i++) {
    if (tester.any(play)) {
      try {
        await tester.ensureVisible(play.first);
      } catch (_) {}
      await tester.tap(play.first, warnIfMissed: false);
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(board, findsOneWidget, reason: 'board did not mount after Play');
  return board;
}

Offset _blockCenter(Block b, Rect rect, double cell) {
  final cx = b.dir == BlockDir.horizontal
      ? (b.col + b.length / 2) * cell
      : (b.col + 0.5) * cell;
  final cy = b.dir == BlockDir.horizontal
      ? (b.row + 0.5) * cell
      : (b.row + b.length / 2) * cell;
  return rect.topLeft + Offset(cx, cy);
}

void main() {
  group('Block Escape — freeze regression (_maxDelta bound)', () {
    setUp(() async => initGameTest());

    for (int diff = 0; diff < 3; diff++) {
      const names = ['EASY', 'MEDIUM', 'HARD'];
      testWidgets('$diff:${names[diff]} dragging the target far never hangs',
          (tester) async {
        await pumpScreen(tester, _device, _build(), settle: false);
        final board = await _start(tester, diff);
        final rect = tester.getRect(board);

        // Level 1 is what the freshly-started screen shows (current level == 1).
        final level = generateBlockEscapeLevel(1, diff);
        final cell = rect.height / level.rows;
        final target = level.blocks.firstWhere((b) => b.isTarget);
        final center = _blockCenter(target, rect, cell);

        // Drag the red piece FAR right (past the exit wall) — the exact gesture
        // that used to spin _maxDelta forever — then far left.
        await tester.dragFrom(center, Offset(cell * 20, 0));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.dragFrom(center, Offset(-cell * 20, 0));
        await tester.pump(const Duration(milliseconds: 250));

        // Reaching here proves onPanStart's _maxDelta scan terminated. Also
        // grab a perpendicular (vertical) blocker and over-drag it, covering
        // the bound for non-target pieces too.
        final vert = level.blocks
            .where((b) => b.dir == BlockDir.vertical && !b.isTarget)
            .toList();
        if (vert.isNotEmpty) {
          final v = vert.first;
          await tester.dragFrom(_blockCenter(v, rect, cell), Offset(0, cell * 20));
          await tester.pump(const Duration(milliseconds: 250));
        }

        expect(find.byKey(_boardKey), findsOneWidget,
            reason: 'board gone after over-dragging — interaction corrupted');
        cleanUp(tester);
      }, timeout: const Timeout(Duration(seconds: 45)));
    }
  });
}
