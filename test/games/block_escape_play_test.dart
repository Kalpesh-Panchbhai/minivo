import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/games/game_registry.dart';
import '../../lib/games/game_wrapper.dart';
import '../../lib/games/block_escape/block_escape_level_gen.dart';
import '../../lib/games/block_escape/block_escape_seeds.g.dart';
import '../../lib/games/shared/level_complete_overlay.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/game_drivers.dart';
import '../helpers/test_helpers.dart';

// ---------------------------------------------------------------------------
// END-TO-END playability: drive a real level to a WIN through the actual
// gesture pipeline (pan-to-slide), not the logic layer. This proves the board
// is genuinely completable on a device — geometry, hit-testing, axis lock,
// snap-to-cell and the positional win check all work together.
//
// We replay the offline-verified optimal solution for EASY level 1 as drags.
// The level is deterministic (generateBlockEscapeLevel(1, 0)), so the moves we
// compute match exactly what the screen loaded.
// ---------------------------------------------------------------------------

const _device = TestDevice(
  name: 'Pixel 6',
  width: 412,
  height: 915,
  pixelRatio: 2.625,
  platform: TargetPlatform.android,
);

Widget _build() =>
    GameWrapper(gameId: 'block_escape', child: GameRegistry.buildGame('block_escape'));

/// Selects EASY and taps Play, retrying through the play button's fade-in until
/// the board actually mounts (a single tap can land mid-animation and be lost).
Future<Finder> _startEasy(WidgetTester tester) async {
  await selectDifficultyStop(tester, 0);
  final play = find.text('Play Block Escape');
  final board = find.byKey(const Key('block_escape_board'));
  for (int i = 0; i < 10 && !tester.any(board); i++) {
    if (tester.any(play)) {
      try {
        await tester.ensureVisible(play.first);
      } catch (_) {}
      await tester.tap(play.first, warnIfMissed: false);
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(board, findsOneWidget, reason: 'EASY board did not mount after Play');
  return board;
}

void main() {
  group('Block Escape — drive a level to a win', () {
    setUp(() async => initGameTest());

    testWidgets('replaying the optimal EASY solution as drags wins the level',
        (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);

      final board = await _startEasy(tester);

      // The exact level + optimal solution the screen is showing.
      const level = 1, diff = 0;
      final salt = beSaltFor(level, diff);
      final cand = buildBlockEscapeCandidate(level, diff, salt)!;
      final rows = cand.rows;

      // Board geometry: the SizedBox is (cell*cols + exitGate) wide, cell*rows
      // tall; cell-grid origin is the SizedBox top-left (board sits at 0,0).
      final rect = tester.getRect(board);
      final cell = rect.height / rows;

      Offset blockCenter(Block b) {
        final cx = b.dir == BlockDir.horizontal
            ? (b.col + b.length / 2) * cell
            : (b.col + 0.5) * cell;
        final cy = b.dir == BlockDir.horizontal
            ? (b.row + 0.5) * cell
            : (b.row + b.length / 2) * cell;
        return rect.topLeft + Offset(cx, cy);
      }

      // Local mirror of block positions so each drag grabs the piece where it
      // currently sits after previous moves.
      final cur = <int, Block>{for (final b in cand.blocks) b.id: b};

      for (final (id, delta) in cand.solution) {
        final b = cur[id]!;
        final start = blockCenter(b);
        final offset = b.dir == BlockDir.horizontal
            ? Offset(delta * cell, 0)
            : Offset(0, delta * cell);
        await tester.dragFrom(start, offset);
        await tester.pump(const Duration(milliseconds: 250));
        cur[id] = b.moved(delta);
      }

      // Let the win fire and the appreciation overlay insert.
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(LevelCompleteOverlay), findsOneWidget,
          reason: 'replaying the optimal solution did not produce a win');

      cleanUp(tester);
    });

    testWidgets('a single drag registers as a move', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      final board = await _startEasy(tester);
      final rect = tester.getRect(board);

      const level = 1, diff = 0;
      final cand = buildBlockEscapeCandidate(level, diff, beSaltFor(level, diff))!;
      final cell = rect.height / cand.rows;
      final (id, delta) = cand.solution.first;
      final b = cand.blocks.firstWhere((x) => x.id == id);
      final start = b.dir == BlockDir.horizontal
          ? rect.topLeft + Offset((b.col + b.length / 2) * cell, (b.row + 0.5) * cell)
          : rect.topLeft + Offset((b.col + 0.5) * cell, (b.row + b.length / 2) * cell);
      final offset = b.dir == BlockDir.horizontal
          ? Offset(delta * cell, 0)
          : Offset(0, delta * cell);

      await tester.dragFrom(start, offset);
      await tester.pump(const Duration(milliseconds: 250));

      // After exactly one move the HUD MOVES counter reads 1.
      expect(find.text('1'), findsWidgets,
          reason: 'MOVES counter did not advance after a drag');
      cleanUp(tester);
    });
  });
}
