import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'tango_seeds.g.dart';

/// A fully-specified Tango puzzle: the unique solution plus the givens
/// (pre-filled cells and "=" / "×" clues between adjacent cells).
///
/// Cell values: 0 = Sun, 1 = Moon. Cells are row-major (`r * gridSize + c`).
/// A clue key is the index of the LEFT cell (hClues) or TOP cell (vClues) of
/// the adjacent pair it constrains. Clue value: 0 = "=" (equal), 1 = "×"
/// (different).
class TangoLevelResult {
  final int gridSize;
  final List<int> solution;
  final Set<int> prefilled;
  final Map<int, int> hClues;
  final Map<int, int> vClues;

  const TangoLevelResult({
    required this.gridSize,
    required this.solution,
    required this.prefilled,
    required this.hClues,
    required this.vClues,
  });
}

/// Board edge length per difficulty (Easy, Medium, Hard). Grid sizes are fixed.
int tangoGridSize(int diffIndex) => const [4, 6, 6][diffIndex.clamp(0, 2)];

/// The deduction tier a difficulty's puzzles require (and are graded to):
///   1 = basic forced moves only            (Easy)
///   2 = + one-ply "what-if" forcing chains  (Medium — a little tough)
///   3 = + two-ply nested forcing chains     (Hard)
/// Every puzzle is fully solvable by pure logic at its tier — never by guessing.
int tangoTierFor(int diffIndex) => const [1, 2, 3][diffIndex.clamp(0, 2)];

// ── slot enumerations ───────────────────────────────────────────────────────
// Horizontal clue slots: left cell of each horizontally adjacent pair.
List<int> _hSlots(int n) {
  final s = <int>[];
  for (int r = 0; r < n; r++) {
    for (int c = 0; c < n - 1; c++) {
      s.add(r * n + c);
    }
  }
  return s;
}

// Vertical clue slots: top cell of each vertically adjacent pair.
List<int> _vSlots(int n) {
  final s = <int>[];
  for (int r = 0; r < n - 1; r++) {
    for (int c = 0; c < n; c++) {
      s.add(r * n + c);
    }
  }
  return s;
}

// ── tiered logic solver ─────────────────────────────────────────────────────
// A value is "locally consistent" at `pos` if placing it does not immediately
// break a rule given the current partial board: line balance, no-three-in-a-row
// (any of the six straddling triples), and any "=" / "×" clue against a filled
// neighbour. This never rejects the true solution value, so a cell with exactly
// one consistent value is FORCED to that value.
bool _consistent(List<int> b, int n, int half, Map<int, int> h, Map<int, int> v,
    int pos, int val) {
  final r = pos ~/ n, c = pos % n;
  int rc = 0;
  for (int j = 0; j < n; j++) {
    if (b[r * n + j] == val) rc++;
  }
  if (rc + 1 > half) return false;
  int cc = 0;
  for (int i = 0; i < n; i++) {
    if (b[i * n + c] == val) cc++;
  }
  if (cc + 1 > half) return false;
  if (c >= 2 && b[pos - 1] == val && b[pos - 2] == val) return false;
  if (c >= 1 && c < n - 1 && b[pos - 1] == val && b[pos + 1] == val) return false;
  if (c < n - 2 && b[pos + 1] == val && b[pos + 2] == val) return false;
  if (r >= 2 && b[(r - 1) * n + c] == val && b[(r - 2) * n + c] == val) {
    return false;
  }
  if (r >= 1 && r < n - 1 && b[(r - 1) * n + c] == val && b[(r + 1) * n + c] == val) {
    return false;
  }
  if (r < n - 2 && b[(r + 1) * n + c] == val && b[(r + 2) * n + c] == val) {
    return false;
  }
  if (c > 0) {
    final ct = h[pos - 1];
    if (ct != null && b[pos - 1] >= 0) {
      if (ct == 0 && b[pos - 1] != val) return false;
      if (ct == 1 && b[pos - 1] == val) return false;
    }
  }
  if (c < n - 1) {
    final ct = h[pos];
    if (ct != null && b[pos + 1] >= 0) {
      if (ct == 0 && b[pos + 1] != val) return false;
      if (ct == 1 && b[pos + 1] == val) return false;
    }
  }
  if (r > 0) {
    final ct = v[(r - 1) * n + c];
    if (ct != null && b[(r - 1) * n + c] >= 0) {
      if (ct == 0 && b[(r - 1) * n + c] != val) return false;
      if (ct == 1 && b[(r - 1) * n + c] == val) return false;
    }
  }
  if (r < n - 1) {
    final ct = v[pos];
    if (ct != null && b[pos + n] >= 0) {
      if (ct == 0 && b[pos + n] != val) return false;
      if (ct == 1 && b[pos + n] == val) return false;
    }
  }
  return true;
}

