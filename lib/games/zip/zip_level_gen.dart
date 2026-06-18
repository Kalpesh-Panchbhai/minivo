import 'dart:math' as math;

import 'zip_seeds.g.dart';

// ---------------------------------------------------------------------------
// Difficulty curves
// ---------------------------------------------------------------------------

int gridSizeForLevel(int level, int diffIndex) {
  switch (diffIndex) {
    case 0:
      if (level <= 8) return 5;
      if (level <= 20) return 6;
      return 7;
    case 1:
      if (level <= 6) return 6;
      if (level <= 15) return 7;
      return 8;
    case 2:
      if (level <= 5) return 7;
      if (level <= 12) return 8;
      return 9;
    default:
      return 5;
  }
}

int cpCount(int n, int level, int diffIndex) {
  final total = n * n;
  final raw = switch (diffIndex) {
    0 => 3 + math.min(level ~/ 4, 4),
    1 => 4 + math.min(level ~/ 3, 6),
    2 => 5 + math.min(level ~/ 2, 8),
    _ => 3,
  };
  return raw.clamp(2, total ~/ 3).toInt();
}

/// Max number of edges that can be removed (the cap of each difficulty's
/// confirmed wall range): Easy 4 · Medium 12 · Hard 20.
int wallMaxForDiff(int diffIndex) => const [4, 12, 20][diffIndex];

int wallCount(int n, int level, int diffIndex) {
  final maxW = (2 * n * (n - 1)) ~/ 4;
  final raw = switch (diffIndex) {
    0 => math.min(level ~/ 3, 4),
    1 => 2 + math.min(level ~/ 2, 10),
    2 => 4 + math.min(level, 18),
    _ => 0,
  };
  return raw.clamp(0, math.min(maxW, wallMaxForDiff(diffIndex))).toInt();
}

// ---------------------------------------------------------------------------
// Grid helpers
// ---------------------------------------------------------------------------

String edgeKey(int a, int b) {
  final lo = math.min(a, b), hi = math.max(a, b);
  return '$lo:$hi';
}

List<int> getNeighbors(int idx, int n) {
  final r = idx ~/ n, c = idx % n;
  final res = <int>[];
  if (r > 0) res.add((r - 1) * n + c);
  if (r < n - 1) res.add((r + 1) * n + c);
  if (c > 0) res.add(r * n + c - 1);
  if (c < n - 1) res.add(r * n + c + 1);
  return res;
}

int _unvisitedDeg(int idx, List<bool> visited, int n) {
  int c = 0;
  for (final nb in getNeighbors(idx, n)) {
    if (!visited[nb]) c++;
  }
  return c;
}

/// Warnsdorff-guided random Hamiltonian path search.
List<int>? findHamiltonianPath(int n, math.Random rng) {
  final total = n * n;
  final visited = List.filled(total, false);
  final path = <int>[];
  final start = rng.nextInt(total);
  visited[start] = true;
  path.add(start);
  while (path.length < total) {
    final cur = path.last;
    final nbs = getNeighbors(cur, n)..shuffle(rng);
    int best = -1, bestDeg = 999;
    for (final nb in nbs) {
      if (visited[nb]) continue;
      final deg = _unvisitedDeg(nb, visited, n);
      if (deg < bestDeg) {
        bestDeg = deg;
        best = nb;
      }
    }
    if (best == -1) return null;
    visited[best] = true;
    path.add(best);
  }
  return path;
}

List<int> generateSnakePath(int n) {
  final p = <int>[];
  for (int r = 0; r < n; r++) {
    if (r.isEven) {
      for (int c = 0; c < n; c++) {
        p.add(r * n + c);
      }
    } else {
      for (int c = n - 1; c >= 0; c--) {
        p.add(r * n + c);
      }
    }
  }
  return p;
}

/// `cp` distinct, evenly spread path indices in [0, total-1] — always including
/// the endpoints 0 and total-1 so checkpoint #1 starts the path and the highest
/// checkpoint ends it.
List<int> _spreadIndices(int total, int cp) {
  cp = cp.clamp(2, total);
  if (cp >= total) return List.generate(total, (i) => i);
  final s = <int>{0, total - 1};
  for (int i = 1; i < cp - 1; i++) {
    s.add((i * (total - 1) / (cp - 1)).round());
  }
  int probe = 1;
  while (s.length < cp) {
    if (!s.contains(probe)) s.add(probe);
    probe++;
    if (probe >= total - 1) probe = 1;
  }
  final list = s.toList()..sort();
  return list;
}

