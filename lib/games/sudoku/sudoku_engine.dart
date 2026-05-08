import 'dart:math' as math;

class SudokuPuzzle {
  final List<List<int>> puzzle;
  final List<List<int>> solution;

  SudokuPuzzle({required this.puzzle, required this.solution});
}

// Top-level for use with compute()
SudokuPuzzle generateSudokuPuzzle(int clues) => SudokuEngine.generate(clues);

class SudokuEngine {
  static final math.Random _rng = math.Random();

  static SudokuPuzzle generate(int clues) {
    final grid = List.generate(9, (_) => List.filled(9, 0));
    _fillGrid(grid);

    // Deep-copy solution
    final solution = grid.map((row) => List<int>.from(row)).toList();

    final toRemove = 81 - clues;
    _removeClues(grid, toRemove);

    return SudokuPuzzle(puzzle: grid, solution: solution);
  }

  static bool _fillGrid(List<List<int>> grid) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (grid[row][col] == 0) {
          final digits = List.generate(9, (i) => i + 1)..shuffle(_rng);
          for (final num in digits) {
            if (_isValid(grid, row, col, num)) {
              grid[row][col] = num;
              if (_fillGrid(grid)) return true;
              grid[row][col] = 0;
            }
          }
          return false;
        }
      }
    }
    return true;
  }

  static bool _isValid(List<List<int>> grid, int row, int col, int num) {
    // Check row
    for (int c = 0; c < 9; c++) {
      if (grid[row][c] == num) return false;
    }
    // Check column
    for (int r = 0; r < 9; r++) {
      if (grid[r][col] == num) return false;
    }
    // Check 3x3 box
    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        if (grid[r][c] == num) return false;
      }
    }
    return true;
  }

  static void _removeClues(List<List<int>> grid, int toRemove) {
    final cells = List.generate(81, (i) => i)..shuffle(_rng);
    int removed = 0;

    for (final cell in cells) {
      if (removed >= toRemove) break;
      final row = cell ~/ 9;
      final col = cell % 9;
      final backup = grid[row][col];
      if (backup == 0) continue;

      grid[row][col] = 0;

      // Check uniqueness
      final count = _countSolutions(
        grid.map((r) => List<int>.from(r)).toList(),
        0,
      );
      if (count == 1) {
        removed++;
      } else {
        grid[row][col] = backup;
      }
    }
  }

  static int _countSolutions(List<List<int>> grid, int count) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (grid[row][col] == 0) {
          for (int num = 1; num <= 9; num++) {
            if (_isValid(grid, row, col, num)) {
              grid[row][col] = num;
              count = _countSolutions(grid, count);
              grid[row][col] = 0;
              if (count > 1) return count;
            }
          }
          return count;
        }
      }
    }
    return count + 1;
  }
}
