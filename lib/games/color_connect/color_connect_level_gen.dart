import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'color_connect_seeds.g.dart';

class ColorConnectLevelResult {
  final int rows;
  final int cols;
  final int numFlows;
  final List<int> endpoints;
  final List<int> solution;

  const ColorConnectLevelResult({
    required this.rows,
    required this.cols,
    required this.numFlows,
    required this.endpoints,
    required this.solution,
  });
}

int ccRows(int diffIndex) => const [5, 7, 9][diffIndex.clamp(0, 2)];
int ccCols(int diffIndex) => const [5, 7, 9][diffIndex.clamp(0, 2)];

/// Candidate colour (flow) counts per difficulty. Generation picks one per
/// attempt; the actual count of each shipped level is stored in `ccFlowCounts`.
/// Chosen so colour load increases monotonically and each band is generable to
/// 10k unique single-solution boards (see [ccToughnessMin]/[ccToughnessMax]).
const List<List<int>> ccFlowSets = [
  [4, 5], // Easy   5x5  (Flow Free 5x5 ≈ 4-5 colours)
  [7], // Medium 7x7  (fewest feasible — long paths, ~1% unique yield)
  [14], // Hard   9x9  (feasibility floor — below this 10k won't build)
];

/// Representative (max) colour count per difficulty — for labels/metadata.
int ccFlows(int diffIndex) => ccFlowSets[diffIndex.clamp(0, 2)].last;

List<int> _neighbors(int idx, int rows, int cols) {
  final r = idx ~/ cols, c = idx % cols;
  final res = <int>[];
  if (r > 0) res.add((r - 1) * cols + c);
  if (r < rows - 1) res.add((r + 1) * cols + c);
  if (c > 0) res.add(r * cols + c - 1);
  if (c < cols - 1) res.add(r * cols + c + 1);
  return res;
}

List<int>? _findHamiltonianPath(int rows, int cols, math.Random rng) {
  final n = rows * cols;
  final visited = List<bool>.filled(n, false);
  final path = <int>[];
  final start = rng.nextInt(n);
  visited[start] = true;
  path.add(start);
  while (path.length < n) {
    final cur = path.last;
    final nbs = _neighbors(cur, rows, cols)..shuffle(rng);
    int best = -1, bestDeg = 999;
    for (final nb in nbs) {
      if (visited[nb]) continue;
      int deg = 0;
      for (final nb2 in _neighbors(nb, rows, cols)) {
        if (!visited[nb2]) deg++;
      }
      if (deg < bestDeg) { bestDeg = deg; best = nb; }
    }
    if (best == -1) return null;
    visited[best] = true;
    path.add(best);
  }
  return path;
}

ColorConnectLevelResult? buildColorConnectPuzzle(
    int rows, int cols, int numFlows, math.Random rng) {
  final n = rows * cols;
  if (numFlows < 2 || numFlows * 2 > n) return null;

  List<int>? hamPath;
  for (int attempt = 0; attempt < 50; attempt++) {
    hamPath = _findHamiltonianPath(rows, cols, math.Random(rng.nextInt(1 << 30)));
    if (hamPath != null && hamPath.length == n) break;
    hamPath = null;
  }
  if (hamPath == null) return null;

  final minSegLen = 3;
  if (n < numFlows * minSegLen) return null;

  final cuts = <int>[0];
  final remaining = n - numFlows * minSegLen;
  final extras = List<int>.filled(numFlows, 0);
  for (int i = 0; i < remaining; i++) {
    extras[rng.nextInt(numFlows)]++;
  }
  int pos = 0;
  for (int f = 0; f < numFlows - 1; f++) {
    pos += minSegLen + extras[f];
    cuts.add(pos);
  }
  cuts.add(n);

  final grid = List<int>.filled(n, -1);
  final endpoints = <int>[];

  for (int f = 0; f < numFlows; f++) {
    final segStart = cuts[f];
    final segEnd = cuts[f + 1];
    for (int i = segStart; i < segEnd; i++) {
      grid[hamPath[i]] = f;
    }
    endpoints.add(hamPath[segStart]);
    endpoints.add(hamPath[segEnd - 1]);
  }

  return ColorConnectLevelResult(
    rows: rows,
    cols: cols,
    numFlows: numFlows,
    endpoints: endpoints,
    solution: grid,
  );
}