// Propagate forced placements into `b` up to `tier`. Returns false on a
// contradiction (an empty cell with no consistent value). At tier >= 2, when a
// cell is locally ambiguous, it tries each value and propagates at tier-1; if a
// value leads to a contradiction the opposite value is forced (a forcing chain).
bool _propagate(List<int> b, int n, int half, Map<int, int> h, Map<int, int> v,
    int tier) {
  bool progress = true;
  while (progress) {
    progress = false;
    for (int pos = 0; pos < n * n; pos++) {
      if (b[pos] >= 0) continue;
      final ok0 = _consistent(b, n, half, h, v, pos, 0);
      final ok1 = _consistent(b, n, half, h, v, pos, 1);
      if (!ok0 && !ok1) return false;
      if (ok0 && !ok1) {
        b[pos] = 0;
        progress = true;
      } else if (!ok0 && ok1) {
        b[pos] = 1;
        progress = true;
      } else if (tier >= 2) {
        for (int val = 0; val <= 1; val++) {
          final copy = List<int>.of(b);
          copy[pos] = val;
          if (!_propagate(copy, n, half, h, v, tier - 1)) {
            b[pos] = 1 - val;
            progress = true;
            break;
          }
        }
      }
    }
  }
  return true;
}

/// True if [p] can be solved to completion using deductions up to [tier]
/// (no guessing). Because the solver only ever places forced cells, a puzzle
/// that solves this way necessarily has exactly one solution.
bool tangoSolvableAt(TangoLevelResult p, int tier) {
  final n = p.gridSize;
  final b = List<int>.filled(n * n, -1);
  for (final i in p.prefilled) {
    b[i] = p.solution[i];
  }
  final ok = _propagate(b, n, n ~/ 2, p.hClues, p.vClues, tier);
  return ok && !b.contains(-1);
}

/// The minimum deduction tier (1, 2 or 3) that fully solves [p]; 99 if even a
/// two-ply forcing search cannot finish it (i.e. it would require guessing).
int tangoRequiredTier(TangoLevelResult p) {
  for (int t = 1; t <= 3; t++) {
    if (tangoSolvableAt(p, t)) return t;
  }
  return 99;
}

// ── full solution board ─────────────────────────────────────────────────────
List<int>? _generateBoard(int n, math.Random rng) {
  final board = List<int>.filled(n * n, -1);
  return _fill(board, n, 0, rng) ? board : null;
}

bool _fill(List<int> board, int n, int pos, math.Random rng) {
  if (pos == n * n) return true;
  final r = pos ~/ n, c = pos % n, half = n ~/ 2;
  for (final v in (rng.nextBool() ? const [0, 1] : const [1, 0])) {
    int rc = 0;
    for (int j = 0; j < c; j++) {
      if (board[r * n + j] == v) rc++;
    }
    if (rc >= half) continue;
    int cc = 0;
    for (int i = 0; i < r; i++) {
      if (board[i * n + c] == v) cc++;
    }
    if (cc >= half) continue;
    if (c >= 2 && board[pos - 1] == v && board[pos - 2] == v) continue;
    if (r >= 2 && board[(r - 1) * n + c] == v && board[(r - 2) * n + c] == v) {
      continue;
    }
    board[pos] = v;
    if (_fill(board, n, pos + 1, rng)) return true;
  }
  board[pos] = -1;
  return false;
}

