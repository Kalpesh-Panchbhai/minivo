import 'dart:math' as math;

import 'queens_puzzle_seeds.g.dart';

int boardSizeForLevel(int level, int diffIndex) {
  switch (diffIndex) {
    case 0:
      return 5;
    case 1:
      if (level <= 8) return 6;
      return 7;
    case 2:
      if (level <= 5) return 7;
      return 8;
    default:
      return 5;
  }
}

class QueensPuzzleLevelResult {
  final int boardSize;
  final List<int> queenCols;
  final List<List<int>> regions;

  QueensPuzzleLevelResult({
    required this.boardSize,
    required this.queenCols,
    required this.regions,
  });
}

int _seed(int level, int diffIndex, int salt) {
  int h = level * 2654435761 + diffIndex * 2246822519 + salt * 3266489917;
  h = ((h >> 16) ^ h) * 0x45d9f3b;
  h = ((h >> 16) ^ h) * 0x45d9f3b;
  h = (h >> 16) ^ h;
  return h.abs();
}

List<int>? _placeQueens(int n, math.Random rng) {
  final cols = List<int>.filled(n, -1);
  final usedCols = List<bool>.filled(n, false);

  bool safe(int row, int col) {
    if (usedCols[col]) return false;
    for (int r = 0; r < row; r++) {
      final c = cols[r];
      if (c < 0) continue;
      if ((r - row).abs() <= 1 && (c - col).abs() <= 1) return false;
    }
    return true;
  }

  bool solve(int row) {
    if (row == n) return true;
    final order = List.generate(n, (i) => i)..shuffle(rng);
    for (final col in order) {
      if (safe(row, col)) {
        cols[row] = col;
        usedCols[col] = true;
        if (solve(row + 1)) return true;
        cols[row] = -1;
        usedCols[col] = false;
      }
    }
    return false;
  }

  if (solve(0)) return cols;
  return null;
}

List<int> _cellNeighbors(int idx, int n) {
  final r = idx ~/ n, c = idx % n;
  final res = <int>[];
  if (r > 0) res.add((r - 1) * n + c);
  if (r < n - 1) res.add((r + 1) * n + c);
  if (c > 0) res.add(r * n + c - 1);
  if (c < n - 1) res.add(r * n + c + 1);
  return res;
}

List<List<int>> _generateRegions(int n, List<int> queenCols, math.Random rng) {
  final total = n * n;
  final par = List.generate(total, (i) => i);
  final rnk = List<int>.filled(total, 0);

  int find(int x) {
    while (par[x] != x) {
      par[x] = par[par[x]];
      x = par[x];
    }
    return x;
  }

  void unite(int a, int b) {
    a = find(a);
    b = find(b);
    if (a == b) return;
    if (rnk[a] < rnk[b]) {
      final t = a;
      a = b;
      b = t;
    }
    par[b] = a;
    if (rnk[a] == rnk[b]) rnk[a]++;
  }

  final queenIdx = List.generate(n, (r) => r * n + queenCols[r]);

  final edges = <List<int>>[];
  for (int r = 0; r < n; r++) {
    for (int c = 0; c < n; c++) {
      final idx = r * n + c;
      if (c < n - 1) edges.add([idx, idx + 1]);
      if (r < n - 1) edges.add([idx, idx + n]);
    }
  }
  edges.shuffle(rng);

  final compQueen = List<int>.filled(total, -1);
  for (int q = 0; q < n; q++) {
    compQueen[queenIdx[q]] = q;
  }

  int comps = total;
  for (final edge in edges) {
    if (comps <= n) break;
    final ra = find(edge[0]), rb = find(edge[1]);
    if (ra == rb) continue;
    final qa = compQueen[ra], qb = compQueen[rb];
    if (qa >= 0 && qb >= 0) continue;
    unite(ra, rb);
    final nr = find(edge[0]);
    compQueen[nr] = qa >= 0 ? qa : qb;
    comps--;
  }

  for (int pass = 0; pass < 10; pass++) {
    bool changed = false;
    for (int i = 0; i < total; i++) {
      final ri = find(i);
      if (compQueen[ri] >= 0) continue;
      for (final nb in _cellNeighbors(i, n)) {
        final rn = find(nb);
        if (compQueen[rn] >= 0) {
          final q = compQueen[rn];
          unite(ri, rn);
          compQueen[find(i)] = q;
          changed = true;
          break;
        }
      }
    }
    if (!changed) break;
  }

  final regions = List.generate(n, (_) => <int>[]);
  for (int i = 0; i < total; i++) {
    final root = find(i);
    final q = compQueen[root];
    regions[q >= 0 ? q : 0].add(i);
  }
  return regions;
}

QueensPuzzleLevelResult _build(int level, int diffIndex, int salt) {
  final rng = math.Random(_seed(level, diffIndex, salt));
  final n = boardSizeForLevel(level, diffIndex);

  List<int>? queens;
  for (int attempt = 0; attempt < 200; attempt++) {
    queens = _placeQueens(n, math.Random(rng.nextInt(1 << 30)));
    if (queens != null) break;
  }
  queens ??= List.generate(n, (i) => i);

  final regions = _generateRegions(n, queens, rng);

  return QueensPuzzleLevelResult(
    boardSize: n,
    queenCols: queens,
    regions: regions,
  );
}

QueensPuzzleLevelResult generateQueensPuzzleLevelWithSalt(int level, int diffIndex, int salt) =>
    _build(level, diffIndex, salt);

QueensPuzzleLevelResult generateQueensPuzzleLevel(int level, int diffIndex) {
  final effLevel = (level - 1) % queensPuzzleLevelsPerDifficulty + 1;
  return _build(effLevel, diffIndex, queensPuzzleSaltFor(effLevel, diffIndex));
}

int countQueensPuzzleSolutions(QueensPuzzleLevelResult r, {int cap = 2}) {
  final n = r.boardSize;
  final regionOf = List<int>.filled(n * n, -1);
  for (int reg = 0; reg < r.regions.length; reg++) {
    for (final idx in r.regions[reg]) {
      regionOf[idx] = reg;
    }
  }

  final colUsed = List<bool>.filled(n, false);
  final regionUsed = List<bool>.filled(n, false);
  final queenCols = List<int>.filled(n, -1);
  int found = 0;

  bool noAdjacent(int row, int col) {
    if (row > 0) {
      final pc = queenCols[row - 1];
      if (pc >= 0 && (pc - col).abs() <= 1) return false;
    }
    return true;
  }

  void solve(int row) {
    if (found >= cap) return;
    if (row == n) {
      found++;
      return;
    }
    for (int col = 0; col < n; col++) {
      if (colUsed[col]) continue;
      final reg = regionOf[row * n + col];
      if (reg < 0 || regionUsed[reg]) continue;
      if (!noAdjacent(row, col)) continue;
      colUsed[col] = true;
      regionUsed[reg] = true;
      queenCols[row] = col;
      solve(row + 1);
      colUsed[col] = false;
      regionUsed[reg] = false;
      queenCols[row] = -1;
      if (found >= cap) return;
    }
  }

  solve(0);
  return found;
}