int countColorConnectSolutions(ColorConnectLevelResult puzzle,
    {int cap = 2, int nodeLimit = 4000000}) {
  final rows = puzzle.rows, cols = puzzle.cols, n = rows * cols;
  final numFlows = puzzle.numFlows;
  final ep = puzzle.endpoints;

  final adj = List.generate(n, (i) => _neighbors(i, rows, cols), growable: false);

  final grid = List<int>.filled(n, -1);
  for (int f = 0; f < numFlows; f++) {
    grid[ep[f * 2]] = f;
    grid[ep[f * 2 + 1]] = f;
  }

  final heads = List<int>.generate(numFlows, (f) => ep[f * 2]);
  final done = List<bool>.filled(numFlows, false);
  int doneCount = 0;

  int found = 0;
  int nodes = 0;
  bool aborted = false;

  final mark = List<int>.filled(n, 0);
  int token = 0;
  final fstack = List<int>.filled(n, 0);

  bool reachable(int from, int to) {
    if (from == to) return true;
    for (final nb in adj[from]) {
      if (nb == to) return true;
    }
    token++;
    int top = 0;
    mark[from] = token;
    fstack[top++] = from;
    while (top > 0) {
      final cur = fstack[--top];
      for (final nb in adj[cur]) {
        if (mark[nb] == token) continue;
        if (nb == to) return true;
        if (grid[nb] >= 0) continue;
        mark[nb] = token;
        fstack[top++] = nb;
      }
    }
    return false;
  }

  bool hasDeadEnd() {
    for (int i = 0; i < n; i++) {
      if (grid[i] >= 0) continue;
      int openNb = 0;
      bool isHead = false;
      for (int f = 0; f < numFlows; f++) {
        if (!done[f] && heads[f] == i) { isHead = true; break; }
      }
      if (isHead) continue;
      for (final nb in adj[i]) {
        if (grid[nb] < 0) { openNb++; continue; }
        for (int f = 0; f < numFlows; f++) {
          if (!done[f] && heads[f] == nb) { openNb++; break; }
        }
      }
      if (openNb == 0) return true;
    }
    return false;
  }

  bool pruneOk(int filled) {
    if (hasDeadEnd()) return false;
    for (int f = 0; f < numFlows; f++) {
      if (done[f]) continue;
      if (!reachable(heads[f], ep[f * 2 + 1])) return false;
    }
    return true;
  }

  void dfs(int filled) {
    if (aborted || found >= cap) return;
    if (++nodes > nodeLimit) { aborted = true; return; }

    if (doneCount == numFlows) {
      if (filled == n) found++;
      return;
    }

    int bestFlow = -1, bestOpts = 999;
    for (int f = 0; f < numFlows; f++) {
      if (done[f]) continue;
      final cur = heads[f];
      int opts = 0;
      for (final nb in adj[cur]) {
        if (nb == ep[f * 2 + 1] && grid[nb] == f) { opts++; continue; }
        if (grid[nb] < 0) opts++;
      }
      if (opts == 0) return;
      if (opts < bestOpts) { bestOpts = opts; bestFlow = f; }
    }
    if (bestFlow < 0) return;

    final cur = heads[bestFlow];
    final target = ep[bestFlow * 2 + 1];

    for (final nb in adj[cur]) {
      if (found >= cap || aborted) return;
      if (nb == target && grid[nb] == bestFlow) {
        done[bestFlow] = true;
        doneCount++;
        final old = heads[bestFlow]; heads[bestFlow] = nb;
        dfs(filled);
        doneCount--;
        done[bestFlow] = false; heads[bestFlow] = old;
      } else if (grid[nb] < 0) {
        grid[nb] = bestFlow;
        final old = heads[bestFlow]; heads[bestFlow] = nb;
        if (pruneOk(filled + 1)) {
          dfs(filled + 1);
        }
        heads[bestFlow] = old; grid[nb] = -1;
      }
    }
  }

  dfs(numFlows * 2);
  if (aborted) return cap;
  return found;
}