// ---------------------------------------------------------------------------
// Level model
// ---------------------------------------------------------------------------

class ZipLevelResult {
  final int gridSize;
  final List<int> solutionPath;
  final Set<String> walls;

  /// Maps a path index -> checkpoint number. The numbered cell is
  /// `solutionPath[pathIndex]`. Checkpoint #1 is always at index 0 (the start),
  /// the highest checkpoint at index `gridSize*gridSize - 1` (the end).
  final Map<int, int> checkpoints;

  ZipLevelResult({
    required this.gridSize,
    required this.solutionPath,
    required this.walls,
    required this.checkpoints,
  });
}

// ---------------------------------------------------------------------------
// Salt-driven escalation
//
// A level is a pure deterministic function of (level, diffIndex, salt). The
// offline generator increments `salt` until the puzzle has exactly one
// solution; the winning salt is baked into zip_seeds.g.dart and replayed on
// device. As `salt` grows we (1) vary the path/wall layout via the RNG seed,
// (2) raise the wall count toward the difficulty's range max, then (3) raise
// the checkpoint count. Since checkpoints eventually reach every cell, a unique
// configuration is always reachable, so the search terminates.
// ---------------------------------------------------------------------------

const int _kEscalateEvery = 8;

int _seed(int level, int diffIndex, int salt) {
  int h = level * 2654435761 + diffIndex * 2246822519 + salt * 3266489917;
  h = ((h >> 16) ^ h) * 0x45d9f3b;
  h = ((h >> 16) ^ h) * 0x45d9f3b;
  h = (h >> 16) ^ h;
  return h.abs();
}

int _wallCountForSalt(int n, int level, int diffIndex, int salt) {
  final base = wallCount(n, level, diffIndex);
  final cap = math.min((2 * n * (n - 1)) ~/ 4, wallMaxForDiff(diffIndex));
  return math.min(base + salt ~/ _kEscalateEvery, cap);
}

int _cpCountForSalt(int n, int level, int diffIndex, int salt) {
  final total = n * n;
  final base = cpCount(n, level, diffIndex);
  final cap = math.min((2 * n * (n - 1)) ~/ 4, wallMaxForDiff(diffIndex));
  final wallRoom = cap - wallCount(n, level, diffIndex);
  // Only start adding checkpoints once wall escalation is exhausted.
  final extra = math.max(0, salt ~/ _kEscalateEvery - wallRoom);
  return (base + extra).clamp(2, total).toInt();
}

ZipLevelResult _build(int level, int diffIndex, int salt) {
  final rng = math.Random(_seed(level, diffIndex, salt));
  final n = gridSizeForLevel(level, diffIndex);
  final total = n * n;

  List<int>? path;
  for (int attempt = 0; attempt < 100; attempt++) {
    path = findHamiltonianPath(n, math.Random(rng.nextInt(1 << 30)));
    if (path != null && path.length == total) break;
    path = null;
  }
  path ??= generateSnakePath(n);

  final pathEdges = <String>{};
  for (int i = 0; i < path.length - 1; i++) {
    pathEdges.add(edgeKey(path[i], path[i + 1]));
  }

  final numWalls = _wallCountForSalt(n, level, diffIndex, salt);
  final candidates = <String>[];
  for (int r = 0; r < n; r++) {
    for (int c = 0; c < n; c++) {
      final idx = r * n + c;
      if (c < n - 1) {
        final k = edgeKey(idx, idx + 1);
        if (!pathEdges.contains(k)) candidates.add(k);
      }
      if (r < n - 1) {
        final k = edgeKey(idx, idx + n);
        if (!pathEdges.contains(k)) candidates.add(k);
      }
    }
  }
  candidates.shuffle(rng);
  final walls = candidates.take(numWalls).toSet();

  final numCp = _cpCountForSalt(n, level, diffIndex, salt);
  final positions = _spreadIndices(total, numCp);
  final checkpoints = <int, int>{};
  for (int i = 0; i < positions.length; i++) {
    checkpoints[positions[i]] = i + 1;
  }

  return ZipLevelResult(
    gridSize: n,
    solutionPath: path,
    walls: walls,
    checkpoints: checkpoints,
  );
}

