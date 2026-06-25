import 'dart:math' as math;

import 'block_escape_seeds.g.dart';

enum BlockDir { horizontal, vertical }

class Block {
  final int id;
  final int row;
  final int col;
  final int length;
  final BlockDir dir;
  final bool isTarget;

  const Block({
    required this.id,
    required this.row,
    required this.col,
    required this.length,
    required this.dir,
    this.isTarget = false,
  });

  List<(int, int)> get cells {
    final res = <(int, int)>[];
    for (int i = 0; i < length; i++) {
      if (dir == BlockDir.horizontal) {
        res.add((row, col + i));
      } else {
        res.add((row + i, col));
      }
    }
    return res;
  }

  Block moved(int delta) {
    if (dir == BlockDir.horizontal) {
      return Block(id: id, row: row, col: col + delta, length: length, dir: dir, isTarget: isTarget);
    } else {
      return Block(id: id, row: row + delta, col: col, length: length, dir: dir, isTarget: isTarget);
    }
  }
}

class BlockEscapeLevel {
  final int rows;
  final int cols;
  final int exitRow;
  final List<Block> blocks;

  /// Optimal move sequence to the exit. Populated with the real moves when a
  /// level is built+verified offline ([buildBlockEscapeCandidate]); at runtime
  /// the device only reconstructs the board layout (no solver runs), so this is
  /// a placeholder list of length [solutionLength] — its contents are never
  /// executed (hints recompute live; the win check is positional).
  final List<(int blockId, int delta)> solution;

  /// Length of the optimal solution (number of compressed car-moves). Baked
  /// into the seed table so the device knows the puzzle's depth without solving.
  final int solutionLength;

  const BlockEscapeLevel({
    required this.rows,
    required this.cols,
    required this.exitRow,
    required this.blocks,
    required this.solution,
    int? solutionLength,
  }) : solutionLength = solutionLength ?? -1;
}

int beRows(int diffIndex) => 6;
int beCols(int diffIndex) => 6;

int _blockCount(int level, int diffIndex) {
  switch (diffIndex) {
    case 0:
      return 4 + math.min(level ~/ 8, 4);
    case 1:
      return 6 + math.min(level ~/ 6, 5);
    default:
      return 8 + math.min(level ~/ 4, 6);
  }
}

// ---------------------------------------------------------------------------
// Difficulty bands — the move-count contract every shipped level obeys.
//
// "Moves" are COMPRESSED car-moves: one piece sliding N squares in a single
// direction counts as one move (matches how a player perceives a move and how
// classic Rush Hour grades difficulty on its solution cards).
//
// Bands calibrated empirically against THIS generator (full 1..10000 sweep)
// and against the research:
//   * Easy   3-6  : near-frictionless; high first-try success (mobile onboarding
//                   research). Excludes trivial 2-move boards so it's easy, not
//                   a no-op. Realised mean ~3.8.
//   * Medium 6-11 : a clear step up; a couple of blocker chains to plan around.
//                   Realised mean ~8.
//   * Hard   10-18: genuinely hard; deep blocker-of-a-blocker chains. Realised
//                   mean ~14. Ceiling is 18 ON PURPOSE — random 6x6 boards above
//                   ~18 car-moves are vanishingly rare (academic: <2% of the
//                   whole space is >=10 moves), so a higher ceiling would starve
//                   the 10k-unique generation. Do NOT raise it.
//
// The bands overlap slightly by design (Easy/Medium at 6, Medium/Hard at 10-11):
// move count alone is a weak difficulty proxy — a 10-move Hard board with 14
// pieces and recursive blocking is harder than an 11-move Medium board with 8.
// What players feel is the clean separation of the *medians* (~4 / 8 / 14) and
// the rising piece count. See block_escape_solvability_test difficulty group.
// ---------------------------------------------------------------------------

/// Minimum optimal solution length (inclusive) accepted for [diffIndex].
int beMinSolLen(int diffIndex) => const [3, 6, 10][diffIndex.clamp(0, 2)];

/// Maximum optimal solution length (inclusive) accepted for [diffIndex].
int beMaxSolLen(int diffIndex) => const [6, 11, 18][diffIndex.clamp(0, 2)];

int _seed(int level, int diffIndex, int salt) {
  int h = level * 2654435761 + diffIndex * 2246822519 + salt * 3266489917;
  h = ((h >> 16) ^ h) * 0x45d9f3b;
  h = ((h >> 16) ^ h) * 0x45d9f3b;
  h = (h >> 16) ^ h;
  return h.abs();
}

class _Grid {
  final int rows;
  final int cols;
  final List<int> data;

  _Grid(this.rows, this.cols) : data = List.filled(rows * cols, -1);