bool ccSolvable(ColorConnectLevelResult p) =>
    countColorConnectSolutions(p, cap: 2) == 1;

// ---------------------------------------------------------------------------
// Toughness metric
//
// Difficulty proxy = how many path cells are genuine "free choices" rather than
// forced moves, as faced by a minimum-remaining-values logical solver.
//
// We replay the KNOWN unique solution. At each step we look at every flow that
// still has cells to lay, count its head's viable continuations (empty
// neighbours, plus its target endpoint when adjacent), and — mirroring how a
// careful human solves — always extend the most-constrained head first (MRV).
// If the head we extend had MORE THAN ONE viable continuation, the player had a
// real decision to make there, so we count it. A puzzle whose every cell is
// forced (toughness 0) can be filled with no look-ahead at all (trivial); a
// higher count means more points where the player must reason about which way a
// path should turn.
//
// Computable from (endpoints, solution) alone, deterministic, and cheap — run
// once per accepted puzzle during generation and asserted by the band tests.
// ---------------------------------------------------------------------------
int ccToughness(ColorConnectLevelResult p) {
  final rows = p.rows, cols = p.cols, n = rows * cols;
  final numFlows = p.numFlows;
  final ep = p.endpoints;
  final adj = List.generate(n, (i) => _neighbors(i, rows, cols), growable: false);

  // cell -> flow, from the solution.
  final sol = p.solution;

  // Working grid: endpoints pre-filled, interior cells laid as heads advance.
  final grid = List<int>.filled(n, -1);
  for (int f = 0; f < numFlows; f++) {
    grid[ep[f * 2]] = f;
    grid[ep[f * 2 + 1]] = f;
  }

  final heads = List<int>.generate(numFlows, (f) => ep[f * 2]);
  final target = List<int>.generate(numFlows, (f) => ep[f * 2 + 1]);
  final done = List<bool>.filled(numFlows, false);
  // A flow is already done if its two endpoints are adjacent and the solution
  // path between them is just the two endpoints (length-2 flow).
  int doneCount = 0;
  for (int f = 0; f < numFlows; f++) {
    int cells = 0;
    for (int i = 0; i < n; i++) {
      if (sol[i] == f) cells++;
    }
    if (cells == 2) {
      done[f] = true;
      doneCount++;
    }
  }

  int viableOpts(int f) {
    final cur = heads[f];
    int opts = 0;
    for (final nb in adj[cur]) {
      if (nb == target[f]) {
        opts++;
        continue;
      }
      if (grid[nb] < 0) opts++;
    }
    return opts;
  }

  // Next cell along flow f's solution path from its current head: the unique
  // solution-cell of f adjacent to the head that hasn't been laid yet.
  int nextSolCell(int f) {
    final cur = heads[f];
    for (final nb in adj[cur]) {
      if (sol[nb] == f && grid[nb] != f) return nb;
    }
    return -1;
  }

  int toughness = 0;
  while (doneCount < numFlows) {
    int bestFlow = -1, bestOpts = 1 << 30;
    for (int f = 0; f < numFlows; f++) {
      if (done[f]) continue;
      final o = viableOpts(f);
      if (o < bestOpts) {
        bestOpts = o;
        bestFlow = f;
        if (bestOpts <= 1) break;
      }
    }
    if (bestFlow < 0) break;
    if (bestOpts > 1) toughness++;

    final nxt = nextSolCell(bestFlow);
    if (nxt < 0) break; // solution malformed; metric meaningless
    grid[nxt] = bestFlow;
    heads[bestFlow] = nxt;
    if (nxt == target[bestFlow]) {
      done[bestFlow] = true;
      doneCount++;
    }
  }
  return toughness;
}