// ── offline generation: build a graded puzzle by clue reduction ─────────────
/// Builds one puzzle for [diffIndex] using [rng]. Starts from a full solution
/// with every clue present plus two seed pre-fills (which break the global
/// sun↔moon complement symmetry), then greedily removes givens while the puzzle
/// stays solvable at the difficulty's tier — never below [givenFloor] givens.
///
/// Returns null when the reduced puzzle's REQUIRED tier doesn't match the
/// difficulty exactly (e.g. it collapsed to an easier tier); the caller retries
/// with a fresh [rng]. A non-null result is guaranteed uniquely solvable.
TangoLevelResult? buildTangoPuzzle(int diffIndex, math.Random rng,
    {int givenFloor = 0}) {
  final n = tangoGridSize(diffIndex);
  final targetTier = tangoTierFor(diffIndex);
  final sol = _generateBoard(n, rng);
  if (sol == null) return null;

  final h = <int, int>{};
  for (final k in _hSlots(n)) {
    h[k] = sol[k] == sol[k + 1] ? 0 : 1;
  }
  final v = <int, int>{};
  for (final k in _vSlots(n)) {
    v[k] = sol[k] == sol[k + n] ? 0 : 1;
  }

  final cells = List.generate(n * n, (i) => i)..shuffle(rng);
  final pre = <int>{...cells.take(2)};

  int givens() => pre.length + h.length + v.length;
  bool solvable() {
    final b = List<int>.filled(n * n, -1);
    for (final i in pre) {
      b[i] = sol[i];
    }
    return _propagate(b, n, n ~/ 2, h, v, targetTier) && !b.contains(-1);
  }

  // removal order: [tag, key] where tag 0=hClue 1=vClue 2=prefill
  final order = <List<int>>[
    for (final k in h.keys) [0, k],
    for (final k in v.keys) [1, k],
    for (final k in pre) [2, k],
  ]..shuffle(rng);

  for (final g in order) {
    if (givens() <= givenFloor) break;
    final tag = g[0], key = g[1];
    int? saved;
    if (tag == 0) {
      saved = h.remove(key);
    } else if (tag == 1) {
      saved = v.remove(key);
    } else {
      if (!pre.remove(key)) continue;
      saved = 1;
    }
    if (!solvable()) {
      if (tag == 0) {
        h[key] = saved!;
      } else if (tag == 1) {
        v[key] = saved!;
      } else {
        pre.add(key);
      }
    }
  }

  final result = TangoLevelResult(
    gridSize: n,
    solution: sol,
    prefilled: pre,
    hClues: h,
    vClues: v,
  );
  return tangoRequiredTier(result) == targetTier ? result : null;
}

// ── exact solution counter (independent ground-truth verifier) ──────────────
int countTangoSolutions(TangoLevelResult puzzle, {int cap = 2}) {
  final n = puzzle.gridSize;
  final b = List<int>.filled(n * n, -1);
  for (final idx in puzzle.prefilled) {
    b[idx] = puzzle.solution[idx];
  }
  final half = n ~/ 2;
  int count = 0;

  bool valid(int pos, int v) {
    final r = pos ~/ n, c = pos % n;
    int rc = 0;
    for (int j = 0; j < n; j++) {
      if (b[r * n + j] == v) rc++;
    }
    if (rc >= half) return false;
    int cc = 0;
    for (int i = 0; i < n; i++) {
      if (b[i * n + c] == v) cc++;
    }
    if (cc >= half) return false;
    if (c >= 2 && b[pos - 1] == v && b[pos - 2] == v) return false;
    if (c >= 1 && c < n - 1 && b[pos - 1] == v && b[pos + 1] == v) {
      return false;
    }
    if (c < n - 2 && b[pos + 1] == v && b[pos + 2] == v) return false;
    if (r >= 2 && b[(r - 1) * n + c] == v && b[(r - 2) * n + c] == v) {
      return false;
    }
    if (r >= 1 && r < n - 1 && b[(r - 1) * n + c] == v && b[(r + 1) * n + c] == v) {
      return false;
    }
    if (r < n - 2 && b[(r + 1) * n + c] == v && b[(r + 2) * n + c] == v) {
      return false;
    }
    if (c > 0) {
      final ct = puzzle.hClues[pos - 1];
      if (ct != null && b[pos - 1] >= 0) {
        if (ct == 0 && b[pos - 1] != v) return false;
        if (ct == 1 && b[pos - 1] == v) return false;
      }
    }
    if (c < n - 1) {
      final ct = puzzle.hClues[pos];
      if (ct != null && b[pos + 1] >= 0) {
        if (ct == 0 && b[pos + 1] != v) return false;
        if (ct == 1 && b[pos + 1] == v) return false;
      }
    }
    if (r > 0) {
      final ct = puzzle.vClues[(r - 1) * n + c];
      if (ct != null && b[(r - 1) * n + c] >= 0) {
        if (ct == 0 && b[(r - 1) * n + c] != v) return false;
        if (ct == 1 && b[(r - 1) * n + c] == v) return false;
      }
    }
    if (r < n - 1) {
      final ct = puzzle.vClues[pos];
      if (ct != null && b[pos + n] >= 0) {
        if (ct == 0 && b[pos + n] != v) return false;
        if (ct == 1 && b[pos + n] == v) return false;
      }
    }
    return true;
  }

  void solve(int pos) {
    if (count >= cap) return;
    while (pos < n * n && b[pos] >= 0) {
      pos++;
    }
    if (pos == n * n) {
      count++;
      return;
    }
    for (int v = 0; v <= 1; v++) {
      if (valid(pos, v)) {
        b[pos] = v;
        solve(pos + 1);
        b[pos] = -1;
      }
      if (count >= cap) return;
    }
  }

  solve(0);
  return count;
}

