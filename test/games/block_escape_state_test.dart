import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/services/level_progress_service.dart';
import '../../lib/games/game_registry.dart';
import '../../lib/games/game_wrapper.dart';
import '../../lib/games/block_escape/block_escape_level_gen.dart';
import '../../lib/games/block_escape/block_escape_seeds.g.dart';
import '../../lib/games/shared/level_complete_overlay.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/game_drivers.dart';
import '../helpers/test_helpers.dart';

// ---------------------------------------------------------------------------
// SAVE / RESTORE of in-progress games.
//
// The screen persists a mid-game snapshot (level, moves, hintsUsed, full block
// layout) on every move via LevelProgressService.saveGameState, and restores
// it in _startGame when the saved level matches the current level. None of
// this — the block (de)serialization contract, the moves restore, the
// "don't save an untouched board" guard, or clearing on restart/win — was
// covered anywhere in the suite. This file closes that gap.
// ---------------------------------------------------------------------------

const _gameId = 'block_escape';
const _sub = 'easy';
const _device = TestDevice(
  name: 'Pixel 6',
  width: 412,
  height: 915,
  pixelRatio: 2.625,
  platform: TargetPlatform.android,
);
const _boardKey = Key('block_escape_board');

Widget _build() =>
    GameWrapper(gameId: _gameId, child: GameRegistry.buildGame(_gameId));

// Mirrors the exact (de)serialization the screen uses (block_escape_screen
// _saveState lines 348-355 and the restore in _startGame lines 147-154).
Map<String, dynamic> _serBlock(Block b) => {
      'id': b.id,
      'row': b.row,
      'col': b.col,
      'length': b.length,
      'dir': b.dir.index,
      'isTarget': b.isTarget,
    };

Block _deserBlock(Map<String, dynamic> b) => Block(
      id: b['id'] as int,
      row: b['row'] as int,
      col: b['col'] as int,
      length: b['length'] as int,
      dir: BlockDir.values[b['dir'] as int],
      isTarget: b['isTarget'] as bool,
    );

String _stateKey(String sub) => 'state_${_gameId}_$sub';