  int get(int r, int c) => (r >= 0 && r < rows && c >= 0 && c < cols) ? data[r * cols + c] : -2;

  void set(int r, int c, int v) {
    if (r >= 0 && r < rows && c >= 0 && c < cols) data[r * cols + c] = v;
  }

  void placeBlock(Block b) {
    for (final (r, c) in b.cells) {
      set(r, c, b.id);
    }
  }

  void removeBlock(Block b) {
    for (final (r, c) in b.cells) {
      set(r, c, -1);
    }
  }

  bool canPlace(Block b) {
    for (final (r, c) in b.cells) {
      if (r < 0 || r >= rows || c < 0 || c >= cols) return false;
      if (data[r * cols + c] != -1) return false;
    }
    return true;
  }
}

List<(int, int)> _compressMoves(List<(int, int)> raw) {
  if (raw.isEmpty) return raw;
  final result = <(int, int)>[raw.first];
  for (int i = 1; i < raw.length; i++) {
    if (raw[i].$1 == result.last.$1) {
      final merged = (result.last.$1, result.last.$2 + raw[i].$2);
      result.last = merged;
    } else {
      result.add(raw[i]);
    }
  }
  result.removeWhere((m) => m.$2 == 0);
  return result;
}

// ---------------------------------------------------------------------------
// Fast shortest-path solver.
//
// Replaces the old string-keyed, full-block-list-copying BFS. Each search
// state is the tuple of every block's *variable* coordinate (col for a
// horizontal block, row for a vertical one) — the fixed coordinate, direction
// and length never change, so they live in static per-block arrays. With a
// 6x6 board each coord is 0..5 (3 bits); up to 21 blocks pack into one 63-bit
// int, used directly as the visited-set key (Set<int>, no String building).
//
// The optimal path is recovered from parent pointers at the end instead of
// copying the growing move list onto every neighbour, so the hot loop does
// zero per-edge allocation. BFS level order means the first time the target
// escapes is the shortest solution; [maxDepth] lets the offline generator bail
// the instant a board proves deeper than the difficulty ceiling (and unsolvable
// boards bail at the cap instead of exhausting the whole reachable space).
//
// Edge semantics are byte-for-byte identical to the old BFS: one edge slides a
// block by any reachable distance (so a 3-cell slide is one move), and the
// horizontal target escapes the moment its right edge crosses the wall. Hence
// the returned compressed move count equals the old solver's for every board
// (verified offline against the legacy BFS over the full sweep).
List<(int, int)> _bfsFast(List<Block> initial, int rows, int cols,
    {int nodeLimit = 100000, int maxDepth = 1 << 30}) {
  final n = initial.length;
  final isH = List<bool>.filled(n, false);
  final len = List<int>.filled(n, 0);
  final fixed = List<int>.filled(n, 0); // row if horizontal, col if vertical
  final isTarget = List<bool>.filled(n, false);
  final id = List<int>.filled(n, 0);
  int startKey = 0;
  for (int i = 0; i < n; i++) {
    final b = initial[i];
    isH[i] = b.dir == BlockDir.horizontal;
    len[i] = b.length;
    isTarget[i] = b.isTarget;
    id[i] = b.id;
    final vc = isH[i] ? b.col : b.row;
    fixed[i] = isH[i] ? b.row : b.col;
    startKey |= vc << (3 * i);
  }

  final visited = <int>{startKey};
  final qKey = <int>[startKey];
  final qDepth = <int>[0];
  final qParent = <int>[-1];
  final qMoveBlock = <int>[-1];
  final qMoveDelta = <int>[0];

  final grid = List<int>.filled(rows * cols, -1);

  int head = 0;
  while (head < qKey.length && head < nodeLimit) {
    final curKey = qKey[head];
    final curDepth = qDepth[head];
    final curIdx = head;
    head++;
    if (curDepth >= maxDepth) continue;

    grid.fillRange(0, rows * cols, -1);
    for (int i = 0; i < n; i++) {
      final vc = (curKey >> (3 * i)) & 7;
      if (isH[i]) {
        final base = fixed[i] * cols + vc;
        for (int k = 0; k < len[i]; k++) { grid[base + k] = i; }
      } else {
        for (int k = 0; k < len[i]; k++) { grid[(vc + k) * cols + fixed[i]] = i; }
      }
    }

    for (int bi = 0; bi < n; bi++) {
      final vc = (curKey >> (3 * bi)) & 7;
      final L = len[bi];
      final mask = ~(7 << (3 * bi));
      if (isH[bi]) {
        final r = fixed[bi];
        final rowBase = r * cols;
        for (int k = 0; k < L; k++) { grid[rowBase + vc + k] = -1; }
        for (int delta = 1;; delta++) {
          final nc = vc + delta;
          final checkC = nc + L - 1;
          if (checkC >= cols) {
            if (isTarget[bi]) {
              return _reconstruct(
                  qParent, qMoveBlock, qMoveDelta, id, curIdx, bi, delta);
            }
            break;
          }
          if (grid[rowBase + checkC] != -1) break;
          final nk = (curKey & mask) | (nc << (3 * bi));
          if (visited.add(nk)) {
            qKey.add(nk);
            qDepth.add(curDepth + 1);
            qParent.add(curIdx);
            qMoveBlock.add(bi);
            qMoveDelta.add(delta);
          }
        }
        for (int delta = -1;; delta--) {
          final nc = vc + delta;
          if (nc < 0) break;
          if (grid[rowBase + nc] != -1) break;
          final nk = (curKey & mask) | (nc << (3 * bi));
          if (visited.add(nk)) {
            qKey.add(nk);
            qDepth.add(curDepth + 1);
            qParent.add(curIdx);
            qMoveBlock.add(bi);
            qMoveDelta.add(delta);
          }
        }
        for (int k = 0; k < L; k++) { grid[rowBase + vc + k] = bi; }
      } else {
        final c = fixed[bi];
        for (int k = 0; k < L; k++) { grid[(vc + k) * cols + c] = -1; }
        for (int delta = 1;; delta++) {
          final nr = vc + delta;
          final checkR = nr + L - 1;
          if (checkR >= rows) break;
          if (grid[checkR * cols + c] != -1) break;
          final nk = (curKey & mask) | (nr << (3 * bi));
          if (visited.add(nk)) {
            qKey.add(nk);
            qDepth.add(curDepth + 1);
            qParent.add(curIdx);
            qMoveBlock.add(bi);
            qMoveDelta.add(delta);
          }
        }
        for (int delta = -1;; delta--) {
          final nr = vc + delta;
          if (nr < 0) break;
          if (grid[nr * cols + c] != -1) break;
          final nk = (curKey & mask) | (nr << (3 * bi));
          if (visited.add(nk)) {
            qKey.add(nk);
            qDepth.add(curDepth + 1);
            qParent.add(curIdx);
            qMoveBlock.add(bi);
            qMoveDelta.add(delta);
          }
        }
        for (int k = 0; k < L; k++) { grid[(vc + k) * cols + c] = bi; }
      }
    }
  }
  return [];
}

