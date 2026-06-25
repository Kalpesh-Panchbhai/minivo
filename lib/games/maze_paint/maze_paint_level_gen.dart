import 'dart:math' as math;

import 'maze_paint_seeds.g.dart';

// ---------------------------------------------------------------------------
// Maze Paint — a "roller splat" puzzle.
//
// A ball sits on an irregular maze of floor tiles (the board is NOT a full
// rectangle — its outline is a random connected shape, possibly with holes).
// Swiping a direction rolls the ball in a straight line until a wall or the
// board edge stops it, painting every tile it passes over. The level is solved
// when every floor tile is painted.
//
// "Strictly solvable, exactly one solution" is defined over IRREDUNDANT move
// sequences: every move must paint at least one NEW tile (a move that only
// rolls over already-painted tiles is wasted and never part of a solution).
// Under that rule the set of solutions is finite, and a level ships only if it
// has EXACTLY ONE such sequence — see [countMazePaintSolutions].
//
// Difficulty rises on two human-felt, monotonic axes:
//   * board size           — Easy 5x5  <  Medium 6x6  <  Hard 7x7 bounding box
//   * branch toughness      — how many points along the unique solution offer
//                             more than one productive direction (a real chance
//                             to go wrong). See [mpToughness] / the bands below.
//
// The 10k levels per difficulty are generated + verified offline and baked into
// maze_paint_seeds.g.dart; the device only decodes (no solver runs on device).
// ---------------------------------------------------------------------------

enum MazePaintDir { up, right, down, left }

const List<(int, int)> _kDeltas = [
  (-1, 0), // up
  (0, 1), // right
  (1, 0), // down
  (0, -1), // left
];

class MazePaintLevel {
  final int rows;
  final int cols;
  final int start;
  final Set<int> walls;
  final List<MazePaintDir> solution;

  MazePaintLevel({
    required this.rows,
    required this.cols,
    required this.start,
    required this.walls,
    required this.solution,
  });

  /// Number of floor (paintable) tiles.
  int get paintableCount => rows * cols - walls.length;
}

// ---------------------------------------------------------------------------
// Difficulty curve — bounding box per difficulty (the region inside is
// irregular). Size strictly grows Easy < Medium < Hard, the primary separator.
// ---------------------------------------------------------------------------

int mpRows(int diffIndex) => const [5, 6, 7][diffIndex.clamp(0, 2)];
int mpCols(int diffIndex) => const [5, 6, 7][diffIndex.clamp(0, 2)];

/// Target floor-tile count range per difficulty. More tiles => longer routes.
List<int> _floorRange(int diffIndex) {
  switch (diffIndex) {
    case 0:
      return const [9, 18]; // Easy   (of 25)
    case 1:
      return const [18, 27]; // Medium (of 36)
    default:
      return const [28, 40]; // Hard   (of 49)
  }
}

/// Probability of growing the region toward its most-connected frontier cell
/// (chunky / open areas => more branch points) vs its least-connected one
/// (thin corridors => mostly forced). Easy stays thin; Hard opens up.
double _compactBias(int diffIndex) => const [0.12, 0.30, 0.40][diffIndex.clamp(0, 2)];

// ---------------------------------------------------------------------------
// Grid helpers (wall-set based — used by the runtime screen for live moves).
// ---------------------------------------------------------------------------

/// Destination cell when rolling from [start] in [dir] until a wall/edge stops
/// the ball. Returns [start] itself if the ball cannot move.
int moveDestination({
  required int rows,
  required int cols,
  required Set<int> walls,
  required int start,
  required MazePaintDir dir,
}) {
  var r = start ~/ cols;
  var c = start % cols;
  final delta = _kDeltas[dir.index];
  while (true) {
    final nr = r + delta.$1;
    final nc = c + delta.$2;
    if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) break;
    final next = nr * cols + nc;
    if (walls.contains(next)) break;
    r = nr;
    c = nc;
  }
  return r * cols + c;
}

/// The tiles rolled over (excluding [start], in travel order) when sliding from
/// [start] in [dir]. Empty when the ball cannot move.
List<int> cellsAlongMove({
  required int rows,
  required int cols,
  required Set<int> walls,
  required int start,
  required MazePaintDir dir,
}) {
  final cells = <int>[];
  var r = start ~/ cols;
  var c = start % cols;
  final delta = _kDeltas[dir.index];
  while (true) {
    final nr = r + delta.$1;
    final nc = c + delta.$2;
    if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) break;
    final next = nr * cols + nc;
    if (walls.contains(next)) break;
    r = nr;
    c = nc;
    cells.add(next);
  }
  return cells;
}

