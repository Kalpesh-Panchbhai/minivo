import 'package:flutter_test/flutter_test.dart';
import '../../lib/games/sudoku/sudoku_engine.dart';

void main() {
  group('SudokuEngine.generate', () {
    test('returns a 9×9 puzzle grid', () {
      final result = SudokuEngine.generate(46);
      expect(result.puzzle.length, 9);
      for (final row in result.puzzle) {
        expect(row.length, 9);
      }
    });

    test('returns a 9×9 solution grid', () {
      final result = SudokuEngine.generate(46);
      expect(result.solution.length, 9);
      for (final row in result.solution) {
        expect(row.length, 9);
      }
    });

    test('solution has no zeros (fully solved)', () {
      final result = SudokuEngine.generate(36);
      for (final row in result.solution) {
        for (final cell in row) {
          expect(cell, greaterThanOrEqualTo(1));
          expect(cell, lessThanOrEqualTo(9));
        }
      }
    });

    test('puzzle has correct number of clues for easy', () {
      final result = SudokuEngine.generate(46);
      int clueCount = 0;
      for (final row in result.puzzle) {
        for (final cell in row) {
          if (cell != 0) clueCount++;
        }
      }
      expect(clueCount, 46);
    });

    test('puzzle has correct number of clues for medium', () {
      final result = SudokuEngine.generate(36);
      int clueCount = 0;
      for (final row in result.puzzle) {
        for (final cell in row) {
          if (cell != 0) clueCount++;
        }
      }
      expect(clueCount, 36);
    });

    test('puzzle has correct number of clues for hard', () {
      final result = SudokuEngine.generate(28);
      int clueCount = 0;
      for (final row in result.puzzle) {
        for (final cell in row) {
          if (cell != 0) clueCount++;
        }
      }
      expect(clueCount, 28);
    });

    test('puzzle clues match solution at same positions', () {
      final result = SudokuEngine.generate(36);
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (result.puzzle[r][c] != 0) {
            expect(result.puzzle[r][c], result.solution[r][c],
                reason: 'Clue at ($r,$c) must match solution');
          }
        }
      }
    });

    test('solution rows contain all digits 1-9', () {
      final result = SudokuEngine.generate(36);
      for (int r = 0; r < 9; r++) {
        final sorted = List<int>.from(result.solution[r])..sort();
        expect(sorted, [1, 2, 3, 4, 5, 6, 7, 8, 9],
            reason: 'Row $r must contain digits 1-9');
      }
    });

    test('solution columns contain all digits 1-9', () {
      final result = SudokuEngine.generate(36);
      for (int c = 0; c < 9; c++) {
        final col = <int>[];
        for (int r = 0; r < 9; r++) {
          col.add(result.solution[r][c]);
        }
        col.sort();
        expect(col, [1, 2, 3, 4, 5, 6, 7, 8, 9],
            reason: 'Column $c must contain digits 1-9');
      }
    });

    test('solution 3×3 boxes contain all digits 1-9', () {
      final result = SudokuEngine.generate(36);
      for (int br = 0; br < 3; br++) {
        for (int bc = 0; bc < 3; bc++) {
          final box = <int>[];
          for (int r = br * 3; r < br * 3 + 3; r++) {
            for (int c = bc * 3; c < bc * 3 + 3; c++) {
              box.add(result.solution[r][c]);
            }
          }
          box.sort();
          expect(box, [1, 2, 3, 4, 5, 6, 7, 8, 9],
              reason: 'Box ($br,$bc) must contain digits 1-9');
        }
      }
    });

    test('two generated puzzles are different (randomness)', () {
      final a = SudokuEngine.generate(36);
      final b = SudokuEngine.generate(36);
      bool same = true;
      for (int r = 0; r < 9 && same; r++) {
        for (int c = 0; c < 9 && same; c++) {
          if (a.solution[r][c] != b.solution[r][c]) same = false;
        }
      }
      expect(same, isFalse, reason: 'Two puzzles should differ');
    });

    test('puzzle values are 0-9 only', () {
      final result = SudokuEngine.generate(36);
      for (final row in result.puzzle) {
        for (final cell in row) {
          expect(cell, greaterThanOrEqualTo(0));
          expect(cell, lessThanOrEqualTo(9));
        }
      }
    });
  });
}