// Per-difficulty toughness QUALITY GATES (not the cross-grid difficulty
// separator — that is the board size + colour count, which both increase
// monotonically Easy → Medium → Hard). A 9x9 board can't hold long winding
// paths and still be bulk-generable with a single solution, so its felt
// difficulty comes from size + colour load rather than deduction depth; these
// bands instead keep each difficulty internally consistent:
//   Easy   → 0..3 : capped low so Easy stays gentle (no fluke-hard boards).
//   Medium → 1..7 : floored so trivial all-forced boards are excluded.
//   Hard   → 1..  : floored so the rare fully-forced board is excluded.
// Calibrated from the measured toughness distributions of the chosen flow sets
// (Easy 5x5/5-6, Medium 7x7/9-10, Hard 9x9/15-16).
const List<int> ccToughnessMin = [0, 1, 1];
const List<int> ccToughnessMax = [3, 7, 1 << 30];

bool ccToughnessOk(int diffIndex, int toughness) {
  final d = diffIndex.clamp(0, 2);
  return toughness >= ccToughnessMin[d] && toughness <= ccToughnessMax[d];
}

String ccSignature(ColorConnectLevelResult r) {
  final sb = StringBuffer('${r.rows}x${r.cols}|${r.numFlows}|');
  sb.write(r.endpoints.join(','));
  return sb.toString();
}

int ccStrideBytes(int rows, int cols, int numFlows) {
  final n = rows * cols;
  final epBits = numFlows * 2 * 8;
  final solBits = n * 8;
  return (epBits + solBits + 7) >> 3;
}

Uint8List ccEncodeLevel(ColorConnectLevelResult r) {
  final n = r.rows * r.cols;
  final numEp = r.numFlows * 2;
  final totalBits = (numEp + n) * 8;
  final out = Uint8List((totalBits + 7) >> 3);
  int bit = 0;
  void putBits(int val, int count) {
    for (int i = 0; i < count; i++) {
      if ((val >> i) & 1 != 0) out[bit >> 3] |= 1 << (bit & 7);
      bit++;
    }
  }
  for (int i = 0; i < numEp; i++) {
    putBits(r.endpoints[i], 8);
  }
  for (int i = 0; i < n; i++) {
    putBits(r.solution[i], 8);
  }
  return out;
}

ColorConnectLevelResult ccDecodeLevel(
    int rows, int cols, int numFlows, Uint8List bytes) {
  final n = rows * cols;
  final numEp = numFlows * 2;
  int bit = 0;
  int getBits(int count) {
    int val = 0;
    for (int i = 0; i < count; i++) {
      val |= ((bytes[bit >> 3] >> (bit & 7)) & 1) << i;
      bit++;
    }
    return val;
  }
  final endpoints = List<int>.generate(numEp, (_) => getBits(8));
  final solution = List<int>.generate(n, (_) => getBits(8));
  return ColorConnectLevelResult(
    rows: rows,
    cols: cols,
    numFlows: numFlows,
    endpoints: endpoints,
    solution: solution,
  );
}

final List<Uint8List?> _packedCache = List<Uint8List?>.filled(3, null);

Uint8List _packedBytes(int diffIndex) {
  final cached = _packedCache[diffIndex];
  if (cached != null) return cached;
  final bytes = base64Decode(ccPacked[diffIndex]);
  _packedCache[diffIndex] = bytes;
  return bytes;
}

ColorConnectLevelResult generateColorConnectLevel(int level, int diffIndex) {
  final rows = ccRows(diffIndex);
  final cols = ccCols(diffIndex);
  final effLevel = (level - 1) % ccLevelsPerDifficulty;
  final numFlows = ccFlowCounts[diffIndex][effLevel];
  final stride = ccStrideBytes(rows, cols, numFlows);
  final offset = ccOffsets[diffIndex][effLevel];
  final bytes = _packedBytes(diffIndex);
  final view = Uint8List.sublistView(bytes, offset, offset + stride);
  return ccDecodeLevel(rows, cols, numFlows, view);
}