/// Walks parent pointers from [curIdx] back to the root, then appends the
/// terminal escape move ([finalBi] sliding [finalDelta] off the board), maps
/// block indices to ids and compresses consecutive same-block slides.
List<(int, int)> _reconstruct(List<int> parent, List<int> moveBlock,
    List<int> moveDelta, List<int> id, int curIdx, int finalBi, int finalDelta) {
  final rev = <(int, int)>[];
  int node = curIdx;
  while (parent[node] != -1) {
    rev.add((moveBlock[node], moveDelta[node]));
    node = parent[node];
  }
  final moves = <(int, int)>[];
  for (int i = rev.length - 1; i >= 0; i--) {
    moves.add((id[rev[i].$1], rev[i].$2));
  }
  moves.add((id[finalBi], finalDelta));
  return _compressMoves(moves);
}

/// The deterministic board layout for (level, diffIndex, salt) — built purely
/// from the seeded RNG, with NO solver run. The accepted offline salt produces
/// exactly this layout, so the device can rebuild it instantly (see
/// [buildBlockEscapeBoardOnly]) without ever running the BFS.
class _BoardDraw {
  final int rows;
  final int cols;
  final int exitRow;
  final List<Block> blocks;
  const _BoardDraw(this.rows, this.cols, this.exitRow, this.blocks);
}

_BoardDraw? _constructBoard(int level, int diffIndex, int salt) {
  final rng = math.Random(_seed(level, diffIndex, salt));
  final rows = beRows(diffIndex);
  final cols = beCols(diffIndex);
  final numBlocks = _blockCount(level, diffIndex);
  final exitRow = rng.nextInt(rows - 1) + 1;

  final grid = _Grid(rows, cols);
  final blocks = <Block>[];
  int nextId = 0;

  final targetCol = rng.nextInt(cols - 2);
  final target = Block(id: nextId++, row: exitRow, col: targetCol, length: 2, dir: BlockDir.horizontal, isTarget: true);
  if (!grid.canPlace(target)) return null;
  grid.placeBlock(target);
  blocks.add(target);

  int placed = 0;
  int attempts = 0;
  while (placed < numBlocks - 1 && attempts < 200) {
    attempts++;
    final len = rng.nextBool() ? 2 : 3;
    final dir = rng.nextBool() ? BlockDir.horizontal : BlockDir.vertical;
    final r = rng.nextInt(rows);
    final c = rng.nextInt(cols);
    final b = Block(id: nextId, row: r, col: c, length: len, dir: dir);
    if (!grid.canPlace(b)) continue;
    if (dir == BlockDir.horizontal && r == exitRow && c + len > targetCol) {
      if (c <= targetCol + 2) continue;
    }
    grid.placeBlock(b);
    blocks.add(b);
    nextId++;
    placed++;
  }

  if (blocks.length < 3) return null;
  return _BoardDraw(rows, cols, exitRow, blocks);
}

