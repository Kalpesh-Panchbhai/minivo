import 'dart:math' as math;

// ---------------------------------------------------------------------------
// Sliding Puzzle (N-puzzle) — pure generation & solvability logic.
//
// A board is a row-major list of length n*n where 0 is the blank. The solved
// board is [1, 2, ..., n*n-1, 0].
//
// Solvability: not every random permutation of an N-puzzle is solvable — only
// half of them are. We guarantee solvable boards two ways (belt-and-suspenders):
//   1. Generation performs a random walk of LEGAL moves from the solved state.
//      Every legal move is reversible, so any reachable board is solvable.
//   2. Generation additionally verifies the board with the inversion-parity
//      rule and regenerates on the (impossible-by-construction) off chance a
//      board is ever not solvable. This makes the guarantee robust even if the
//      generation strategy is ever changed.
// ---------------------------------------------------------------------------

class SlidingPuzzleGen {
  const SlidingPuzzleGen._();

  /// A shuffled board and the index of its blank tile.
  static ({List<int> tiles, int emptyIndex}) generate(
    int n, {
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    late List<int> tiles;
    late int emptyIndex;
    do {
      tiles = solved(n);
      emptyIndex = n * n - 1;
      final walkLength = n * n * 200;
      for (int i = 0; i < walkLength; i++) {
        final neighbors = movableIndices(emptyIndex, n);
        final pick = neighbors[rng.nextInt(neighbors.length)];
        tiles[emptyIndex] = tiles[pick];
        tiles[pick] = 0;
        emptyIndex = pick;
      }
    } while (isSolved(tiles) || !isSolvable(tiles, n));
    return (tiles: tiles, emptyIndex: emptyIndex);
  }

  /// The solved arrangement for an n×n grid: [1, 2, ..., n*n-1, 0].
  static List<int> solved(int n) =>
      List<int>.generate(n * n - 1, (i) => i + 1)..add(0);

  /// True when [tiles] is fully solved (1..n*n-1 in order, blank last).
  static bool isSolved(List<int> tiles) {
    for (int i = 0; i < tiles.length - 1; i++) {
      if (tiles[i] != i + 1) return false;
    }
    return tiles.isNotEmpty && tiles.last == 0;
  }

  /// Board indices adjacent to [emptyIndex] whose tile can slide into the blank.
  static List<int> movableIndices(int emptyIndex, int n) {
    final r = emptyIndex ~/ n;
    final c = emptyIndex % n;
    final result = <int>[];
    if (r > 0) result.add((r - 1) * n + c);
    if (r < n - 1) result.add((r + 1) * n + c);
    if (c > 0) result.add(r * n + c - 1);
    if (c < n - 1) result.add(r * n + c + 1);
    return result;
  }

  /// Number of inversions in [tiles] (row-major order, ignoring the blank).
  static int inversions(List<int> tiles) {
    final seq = <int>[for (final v in tiles) if (v != 0) v];
    int count = 0;
    for (int i = 0; i < seq.length; i++) {
      for (int j = i + 1; j < seq.length; j++) {
        if (seq[i] > seq[j]) count++;
      }
    }
    return count;
  }

  /// Whether an arbitrary [tiles] arrangement of an n×n grid is solvable, using
  /// the classic N-puzzle inversion-parity rule.
  static bool isSolvable(List<int> tiles, int n) {
    final inv = inversions(tiles);
    if (n.isOdd) return inv.isEven;
    // Even width: solvable iff (inversions + blank row counted from the bottom,
    // 1-based) is odd.
    final blankRowFromBottom = n - (tiles.indexOf(0) ~/ n);
    return (inv + blankRowFromBottom).isOdd;
  }
}
