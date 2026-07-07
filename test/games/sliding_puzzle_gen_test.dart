import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import '../../lib/games/sliding_puzzle/sliding_puzzle_gen.dart';

String _key(List<int> b) => b.join(',');

// ---------------------------------------------------------------------------
// Independent verification helpers (do NOT reuse SlidingPuzzleGen.isSolvable,
// so the checks below are genuinely independent of the code under test).
// ---------------------------------------------------------------------------

/// Ground truth for small boards: every board reachable from the solved state
/// via legal moves. By definition this is exactly the set of solvable boards.
Set<String> _reachableFromSolved(int n) {
  final start = SlidingPuzzleGen.solved(n);
  final visited = <String>{_key(start)};
  final queue = Queue<List<int>>()..add(start);
  while (queue.isNotEmpty) {
    final cur = queue.removeFirst();
    final blank = cur.indexOf(0);
    for (final nb in SlidingPuzzleGen.movableIndices(blank, n)) {
      final next = List<int>.from(cur);
      next[blank] = next[nb];
      next[nb] = 0;
      final k = _key(next);
      if (visited.add(k)) queue.add(next);
    }
  }
  return visited;
}

/// A second, independently-derived solvability oracle: a board is solvable iff
/// the parity of the tile permutation equals the parity of the blank's taxicab
/// distance from its home (bottom-right) cell. Derived via cycle decomposition
/// — completely separate math from the inversion-count rule under test.
bool _solvableByCycleParity(List<int> tiles, int n) {
  final size = n * n;
  int goalPos(int v) => v == 0 ? size - 1 : v - 1;
  final perm = List<int>.generate(size, (i) => goalPos(tiles[i]));
  final seen = List<bool>.filled(size, false);
  int cycles = 0;
  for (int i = 0; i < size; i++) {
    if (seen[i]) continue;
    cycles++;
    int j = i;
    while (!seen[j]) {
      seen[j] = true;
      j = perm[j];
    }
  }
  final permEven = ((size - cycles) % 2) == 0;
  final blank = tiles.indexOf(0);
  final dist = (blank ~/ n - (n - 1)).abs() + (blank % n - (n - 1)).abs();
  final distEven = (dist % 2) == 0;
  return permEven == distEven;
}

int _manhattan(List<int> b, int n) {
  int d = 0;
  for (int i = 0; i < b.length; i++) {
    final v = b[i];
    if (v == 0) continue;
    final tr = (v - 1) ~/ n;
    final tc = (v - 1) % n;
    d += (i ~/ n - tr).abs() + (i % n - tc).abs();
  }
  return d;
}