/// Stable string identity of a puzzle (solution + clue layout + prefills), used
/// to guarantee no two levels within a difficulty are identical.
String tangoSignature(TangoLevelResult r) {
  final sb = StringBuffer('${r.gridSize}|');
  sb.write(r.solution.join(','));
  sb.write('|h:');
  final hk = r.hClues.keys.toList()..sort();
  sb.write(hk.map((k) => '$k=${r.hClues[k]}').join(','));
  sb.write('|v:');
  final vk = r.vClues.keys.toList()..sort();
  sb.write(vk.map((k) => '$k=${r.vClues[k]}').join(','));
  sb.write('|p:');
  final pk = r.prefilled.toList()..sort();
  sb.write(pk.join(','));
  return sb.toString();
}

// ── compact bit packing (encode = generator, decode = runtime) ──────────────
// Per-level record bit order: solution[n*n], hClue-present[hSlots],
// vClue-present[vSlots], prefill-present[n*n]. Clue/prefill VALUES are derived
// from the solution, so they need no storage.
int _bitsFor(int n) => 2 * n * n + 2 * n * (n - 1);
int tangoStrideBytes(int n) => (_bitsFor(n) + 7) >> 3;

Uint8List tangoEncodeLevel(TangoLevelResult r) {
  final n = r.gridSize;
  final out = Uint8List(tangoStrideBytes(n));
  int bit = 0;
  void put(int v) {
    if (v != 0) out[bit >> 3] |= 1 << (bit & 7);
    bit++;
  }

  for (int i = 0; i < n * n; i++) {
    put(r.solution[i]);
  }
  for (final k in _hSlots(n)) {
    put(r.hClues.containsKey(k) ? 1 : 0);
  }
  for (final k in _vSlots(n)) {
    put(r.vClues.containsKey(k) ? 1 : 0);
  }
  for (int i = 0; i < n * n; i++) {
    put(r.prefilled.contains(i) ? 1 : 0);
  }
  return out;
}

TangoLevelResult tangoDecodeLevel(int n, Uint8List bytes) {
  int bit = 0;
  int get() {
    final v = (bytes[bit >> 3] >> (bit & 7)) & 1;
    bit++;
    return v;
  }

  final sol = List<int>.generate(n * n, (_) => get());
  final h = <int, int>{};
  for (final k in _hSlots(n)) {
    if (get() == 1) h[k] = sol[k] == sol[k + 1] ? 0 : 1;
  }
  final v = <int, int>{};
  for (final k in _vSlots(n)) {
    if (get() == 1) v[k] = sol[k] == sol[k + n] ? 0 : 1;
  }
  final pre = <int>{};
  for (int i = 0; i < n * n; i++) {
    if (get() == 1) pre.add(i);
  }
  return TangoLevelResult(
    gridSize: n,
    solution: sol,
    prefilled: pre,
    hClues: h,
    vClues: v,
  );
}

// ── runtime decode from the generated seed table ────────────────────────────
final List<Uint8List?> _packedCache = List<Uint8List?>.filled(3, null);

Uint8List _packedBytes(int diffIndex) {
  final cached = _packedCache[diffIndex];
  if (cached != null) return cached;
  final bytes = base64Decode(tangoPacked[diffIndex]);
  _packedCache[diffIndex] = bytes;
  return bytes;
}

/// Decodes the offline-generated, verified puzzle for [level] / [diffIndex].
/// Levels wrap around the [tangoLevelsPerDifficulty] table. No solving happens
/// at runtime — the puzzle is read straight from packed bytes.
TangoLevelResult generateTangoLevel(int level, int diffIndex) {
  final n = tangoGridSize(diffIndex);
  final stride = tangoStrideBytes(n);
  final idx = (level - 1) % tangoLevelsPerDifficulty;
  final bytes = _packedBytes(diffIndex);
  final view = Uint8List.sublistView(bytes, idx * stride, (idx + 1) * stride);
  return tangoDecodeLevel(n, view);
}