/// Build a level for an explicit salt — used by the offline generator and tests.
ZipLevelResult generateZipLevelWithSalt(int level, int diffIndex, int salt) =>
    _build(level, diffIndex, salt);

/// Build the on-device level: looks up the offline-verified unique salt and
/// rebuilds it deterministically. No solver runs here.
///
/// The 10k pre-generated puzzles per difficulty repeat forever — level 10001
/// plays puzzle 1, 10002 plays puzzle 2, and so on — while the displayed level
/// counter keeps climbing. The effective puzzle index drives BOTH the salt
/// lookup and the build so the replayed level is byte-identical to (and as
/// strictly-unique as) its original.
ZipLevelResult generateZipLevel(int level, int diffIndex) {
  final effLevel = (level - 1) % zipLevelsPerDifficulty + 1;
  return _build(effLevel, diffIndex, zipSaltFor(effLevel, diffIndex));
}

// ---------------------------------------------------------------------------
// Uniqueness solver
//
// Counts the distinct valid solutions of a Zip puzzle, capped at [cap]. A valid
// solution is a Hamiltonian path that:
//   * starts at checkpoint #1's cell (the player is forced to start there),
//   * never crosses a wall,
//   * visits numbered cells in strictly increasing numeric order.
// The end cell is free (the player may continue past the highest checkpoint).
// "Strictly solvable" == exactly one such path == countZipSolutions(r) == 1.
// ---------------------------------------------------------------------------

int countZipSolutions(ZipLevelResult r, {int cap = 2, int nodeLimit = 8000000}) {
  final n = r.gridSize;
  final total = n * n;

  final cellCp = List<int>.filled(total, 0); // 0 == not a checkpoint
  int maxCp = 0;
  r.checkpoints.forEach((pathIdx, value) {
    cellCp[r.solutionPath[pathIdx]] = value;
    if (value > maxCp) maxCp = value;
  });
  final start = r.solutionPath[0];

  // Adjacency with walls removed.
  final adj = List.generate(total, (i) {
    final res = <int>[];
    for (final nb in getNeighbors(i, n)) {
      if (!r.walls.contains(edgeKey(i, nb))) res.add(nb);
    }
    return res;
  }, growable: false);

  final visited = List<bool>.filled(total, false);

  // Flood-fill scratch (token avoids re-allocation between prune calls).
  final mark = List<int>.filled(total, 0);
  int token = 0;
  final stack = List<int>.filled(total, 0);

  // All unvisited cells must remain reachable from [from] through unvisited
  // cells. If any unvisited cell is cut off, no Hamiltonian completion exists.
  bool connected(int from, int remaining) {
    token++;
    int top = 0, seen = 0;
    for (final nb in adj[from]) {
      if (!visited[nb] && mark[nb] != token) {
        mark[nb] = token;
        stack[top++] = nb;
      }
    }
    while (top > 0) {
      final cur = stack[--top];
      seen++;
      for (final nb in adj[cur]) {
        if (!visited[nb] && mark[nb] != token) {
          mark[nb] = token;
          stack[top++] = nb;
        }
      }
    }
    return seen == remaining;
  }

  int found = 0;
  int nodes = 0;
  bool aborted = false;

  void dfs(int cur, int count, int nextCp) {
    if (aborted) return;
    if (++nodes > nodeLimit) {
      aborted = true;
      return;
    }
    if (count == total) {
      if (nextCp == maxCp + 1) found++;
      return;
    }
    final remaining = total - count;
    for (final nb in adj[cur]) {
      if (visited[nb]) continue;
      final cpv = cellCp[nb];
      int nNext = nextCp;
      if (cpv != 0) {
        if (cpv != nextCp) continue; // out of order
        nNext = nextCp + 1;
      }
      visited[nb] = true;
      // remaining-1 cells will be left after stepping to nb.
      if (remaining - 1 == 0 || connected(nb, remaining - 1)) {
        dfs(nb, count + 1, nNext);
      }
      visited[nb] = false;
      if (found >= cap || aborted) return;
    }
  }

  visited[start] = true;
  dfs(start, 1, cellCp[start] == 1 ? 2 : 1);
  // A node-limit abort means "could not prove uniqueness" — report >1 so the
  // offline generator rejects this salt rather than baking an unverified level.
  if (aborted) return cap;
  return found;
}