Future<Finder> _startEasy(WidgetTester tester) async {
  await selectDifficultyStop(tester, 0);
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
  expect(board, findsOneWidget, reason: 'EASY board did not mount after Play');
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
  test('block serialization round-trips through saveGameState/getGameState', () async {
    await initGameTest();
    final lps = LevelProgressService();

    for (int diff = 0; diff < 3; diff++) {
      final sub = const ['easy', 'medium', 'hard'][diff];
      final level = generateBlockEscapeLevel(1, diff);
      final state = {
        'level': 1,
        'moves': 5,
        'hintsUsed': 2,
        'blocks': level.blocks.map(_serBlock).toList(),
      };
      await lps.saveGameState(_gameId, sub, state);

      final got = lps.getGameState(_gameId, sub);
      expect(got, isNotNull);
      expect(got!['level'], 1);
      expect(got['moves'], 5);
      expect(got['hintsUsed'], 2);

      final restored =
          (got['blocks'] as List).map((b) => _deserBlock(b as Map<String, dynamic>)).toList();
      expect(restored.length, level.blocks.length, reason: 'diff $diff: block count changed');
      for (int i = 0; i < level.blocks.length; i++) {
        final a = level.blocks[i], r = restored[i];
        expect(r.id, a.id);
        expect(r.row, a.row);
        expect(r.col, a.col);
        expect(r.length, a.length);
        expect(r.dir, a.dir);
        expect(r.isTarget, a.isTarget);
      }
      expect(restored.where((b) => b.isTarget).length, 1,
          reason: 'diff $diff: target lost in round-trip');
    }
  });

  group('Block Escape — screen save/restore', () {
    testWidgets('an untouched board is NOT persisted (no-move save guard)',
        (tester) async {
      await initGameTest();
      await pumpScreen(tester, _device, _build(), settle: false);
      await _startEasy(tester);
      // _startGame restores nothing and _saveState early-returns while
      // moves==0 && hintsUsed==0, so no snapshot should exist yet.
      expect(LevelProgressService().getGameState(_gameId, _sub), isNull,
          reason: 'state saved before any move was made');
      cleanUp(tester);
    });

    testWidgets('a move persists level + moves + full block layout', (tester) async {
      await initGameTest();
      await pumpScreen(tester, _device, _build(), settle: false);
      final board = await _startEasy(tester);
      final rect = tester.getRect(board);

      final cand = buildBlockEscapeCandidate(1, 0, beSaltFor(1, 0))!;
      final cell = rect.height / cand.rows;
      final (id, delta) = cand.solution.first;
      final b = cand.blocks.firstWhere((x) => x.id == id);
      final offset = b.dir == BlockDir.horizontal
          ? Offset(delta * cell, 0)
          : Offset(0, delta * cell);
      await tester.dragFrom(_blockCenter(b, rect, cell), offset);
      await tester.pump(const Duration(milliseconds: 250));

      final saved = LevelProgressService().getGameState(_gameId, _sub);
      expect(saved, isNotNull, reason: 'no state persisted after a move');
      expect(saved!['level'], 1);
      expect(saved['moves'], 1);
      final blocks = (saved['blocks'] as List)
          .map((m) => _deserBlock(m as Map<String, dynamic>))
          .toList();
      expect(blocks.length, cand.blocks.length);
      expect(blocks.where((x) => x.isTarget).length, 1);
      cleanUp(tester);
    });

    testWidgets('restart clears the saved snapshot', (tester) async {
      await initGameTest();
      await pumpScreen(tester, _device, _build(), settle: false);
      final board = await _startEasy(tester);
      final rect = tester.getRect(board);

      final cand = buildBlockEscapeCandidate(1, 0, beSaltFor(1, 0))!;
      final cell = rect.height / cand.rows;
      final (id, delta) = cand.solution.first;
      final b = cand.blocks.firstWhere((x) => x.id == id);
      final offset = b.dir == BlockDir.horizontal
          ? Offset(delta * cell, 0)
          : Offset(0, delta * cell);
      await tester.dragFrom(_blockCenter(b, rect, cell), offset);
      await tester.pump(const Duration(milliseconds: 250));
      expect(LevelProgressService().getGameState(_gameId, _sub), isNotNull);

      // Restart goes through a confirmation dialog ("Restart Game?"); _restartLevel
      // (which clears the snapshot) only runs once the user confirms.
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.widgetWithText(FilledButton, 'Restart'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(LevelProgressService().getGameState(_gameId, _sub), isNull,
          reason: 'restart did not clear the in-progress snapshot');
      cleanUp(tester);
    });

    testWidgets('winning clears the saved snapshot', (tester) async {
      await initGameTest();
      await pumpScreen(tester, _device, _build(), settle: false);
      final board = await _startEasy(tester);
      final rect = tester.getRect(board);

      final cand = buildBlockEscapeCandidate(1, 0, beSaltFor(1, 0))!;
      final cell = rect.height / cand.rows;
      final cur = <int, Block>{for (final x in cand.blocks) x.id: x};
      for (final (id, delta) in cand.solution) {
        final b = cur[id]!;
        final offset = b.dir == BlockDir.horizontal
            ? Offset(delta * cell, 0)
            : Offset(0, delta * cell);
        await tester.dragFrom(_blockCenter(b, rect, cell), offset);
        await tester.pump(const Duration(milliseconds: 250));
        cur[id] = b.moved(delta);
      }
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(LevelCompleteOverlay), findsOneWidget,
          reason: 'optimal replay did not win');
      expect(LevelProgressService().getGameState(_gameId, _sub), isNull,
          reason: 'winning did not clear the in-progress snapshot');
      cleanUp(tester);
    });
  });

  group('Block Escape — screen restore', () {
    testWidgets('a pre-seeded snapshot restores the moves counter on Play',
        (tester) async {
      // Seed an in-progress EASY level-1 game with a distinctive move count
      // (7 — can't collide with LEVEL 1) BEFORE the screen builds.
      final level = generateBlockEscapeLevel(1, 0);
      final state = {
        'level': 1,
        'moves': 7,
        'hintsUsed': 0,
        'blocks': level.blocks.map(_serBlock).toList(),
      };
      await initGameTest(extra: {_stateKey(_sub): jsonEncode(state)});

      await pumpScreen(tester, _device, _build(), settle: false);
      await _startEasy(tester);

      // _startGame saw saved['level'] == current level (1) and restored moves.
      expect(find.text('7'), findsOneWidget,
          reason: 'restored MOVES counter not shown — snapshot ignored');
      cleanUp(tester);
    });
  });
}
