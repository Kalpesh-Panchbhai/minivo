import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:minivo/games/number_merge/number_merge_logic.dart';

void main() {
  group('MergeBoard', () {
    // ── Construction ────────────────────────────────────────────────────────

    test('empty board has all zeros', () {
      final b = MergeBoard.empty();
      expect(b.cells.every((v) => v == 0), isTrue);
    });

    test('from() defensive-copies the list', () {
      final src = List<int>.filled(16, 2);
      final b = MergeBoard.from(src);
      src[0] = 99;
      expect(b.cells[0], 2); // not mutated
    });

    test('from() rejects wrong-length lists', () {
      expect(() => MergeBoard.from(List.filled(15, 0)), throwsA(isA<AssertionError>()));
    });

    // ── emptyIndices ────────────────────────────────────────────────────────

    test('emptyIndices returns all 16 on blank board', () {
      expect(MergeBoard.empty().emptyIndices.length, 16);
    });

    test('emptyIndices excludes non-zero cells', () {
      final cells = List<int>.filled(16, 2);
      cells[3] = 0;
      cells[7] = 0;
      expect(MergeBoard.from(cells).emptyIndices, [3, 7]);
    });

    // ── hasWon ───────────────────────────────────────────────────────────────

    test('hasWon is false when no tile reaches 2048', () {
      final cells = List<int>.filled(16, 1024);
      expect(MergeBoard.from(cells).hasWon, isFalse);
    });

    test('hasWon is true when any tile equals 2048', () {
      final cells = List<int>.filled(16, 0);
      cells[5] = 2048;
      expect(MergeBoard.from(cells).hasWon, isTrue);
    });

    test('hasWon is true for tiles beyond 2048', () {
      final cells = List<int>.filled(16, 0);
      cells[0] = 4096;
      expect(MergeBoard.from(cells).hasWon, isTrue);
    });

    // ── isGameOver ────────────────────────────────────────────────────────────

    test('isGameOver false when empty cells exist', () {
      expect(MergeBoard.empty().isGameOver, isFalse);
    });

    test('isGameOver false when adjacent merge possible', () {
      // Fill with alternating 2/4 — adjacent same values in some row
      final cells = [
        2, 2, 4, 8,
        4, 8, 2, 4,
        8, 4, 8, 2,
        4, 8, 4, 8,
      ];
      expect(MergeBoard.from(cells).isGameOver, isFalse);
    });

    test('isGameOver true when board is full with no merges', () {
      final cells = [
        2, 4, 2, 4,
        4, 2, 4, 2,
        2, 4, 2, 4,
        4, 2, 4, 2,
      ];
      expect(MergeBoard.from(cells).isGameOver, isTrue);
    });

    // ── slideLeft ─────────────────────────────────────────────────────────────

    test('slideLeft compacts tiles to the left', () {
      final cells = List<int>.filled(16, 0);
      cells[1] = 2; // row 0, col 1
      final result = MergeBoard.from(cells).slideLeft();
      expect(result.moved, isTrue);
      expect(result.board[0], 2); // moved to col 0
      expect(result.board[1], 0);
    });

    test('slideLeft merges adjacent equal tiles', () {
      final cells = List<int>.filled(16, 0);
      cells[0] = 2;
      cells[1] = 2;
      final result = MergeBoard.from(cells).slideLeft();
      expect(result.board[0], 4);
      expect(result.board[1], 0);
      expect(result.scoreGained, 4);
    });

    test('slideLeft merges once per pair (no chain)', () {
      final cells = List<int>.filled(16, 0);
      // [2, 2, 4, 0] → merge 2+2=4 → [4, 4, 0, 0] but NOT [8]
      cells[0] = 2; cells[1] = 2; cells[2] = 4;
      final result = MergeBoard.from(cells).slideLeft();
      expect(result.board[0], 4);
      expect(result.board[1], 4);
      expect(result.board[2], 0);
    });

    test('slideLeft reports moved=false when nothing changes', () {
      final cells = List<int>.filled(16, 0);
      cells[0] = 4; cells[4] = 8; // already left-aligned
      final result = MergeBoard.from(cells).slideLeft();
      expect(result.moved, isFalse);
    });

    // ── slideRight ────────────────────────────────────────────────────────────

    test('slideRight compacts tiles to the right', () {
      final cells = List<int>.filled(16, 0);
      cells[0] = 2; // row 0, col 0
      final result = MergeBoard.from(cells).slideRight();
      expect(result.moved, isTrue);
      expect(result.board[3], 2); // moved to col 3
    });

    test('slideRight merges correctly', () {
      final cells = List<int>.filled(16, 0);
      cells[2] = 4; cells[3] = 4; // row 0, cols 2&3
      final result = MergeBoard.from(cells).slideRight();
      expect(result.board[3], 8);
      expect(result.scoreGained, 8);
    });

    // ── slideUp ───────────────────────────────────────────────────────────────

    test('slideUp compacts tiles to the top', () {
      final cells = List<int>.filled(16, 0);
      cells[8] = 2; // row 2, col 0
      final result = MergeBoard.from(cells).slideUp();
      expect(result.moved, isTrue);
      expect(result.board[0], 2); // row 0, col 0
    });

    test('slideUp merges correctly', () {
      final cells = List<int>.filled(16, 0);
      cells[0] = 8; // row 0, col 0
      cells[4] = 8; // row 1, col 0
      final result = MergeBoard.from(cells).slideUp();
      expect(result.board[0], 16);
      expect(result.scoreGained, 16);
    });

    // ── slideDown ─────────────────────────────────────────────────────────────

    test('slideDown compacts tiles to the bottom', () {
      final cells = List<int>.filled(16, 0);
      cells[0] = 2; // row 0, col 0
      final result = MergeBoard.from(cells).slideDown();
      expect(result.moved, isTrue);
      expect(result.board[12], 2); // row 3, col 0
    });

    // ── score accumulation ────────────────────────────────────────────────────

    test('multiple merges in one slide sum correctly', () {
      // Row: [2, 2, 4, 4] → [4, 8, 0, 0] score = 4 + 8 = 12
      final cells = List<int>.filled(16, 0);
      cells[0] = 2; cells[1] = 2; cells[2] = 4; cells[3] = 4;
      final result = MergeBoard.from(cells).slideLeft();
      expect(result.scoreGained, 12);
    });

    // ── spawnTile ─────────────────────────────────────────────────────────────

    test('spawnTile places a 2 or 4 in an empty cell', () {
      final rng = Random(42);
      final board = MergeBoard.empty().spawnTile(rng);
      final nonZero = board.cells.where((v) => v != 0).toList();
      expect(nonZero.length, 1);
      expect([2, 4].contains(nonZero[0]), isTrue);
    });

    test('spawnTile does not mutate a full board', () {
      final cells = List<int>.filled(16, 2);
      final board = MergeBoard.from(cells);
      final result = board.spawnTile(Random());
      expect(result.cells, board.cells);
    });

    test('spawnTile spawns mostly 2s (statistical)', () {
      final rng = Random(0);
      int twos = 0;
      for (int i = 0; i < 200; i++) {
        final board = MergeBoard.empty().spawnTile(rng);
        if (board.cells.any((v) => v == 2)) twos++;
      }
      // Expect ≥ 75 % to be 2 (actual probability 90 %)
      expect(twos, greaterThan(150));
    });

    // ── immutability ──────────────────────────────────────────────────────────

    test('slide operations return new boards without mutating the original', () {
      final original = List<int>.filled(16, 0);
      original[0] = 2; original[1] = 2;
      final board = MergeBoard.from(original);
      final snapshot = List<int>.from(board.cells);
      board.slideLeft();
      expect(board.cells, snapshot);
    });
  });
}