/// Offline candidate builder: constructs the board, then RUNS the solver to
/// verify solvability and enforce the per-difficulty move-count band. Returns
/// null if unsolvable or out of band. Used only by the seed generator + tests.
BlockEscapeLevel? buildBlockEscapeCandidate(int level, int diffIndex, int salt) {
  final draw = _constructBoard(level, diffIndex, salt);
  if (draw == null) return null;

  // Depth-capped at the difficulty ceiling: a board deeper than the band (or
  // unsolvable) bails at the cap instead of exhausting the reachable space,
  // and the cap never changes the accepted set — a true-shortest in [min,max]
  // is still found, anything above max is rejected either way.
  final solution =
      _bfsFast(draw.blocks, draw.rows, draw.cols, maxDepth: beMaxSolLen(diffIndex));
  if (solution.isEmpty) return null;
  final solLen = solution.length;
  if (solLen < beMinSolLen(diffIndex) || solLen > beMaxSolLen(diffIndex)) return null;

  return BlockEscapeLevel(
    rows: draw.rows,
    cols: draw.cols,
    exitRow: draw.exitRow,
    blocks: draw.blocks,
    solution: solution,
    solutionLength: solLen,
  );
}

/// Device-side builder: rebuilds the offline-verified board layout from its
/// salt WITHOUT running the solver, then attaches the baked [solLen]. This is
/// the hot path — it must stay well under the 10ms load budget. The [solution]
/// list is a placeholder of the correct length (contents unused at runtime).
BlockEscapeLevel buildBlockEscapeBoardOnly(int level, int diffIndex, int salt, int solLen) {
  final draw = _constructBoard(level, diffIndex, salt)!;
  return BlockEscapeLevel(
    rows: draw.rows,
    cols: draw.cols,
    exitRow: draw.exitRow,
    blocks: draw.blocks,
    solution: List.filled(solLen, const (0, 0)),
    solutionLength: solLen,
  );
}

int countBlockEscapeSolutions(BlockEscapeLevel p, {int cap = 2}) {
  final sol = _bfsFast(p.blocks, p.rows, p.cols);
  if (sol.isEmpty) return 0;
  return 1;
}

String beSignature(BlockEscapeLevel p) {
  final sb = StringBuffer('${p.rows}x${p.cols}|${p.exitRow}|');
  final sorted = List<Block>.from(p.blocks)..sort((a, b) => a.id.compareTo(b.id));
  for (final b in sorted) {
    sb.write('${b.row},${b.col},${b.length},${b.dir.index},${b.isTarget ? 1 : 0};');
  }
  return sb.toString();
}

BlockEscapeLevel? generateBlockEscapeLevelWithSalt(int level, int diffIndex, int salt) {
  return buildBlockEscapeCandidate(level, diffIndex, salt);
}

/// Device-side level lookup. Pure board reconstruction from the offline-verified
/// salt + baked solution length — NO solver runs here, so it stays far under the
/// 10ms load budget. The [beLevelsPerDifficulty] levels per difficulty repeat
/// forever (level N+1 plays puzzle 1, ...).
BlockEscapeLevel generateBlockEscapeLevel(int level, int diffIndex) {
  final d = diffIndex.clamp(0, 2);
  final effLevel = (level - 1) % beLevelsPerDifficulty + 1;
  final salt = beSaltFor(effLevel, d);
  final solLen = beSolLenFor(effLevel, d);
  return buildBlockEscapeBoardOnly(effLevel, d, salt, solLen);
}

/// Live hint solver for the play screen: the single shortest car-move that
/// advances the CURRENT board toward the exit. Uses the same efficient
/// int-grid BFS as the offline solver (not the old string-key, full-list-copy
/// version), with a tighter node cap so it can never freeze the UI thread.
/// Returns null if no move is found within [nodeLimit]. Requires block ids to
/// be a contiguous 0..n-1 set (as produced by [generateBlockEscapeLevel]).
(int blockId, int delta)? blockEscapeHintMove(List<Block> blocks, int rows, int cols,
    {int nodeLimit = 60000}) {
  final compressed = _bfsFast(blocks, rows, cols, nodeLimit: nodeLimit);
  return compressed.isEmpty ? null : compressed.first;
}