// ---------------------------------------------------------------------------
// Slide engine over a bitmask floor (fast — used by the solver/toughness).
//
// For every floor cell and direction we precompute the destination cell and
// the bitmask of tiles painted along the way (excluding the origin). A move is
// only legal when that bitmask is non-empty (the ball actually moves).
// ---------------------------------------------------------------------------

class _SlideTable {
  final int area;
  final int floorMask;
  final List<int> dest; // [cell*4 + dir] -> destination cell
  final List<int> pathMask; // [cell*4 + dir] -> tiles painted (excl. origin)

  _SlideTable(this.area, this.floorMask, this.dest, this.pathMask);

  static _SlideTable build(int rows, int cols, Set<int> walls) {
    final area = rows * cols;
    int floorMask = 0;
    for (int i = 0; i < area; i++) {
      if (!walls.contains(i)) floorMask |= 1 << i;
    }
    final dest = List<int>.filled(area * 4, 0);
    final pathMask = List<int>.filled(area * 4, 0);
    for (int cell = 0; cell < area; cell++) {
      if ((floorMask >> cell) & 1 == 0) continue;
      for (int d = 0; d < 4; d++) {
        final delta = _kDeltas[d];
        var r = cell ~/ cols, c = cell % cols;
        int mask = 0, last = cell;
        while (true) {
          final nr = r + delta.$1, nc = c + delta.$2;
          if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) break;
          final next = nr * cols + nc;
          if ((floorMask >> next) & 1 == 0) break;
          mask |= 1 << next;
          last = next;
          r = nr;
          c = nc;
        }
        dest[cell * 4 + d] = last;
        pathMask[cell * 4 + d] = mask;
      }
    }
    return _SlideTable(area, floorMask, dest, pathMask);
  }
}

// ---------------------------------------------------------------------------
// Uniqueness solver.
//
// Counts the distinct IRREDUNDANT solutions (each move paints >=1 new tile)
// that fully paint the maze, starting at [start], capped at [cap]. State is
// (paintedMask, position); painted grows strictly each move, so the state graph
// is a DAG and the count is the number of root->complete paths through it.
// `== 1` means strictly solvable with a single intended route.
//
// Memo key packs (mask << 6 | pos); kept valid only when no node hits the cap
// (i.e. when the final count is exactly 1), which is the only case we extract a
// solution for. A node-limit abort returns [cap] so the generator rejects the
// candidate rather than ship an unverified level.
// ---------------------------------------------------------------------------

class _Solver {
  final _SlideTable t;
  final int start;
  final int cap;
  final int nodeLimit;
  final Map<int, int> memo = {};
  int nodes = 0;
  bool aborted = false;

  _Solver(this.t, this.start, this.cap, this.nodeLimit);

  int _count(int mask, int pos) {
    if (mask == t.floorMask) return 1;
    if (aborted) return 0;
    final key = (mask << 6) | pos;
    final cached = memo[key];
    if (cached != null) return cached;
    if (++nodes > nodeLimit) {
      aborted = true;
      return 0;
    }
    int total = 0;
    final base = pos * 4;
    for (int d = 0; d < 4; d++) {
      final pm = t.pathMask[base + d];
      if (pm == 0) continue; // ball can't move this way
      if (pm & ~mask == 0) continue; // nothing new painted => wasted move
      total += _count(mask | pm, t.dest[base + d]);
      if (total >= cap) {
        total = cap;
        break;
      }
    }
    memo[key] = total;
    return total;
  }

  int count() {
    final c = _count(1 << start, start);
    return aborted ? cap : c;
  }

  /// Reconstruct the single solution. Only valid after [count] returned 1.
  List<MazePaintDir>? extractSolution() {
    final dirs = <MazePaintDir>[];
    int mask = 1 << start, pos = start;
    while (mask != t.floorMask) {
      bool advanced = false;
      final base = pos * 4;
      for (int d = 0; d < 4; d++) {
        final pm = t.pathMask[base + d];
        if (pm == 0 || pm & ~mask == 0) continue;
        final nmask = mask | pm;
        final ndest = t.dest[base + d];
        if (_count(nmask, ndest) >= 1) {
          dirs.add(MazePaintDir.values[d]);
          mask = nmask;
          pos = ndest;
          advanced = true;
          break;
        }
      }
      if (!advanced) return null;
      if (dirs.length > t.area * 2) return null; // safety
    }
    return dirs;
  }
}

/// Number of distinct irredundant solutions, capped at [cap]. `== 1` => the
/// level is strictly solvable with exactly one intended route.
int countMazePaintSolutions(MazePaintLevel p,
    {int cap = 2, int nodeLimit = 1500000}) {
  final t = _SlideTable.build(p.rows, p.cols, p.walls);
  return _Solver(t, p.start, cap, nodeLimit).count();
}

bool mpSolvable(MazePaintLevel p) => countMazePaintSolutions(p, cap: 2) == 1;