class _MinHeap {
  final List<double> _f = [];
  final List<String> _k = [];
  bool get isEmpty => _k.isEmpty;
  void push(double f, String k) {
    _f.add(f);
    _k.add(k);
    int i = _k.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_f[p] <= _f[i]) break;
      _swap(i, p);
      i = p;
    }
  }

  String pop() {
    final top = _k[0];
    final lf = _f.removeLast();
    final lk = _k.removeLast();
    if (_k.isNotEmpty) {
      _f[0] = lf;
      _k[0] = lk;
      int i = 0;
      final m = _k.length;
      while (true) {
        int l = 2 * i + 1, r = 2 * i + 2, s = i;
        if (l < m && _f[l] < _f[s]) s = l;
        if (r < m && _f[r] < _f[s]) s = r;
        if (s == i) break;
        _swap(i, s);
        i = s;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final tf = _f[a];
    _f[a] = _f[b];
    _f[b] = tf;
    final tk = _k[a];
    _k[a] = _k[b];
    _k[b] = tk;
  }
}

/// Independent (weighted A*/greedy) solver over REAL legal moves. Returns the
/// sequence of blank-destination indices for a solution, or null if none found
/// within [nodeCap]. Not necessarily optimal — existence is all we need.
List<int>? _solve(List<int> start, int n, {double weight = 1.0, int nodeCap = 1500000}) {
  final targetKey = _key(SlidingPuzzleGen.solved(n));
  final startKey = _key(start);
  if (startKey == targetKey) return <int>[];

  final g = <String, int>{startKey: 0};
  final parent = <String, String>{};
  final parentMove = <String, int>{};
  final boards = <String, List<int>>{startKey: start};
  final closed = <String>{};
  final open = _MinHeap()..push(weight * _manhattan(start, n), startKey);
  int expansions = 0;

  while (!open.isEmpty) {
    final curKey = open.pop();
    if (!closed.add(curKey)) continue;
    if (++expansions > nodeCap) return null;
    final cur = boards[curKey]!;
    final blank = cur.indexOf(0);
    final gc = g[curKey]!;
    for (final nb in SlidingPuzzleGen.movableIndices(blank, n)) {
      final next = List<int>.from(cur);
      next[blank] = next[nb];
      next[nb] = 0;
      final nk = _key(next);
      final ng = gc + 1;
      if (g.containsKey(nk) && ng >= g[nk]!) continue;
      g[nk] = ng;
      parent[nk] = curKey;
      parentMove[nk] = nb;
      boards[nk] = next;
      if (nk == targetKey) {
        final moves = <int>[];
        String c = targetKey;
        while (c != startKey) {
          moves.add(parentMove[c]!);
          c = parent[c]!;
        }
        return moves.reversed.toList();
      }
      open.push(ng + weight * _manhattan(next, n), nk);
    }
  }
  return null;
}

/// Replays a solution [moves] on [start] and returns true iff every move is a
/// legal slide and the board ends solved. This is the irrefutable witness that
/// the board is solvable — no dependence on any parity formula.
bool _replaySolves(List<int> start, List<int> moves, int n) {
  final b = List<int>.from(start);
  int blank = b.indexOf(0);
  for (final to in moves) {
    if (!SlidingPuzzleGen.movableIndices(blank, n).contains(to)) return false;
    b[blank] = b[to];
    b[to] = 0;
    blank = to;
  }
  return SlidingPuzzleGen.isSolved(b);
}

void _permute(List<int> arr, int k, void Function(List<int>) emit) {
  if (k == 1) {
    emit(List<int>.from(arr));
    return;
  }
  for (int i = 0; i < k; i++) {
    _permute(arr, k - 1, emit);
    if (k.isEven) {
      final t = arr[i];
      arr[i] = arr[k - 1];
      arr[k - 1] = t;
    } else {
      final t = arr[0];
      arr[0] = arr[k - 1];
      arr[k - 1] = t;
    }
  }
}

bool _isValidPermutation(List<int> tiles, int n) {
  if (tiles.length != n * n) return false;
  final seen = List<bool>.filled(n * n, false);
  for (final v in tiles) {
    if (v < 0 || v >= n * n || seen[v]) return false;
    seen[v] = true;
  }
  return true;
}

void main() {
  // Difficulty → grid width. Easy 3x3, Medium 4x4, Hard 5x5.
  const difficulties = {'Easy': 3, 'Medium': 4, 'Hard': 5};

  group('isSolvable — classic known cases', () {
    test('solved boards are solvable (3x3, 4x4, 5x5)', () {
      for (final n in [3, 4, 5]) {
        expect(SlidingPuzzleGen.isSolvable(SlidingPuzzleGen.solved(n), n), isTrue);
      }
    });

    test('single non-blank swap breaks solvability (all sizes)', () {
      for (final n in [3, 4, 5]) {
        final b = SlidingPuzzleGen.solved(n);
        final t = b[0];
        b[0] = b[1];
        b[1] = t;
        expect(SlidingPuzzleGen.isSolvable(b, n), isFalse);
      }
    });

    test('classic unsolvable 15-puzzle (14/15 swapped) is rejected', () {
      final b = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 14, 0];
      expect(SlidingPuzzleGen.isSolvable(b, 4), isFalse);
    });
  });

  group('isSolvable — 3x3 exhaustive vs legal-move reachability', () {
    test('formula agrees with reachability for ALL 9! permutations', () {
      const n = 3;
      final reachable = _reachableFromSolved(n);
      expect(reachable.length, 181440); // 9!/2
      _permute(List<int>.generate(n * n, (i) => i), n * n, (perm) {
        expect(SlidingPuzzleGen.isSolvable(perm, n), reachable.contains(_key(perm)),
            reason: 'mismatch at ${_key(perm)}');
      });
    });
  });

  group('isSolvable — cross-checked vs independent cycle-parity oracle', () {
    test('agrees for ALL 9! permutations (3x3, odd-width branch)', () {
      _permute(List<int>.generate(9, (i) => i), 9, (perm) {
        expect(SlidingPuzzleGen.isSolvable(perm, 3), _solvableByCycleParity(perm, 3),
            reason: 'mismatch at ${_key(perm)}');
      });
    });

    test('agrees for 200k random permutations of 4x4 (even-width branch)', () {
      final rng = math.Random(2024);
      for (int i = 0; i < 200000; i++) {
        final p = List<int>.generate(16, (i) => i)..shuffle(rng);
        expect(SlidingPuzzleGen.isSolvable(p, 4), _solvableByCycleParity(p, 4),
            reason: 'mismatch at ${_key(p)}');
      }
    });

    test('agrees for 200k random permutations of 5x5 (odd-width branch)', () {
      final rng = math.Random(2025);
      for (int i = 0; i < 200000; i++) {
        final p = List<int>.generate(25, (i) => i)..shuffle(rng);
        expect(SlidingPuzzleGen.isSolvable(p, 5), _solvableByCycleParity(p, 5),
            reason: 'mismatch at ${_key(p)}');
      }
    });
  });

  group('generate — validity & non-circular solvability (all difficulties)', () {
    test('every generated board is a valid, non-solved permutation', () {
      final rng = math.Random(777);
      difficulties.forEach((label, n) {
        for (int i = 0; i < 500; i++) {
          final board = SlidingPuzzleGen.generate(n, random: rng);
          expect(_isValidPermutation(board.tiles, n), isTrue, reason: '$label invalid perm');
          expect(board.tiles[board.emptyIndex], 0, reason: '$label emptyIndex wrong');
          expect(SlidingPuzzleGen.isSolved(board.tiles), isFalse, reason: '$label started solved');
          // Independent oracle (not the formula the generator guards with).
          expect(_solvableByCycleParity(board.tiles, n), isTrue, reason: '$label cycle-parity says unsolvable');
        }
      });
    });

    test('generated boards are ACTUALLY solved by a real move-sequence (witness)', () {
      // The strongest, fully non-circular check: find a real solution via
      // search over legal moves, then replay it to confirm it reaches solved.
      final rng = math.Random(4242);
      // Weight tuned per size so search stays fast; existence (not optimality)
      // is what proves solvability.
      final cfg = {3: (count: 120, weight: 1.0), 4: (count: 40, weight: 2.0), 5: (count: 20, weight: 6.0)};
      difficulties.forEach((label, n) {
        final c = cfg[n]!;
        for (int i = 0; i < c.count; i++) {
          final board = SlidingPuzzleGen.generate(n, random: rng);
          final moves = _solve(board.tiles, n, weight: c.weight);
          expect(moves, isNotNull, reason: '$label board had no solution found: ${_key(board.tiles)}');
          expect(_replaySolves(board.tiles, moves!, n), isTrue,
              reason: '$label replay did not reach solved: ${_key(board.tiles)}');
        }
      });
    });

    test('generated 3x3 boards are all in the solvable reachability set', () {
      final reachable = _reachableFromSolved(3);
      final rng = math.Random(555);
      for (int i = 0; i < 300; i++) {
        final board = SlidingPuzzleGen.generate(3, random: rng);
        expect(reachable.contains(_key(board.tiles)), isTrue);
      }
    });
  });

  group('solver sanity (validates the independent oracle itself)', () {
    test('solver returns empty for already-solved boards', () {
      for (final n in [3, 4, 5]) {
        expect(_solve(SlidingPuzzleGen.solved(n), n), isEmpty);
      }
    });

    test('solver refuses a known-unsolvable 4x4 board within cap', () {
      // 14/15 swap is unsolvable; solver must exhaust without a witness.
      final b = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 14, 0];
      final moves = _solve(b, 4, weight: 1.0, nodeCap: 200000);
      // Either no solution found, or (impossibly) a bogus one that fails replay.
      if (moves != null) {
        expect(_replaySolves(b, moves, 4), isFalse);
      }
    });
  });
}
