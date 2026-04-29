import 'dart:math';

/// Pure game-logic for 2048. No Flutter dependencies — fully unit-testable.
///
/// The board is a 4×4 grid stored as a flat 16-element list (row-major).
/// Index formula: row * 4 + col.  Empty cells have value 0.

const int kBoardSize = 4;
const int kWinTile = 2048;

/// Result returned by every slide operation.
final class SlideResult {
  final List<int> board;
  final int scoreGained;
  final bool moved;

  const SlideResult({
    required this.board,
    required this.scoreGained,
    required this.moved,
  });
}

final class MergeBoard {
  /// Flat 16-element list, row-major order, immutable.
  final List<int> cells;

  const MergeBoard._(this.cells);

  factory MergeBoard.empty() => MergeBoard._(List.unmodifiable(List.filled(16, 0)));

  factory MergeBoard.from(List<int> cells) {
    assert(cells.length == 16, 'Board must have exactly 16 cells');
    return MergeBoard._(List.unmodifiable(List<int>.from(cells)));
  }

  // ── Accessors ─────────────────────────────────────────────────────────────

  int get(int row, int col) => cells[row * kBoardSize + col];

  List<int> get emptyIndices =>
      [for (int i = 0; i < 16; i++) if (cells[i] == 0) i];

  bool get hasWon => cells.any((v) => v >= kWinTile);

  bool get isGameOver {
    if (cells.any((v) => v == 0)) return false;
    for (int r = 0; r < kBoardSize; r++) {
      for (int c = 0; c < kBoardSize; c++) {
        final v = get(r, c);
        if (c + 1 < kBoardSize && get(r, c + 1) == v) return false;
        if (r + 1 < kBoardSize && get(r + 1, c) == v) return false;
      }
    }
    return true;
  }

  // ── Slide operations ──────────────────────────────────────────────────────

  SlideResult slideLeft() {
    final flat = List<int>.from(cells);
    int score = 0;
    bool moved = false;
    for (int r = 0; r < kBoardSize; r++) {
      final (line, gained, lineMoved) = _mergeLine(
        [for (int c = 0; c < kBoardSize; c++) flat[r * kBoardSize + c]],
      );
      for (int c = 0; c < kBoardSize; c++) { flat[r * kBoardSize + c] = line[c]; }
      score += gained;
      if (lineMoved) moved = true;
    }
    return SlideResult(board: flat, scoreGained: score, moved: moved);
  }

  SlideResult slideRight() {
    final flat = List<int>.from(cells);
    int score = 0;
    bool moved = false;
    for (int r = 0; r < kBoardSize; r++) {
      final row = [for (int c = 0; c < kBoardSize; c++) flat[r * kBoardSize + c]];
      final (line, gained, lineMoved) = _mergeLine(row.reversed.toList());
      final result = line.reversed.toList();
      for (int c = 0; c < kBoardSize; c++) { flat[r * kBoardSize + c] = result[c]; }
      score += gained;
      if (lineMoved) moved = true;
    }
    return SlideResult(board: flat, scoreGained: score, moved: moved);
  }

  SlideResult slideUp() {
    final flat = List<int>.from(cells);
    int score = 0;
    bool moved = false;
    for (int c = 0; c < kBoardSize; c++) {
      final (line, gained, lineMoved) = _mergeLine(
        [for (int r = 0; r < kBoardSize; r++) flat[r * kBoardSize + c]],
      );
      for (int r = 0; r < kBoardSize; r++) { flat[r * kBoardSize + c] = line[r]; }
      score += gained;
      if (lineMoved) moved = true;
    }
    return SlideResult(board: flat, scoreGained: score, moved: moved);
  }

  SlideResult slideDown() {
    final flat = List<int>.from(cells);
    int score = 0;
    bool moved = false;
    for (int c = 0; c < kBoardSize; c++) {
      final col = [for (int r = 0; r < kBoardSize; r++) flat[r * kBoardSize + c]];
      final (line, gained, lineMoved) = _mergeLine(col.reversed.toList());
      final result = line.reversed.toList();
      for (int r = 0; r < kBoardSize; r++) { flat[r * kBoardSize + c] = result[r]; }
      score += gained;
      if (lineMoved) moved = true;
    }
    return SlideResult(board: flat, scoreGained: score, moved: moved);
  }

  // ── Tile spawning ─────────────────────────────────────────────────────────

  /// Spawns a tile (90 % → 2, 10 % → 4) at a random empty cell.
  MergeBoard spawnTile(Random rng) {
    final empty = emptyIndices;
    if (empty.isEmpty) return this;
    final index = empty[rng.nextInt(empty.length)];
    final value = rng.nextDouble() < 0.9 ? 2 : 4;
    final next = List<int>.from(cells);
    next[index] = value;
    return MergeBoard._(List.unmodifiable(next));
  }

  // ── Line merge helper ─────────────────────────────────────────────────────

  /// Compact → merge adjacent equal pairs (left-to-right, once per pair) → compact.
  static (List<int>, int, bool) _mergeLine(List<int> line) {
    final original = List<int>.from(line);

    // Compact non-zero values to the left
    final compacted = line.where((v) => v != 0).toList();
    int score = 0;

    // Merge adjacent equal tiles once per pair (left-to-right scan).
    // After a merge, advance i so the merged tile cannot merge again this pass.
    // Since we removeAt(i+1), the element now at i+1 was previously i+2, so
    // a plain i++ (from the for loop) is sufficient — no double increment needed.
    int i = 0;
    while (i < compacted.length - 1) {
      if (compacted[i] == compacted[i + 1]) {
        compacted[i] *= 2;
        score += compacted[i];
        compacted.removeAt(i + 1);
        // Advance past the merged tile so it cannot be used again this pass.
        i++;
      } else {
        i++;
      }
    }

    // Pad back to kBoardSize with zeros
    while (compacted.length < kBoardSize) { compacted.add(0); }

    final moved = !_listEquals(original, compacted);
    return (compacted, score, moved);
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