/// Replays [solution] from [start] and returns the painted tile set — used by
/// tests/generation to assert full coverage.
Set<int> mpReplay(MazePaintLevel p) {
  final painted = <int>{p.start};
  var pos = p.start;
  for (final dir in p.solution) {
    final cells = cellsAlongMove(
        rows: p.rows, cols: p.cols, walls: p.walls, start: pos, dir: dir);
    if (cells.isEmpty) break;
    painted.addAll(cells);
    pos = cells.last;
  }
  return painted;
}

// ---------------------------------------------------------------------------
// Toughness — felt difficulty proxy.
//
// Walk the unique solution. At each state count the PRODUCTIVE directions (a
// move painting >=1 new tile). Every step with more than one productive option
// is a point where the player faces a genuine decision and can go wrong; we
// sum those. A pure forced corridor scores 0 (trivial); open areas with many
// fork points score high. Deterministic and cheap — run once per accepted
// level during generation and asserted by the band tests.
// ---------------------------------------------------------------------------

int mpToughness(MazePaintLevel p) {
  final t = _SlideTable.build(p.rows, p.cols, p.walls);
  int mask = 1 << p.start, pos = p.start;
  int tough = 0;
  for (final dir in p.solution) {
    int productive = 0;
    final base = pos * 4;
    for (int d = 0; d < 4; d++) {
      final pm = t.pathMask[base + d];
      if (pm == 0 || pm & ~mask == 0) continue;
      productive++;
    }
    if (productive > 1) tough++;
    final pm = t.pathMask[base + dir.index];
    mask |= pm;
    pos = t.dest[base + dir.index];
  }
  return tough;
}

/// Per-difficulty toughness bands. Easy stays gentle (mostly forced), Medium
/// asks for some planning, Hard is genuinely forky. Calibrated against the
/// measured distributions of the generators' shape parameters.
const List<int> mpToughnessMin = [0, 2, 4];
const List<int> mpToughnessMax = [3, 6, 1 << 30];

bool mpToughnessOk(int diffIndex, int toughness) {
  final d = diffIndex.clamp(0, 2);
  return toughness >= mpToughnessMin[d] && toughness <= mpToughnessMax[d];
}

// ---------------------------------------------------------------------------
// Candidate generation — random irregular connected region + endpoint start.
// ---------------------------------------------------------------------------

List<int> _neighbors(int idx, int rows, int cols) {
  final r = idx ~/ cols, c = idx % cols;
  final res = <int>[];
  if (r > 0) res.add((r - 1) * cols + c);
  if (r < rows - 1) res.add((r + 1) * cols + c);
  if (c > 0) res.add(r * cols + c - 1);
  if (c < cols - 1) res.add(r * cols + c + 1);
  return res;
}

/// Grows a random connected blob of [target] cells. [compactBias] in [0,1]
/// controls whether growth favours well-connected frontier cells (chunky open
/// regions) or poorly-connected ones (thin winding corridors).
Set<int> _growRegion(
    int rows, int cols, int target, double compactBias, math.Random rng) {
  final area = rows * cols;
  final floor = <int>{rng.nextInt(area)};
  final frontier = <int>{};
  for (final nb in _neighbors(floor.first, rows, cols)) {
    frontier.add(nb);
  }
  while (floor.length < target && frontier.isNotEmpty) {
    final list = frontier.toList();
    int pick;
    if (rng.nextDouble() < compactBias) {
      // Most floor-adjacent frontier cell (ties broken randomly).
      list.shuffle(rng);
      int best = list.first, bestDeg = -1;
      for (final f in list) {
        int deg = 0;
        for (final nb in _neighbors(f, rows, cols)) {
          if (floor.contains(nb)) deg++;
        }
        if (deg > bestDeg) {
          bestDeg = deg;
          best = f;
        }
      }
      pick = best;
    } else {
      // Least floor-adjacent frontier cell -> keeps corridors thin.
      list.shuffle(rng);
      int best = list.first, bestDeg = 5;
      for (final f in list) {
        int deg = 0;
        for (final nb in _neighbors(f, rows, cols)) {
          if (floor.contains(nb)) deg++;
        }
        if (deg < bestDeg) {
          bestDeg = deg;
          best = f;
        }
      }
      pick = best;
    }
    frontier.remove(pick);
    floor.add(pick);
    for (final nb in _neighbors(pick, rows, cols)) {
      if (!floor.contains(nb)) frontier.add(nb);
    }
  }
  return floor;
}

/// Floor cells ordered by how good a starting point they are: corridor ends
/// (fewest floor neighbours) first — these force the most among early moves and
/// dramatically raise the single-solution yield.
List<int> _startCandidates(Set<int> floor, int rows, int cols, math.Random rng) {
  final list = floor.toList()..shuffle(rng);
  list.sort((a, b) {
    int deg(int x) {
      int d = 0;
      for (final nb in _neighbors(x, rows, cols)) {
        if (floor.contains(nb)) d++;
      }
      return d;
    }

    return deg(a).compareTo(deg(b));
  });
  return list;
}

/// Builds one candidate level for [diffIndex] using [rng], or null if this draw
/// did not yield a strictly-unique, in-band puzzle. Loop until non-null.
/// [enforceBand] is false only for offline band calibration.
MazePaintLevel? buildMazePaintCandidate(int diffIndex, math.Random rng,
    {bool enforceBand = true}) {
  final rows = mpRows(diffIndex);
  final cols = mpCols(diffIndex);
  final area = rows * cols;
  final range = _floorRange(diffIndex);
  final target = range[0] + rng.nextInt(range[1] - range[0] + 1);
  final bias = _compactBias(diffIndex);

  final floor = _growRegion(rows, cols, target, bias, rng);
  if (floor.length < 4) return null;

  final walls = <int>{};
  for (int i = 0; i < area; i++) {
    if (!floor.contains(i)) walls.add(i);
  }

  // Try a handful of the most "endpoint-like" start cells.
  final starts = _startCandidates(floor, rows, cols, rng);
  final tries = math.min(starts.length, 6);
  for (int k = 0; k < tries; k++) {
    final start = starts[k];
    final t = _SlideTable.build(rows, cols, walls);
    final solver = _Solver(t, start, 2, 1500000);
    if (solver.count() != 1) continue;
    final solution = solver.extractSolution();
    if (solution == null || solution.isEmpty) continue;
    final level = MazePaintLevel(
        rows: rows, cols: cols, start: start, walls: walls, solution: solution);
    if (mpReplay(level).length != level.paintableCount) continue;
    if (enforceBand && !mpToughnessOk(diffIndex, mpToughness(level))) continue;
    return level;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Signature (cross-level uniqueness) + bit packing for the seed table.
// ---------------------------------------------------------------------------

/// Identifies a level by its shape + start; the unique solution is derived, so
/// two levels with the same shape+start are the same puzzle.
String mpSignature(MazePaintLevel r) {
  final floor = <int>[];
  for (int i = 0; i < r.rows * r.cols; i++) {
    if (!r.walls.contains(i)) floor.add(i);
  }
  return '${r.rows}x${r.cols}|${r.start}|${floor.join(",")}';
}

/// Byte length of an encoded level: floor bitmap + start(8) + solLen(8) +
/// 2 bits per move.
int mpStrideBytes(int rows, int cols, int solLen) {
  final bits = rows * cols + 8 + 8 + solLen * 2;
  return (bits + 7) >> 3;
}

List<int> mpEncodeLevel(MazePaintLevel r) {
  final area = r.rows * r.cols;
  final solLen = r.solution.length;
  final out = List<int>.filled(mpStrideBytes(r.rows, r.cols, solLen), 0);
  int bit = 0;
  void putBits(int val, int count) {
    for (int i = 0; i < count; i++) {
      if ((val >> i) & 1 != 0) out[bit >> 3] |= 1 << (bit & 7);
      bit++;
    }
  }

  for (int i = 0; i < area; i++) {
    putBits(r.walls.contains(i) ? 0 : 1, 1);
  }
  putBits(r.start, 8);
  putBits(solLen, 8);
  for (final d in r.solution) {
    putBits(d.index, 2);
  }
  return out;
}

MazePaintLevel mpDecodeLevel(int rows, int cols, List<int> bytes) {
  final area = rows * cols;
  int bit = 0;
  int getBits(int count) {
    int val = 0;
    for (int i = 0; i < count; i++) {
      val |= ((bytes[bit >> 3] >> (bit & 7)) & 1) << i;
      bit++;
    }
    return val;
  }

  final walls = <int>{};
  for (int i = 0; i < area; i++) {
    if (getBits(1) == 0) walls.add(i);
  }
  final start = getBits(8);
  final solLen = getBits(8);
  final solution =
      List<MazePaintDir>.generate(solLen, (_) => MazePaintDir.values[getBits(2)]);
  return MazePaintLevel(
      rows: rows, cols: cols, start: start, walls: walls, solution: solution);
}

// ---------------------------------------------------------------------------
// Device-side level lookup — pure decode of the offline-verified table. The
// 10k levels per difficulty repeat forever (level 10001 plays puzzle 1, ...).
// ---------------------------------------------------------------------------

MazePaintLevel generateMazePaintLevel(int level, int diffIndex) {
  final d = diffIndex.clamp(0, 2);
  final rows = mpRows(d);
  final cols = mpCols(d);
  final idx = (level - 1) % mpLevelsPerDifficulty;
  final bytes = mpLevelBytes(d, idx);
  return mpDecodeLevel(rows, cols, bytes);
}
