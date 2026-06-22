import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'patches_seeds.g.dart';

class PatchesLevelResult {
  final int rows;
  final int cols;
  final List<int> clues;
  final List<int> solution;

  const PatchesLevelResult({
    required this.rows,
    required this.cols,
    required this.clues,
    required this.solution,
  });
}

int patchesRows(int diffIndex) => const [5, 7, 9][diffIndex.clamp(0, 2)];
int patchesCols(int diffIndex) => const [5, 7, 9][diffIndex.clamp(0, 2)];

/// Upper bound on a single region's area when growing the partition. Bigger
/// rectangles create more placement ambiguity, so this biases each difficulty
/// toward a harder size distribution. The toughness band (see [_toughnessOk])
/// does the final filtering — this only shifts where the bulk of the
/// distribution lands so each band is fillable.
///   Easy   → 1..3 (singletons / dominoes / triominoes → mostly forced)
///   Medium → 2..5 (the original distribution)
///   Hard   → 4..9 (large rectangles → deep deduction)
int _maxAreaFor(int diffIndex, math.Random rng) {
  switch (diffIndex) {
    case 0:
      return rng.nextInt(3) + 1;
    case 1:
      return rng.nextInt(4) + 2;
    default:
      return rng.nextInt(6) + 4;
  }
}

List<int>? _generatePartition(int rows, int cols, math.Random rng, int diffIndex) {
  final n = rows * cols;
  final label = List<int>.filled(n, -1);
  int nextId = 0;
  final cells = List.generate(n, (i) => i)..shuffle(rng);

  for (final start in cells) {
    if (label[start] >= 0) continue;
    final id = nextId++;
    final maxArea = _maxAreaFor(diffIndex, rng);
    final area = _growRect(label, rows, cols, start, id, maxArea, rng);
    if (area == 0) return null;
  }
  return label;
}

int _growRect(List<int> label, int rows, int cols, int start, int id, int maxArea, math.Random rng) {
  final sr = start ~/ cols, sc = start % cols;
  final candidates = <List<int>>[];
  for (int h = 1; h <= math.min(maxArea, rows - sr); h++) {
    for (int w = 1; w <= math.min(maxArea ~/ h, cols - sc); w++) {
      if (h * w < 2 || h * w > maxArea) continue;
      bool ok = true;
      for (int r = sr; r < sr + h && ok; r++) {
        for (int c = sc; c < sc + w && ok; c++) {
          if (label[r * cols + c] >= 0) ok = false;
        }
      }
      if (ok) candidates.add([h, w]);
    }
  }
  if (candidates.isEmpty) {
    if (label[start] >= 0) return 0;
    label[start] = id;
    return 1;
  }
  final pick = candidates[rng.nextInt(candidates.length)];
  final h = pick[0], w = pick[1];
  for (int r = sr; r < sr + h; r++) {
    for (int c = sc; c < sc + w; c++) {
      label[r * cols + c] = id;
    }
  }
  return h * w;
}

List<int> _makeClues(List<int> label, int rows, int cols, math.Random rng) {
  final n = rows * cols;
  final clues = List<int>.filled(n, 0);
  final patchCells = <int, List<int>>{};
  for (int i = 0; i < n; i++) {
    patchCells.putIfAbsent(label[i], () => []).add(i);
  }
  for (final entry in patchCells.entries) {
    final cells = entry.value;
    final area = cells.length;
    final pos = cells[rng.nextInt(cells.length)];
    clues[pos] = area;
  }
  return clues;
}

int countPatchesSolutions(PatchesLevelResult puzzle, {int cap = 2}) {
  final rows = puzzle.rows, cols = puzzle.cols, n = rows * cols;
  final clues = puzzle.clues;
  final label = List<int>.filled(n, -1);
  int count = 0;
  int nextId = 0;

  final cluePositions = <int>[];
  for (int i = 0; i < n; i++) {
    if (clues[i] > 0) cluePositions.add(i);
  }

  void solve(int ci) {
    if (count >= cap) return;
    if (ci == cluePositions.length) {
      if (!label.contains(-1)) count++;
      return;
    }
    final pos = cluePositions[ci];
    if (label[pos] >= 0) {
      solve(ci + 1);
      return;
    }
    final area = clues[pos];
    final pr = pos ~/ cols, pc = pos % cols;
    final id = nextId++;

    for (int h = 1; h <= math.min(area, rows); h++) {
      if (area % h != 0) continue;
      final w = area ~/ h;
      if (w > cols) continue;
      for (int tr = math.max(0, pr - h + 1); tr <= math.min(pr, rows - h); tr++) {
        for (int tc = math.max(0, pc - w + 1); tc <= math.min(pc, cols - w); tc++) {
          if (tr + h > rows || tc + w > cols) continue;
          bool ok = true;
          for (int r = tr; r < tr + h && ok; r++) {
            for (int c = tc; c < tc + w && ok; c++) {
              final idx = r * cols + c;
              if (label[idx] >= 0) ok = false;
              if (clues[idx] > 0 && idx != pos) ok = false;
            }
          }
          if (!ok) continue;
          for (int r = tr; r < tr + h; r++) {
            for (int c = tc; c < tc + w; c++) {
              label[r * cols + c] = id;
            }
          }
          solve(ci + 1);
          for (int r = tr; r < tr + h; r++) {
            for (int c = tc; c < tc + w; c++) {
              label[r * cols + c] = -1;
            }
          }
          if (count >= cap) { nextId--; return; }
        }
      }
    }
    nextId--;
  }

  solve(0);
  return count;
}

bool patchesSolvable(PatchesLevelResult p) {
  return countPatchesSolutions(p, cap: 2) == 1;
}

// ---------------------------------------------------------------------------
// Toughness metric
//
// Difficulty proxy = how many clues need disambiguation. Walking the unique
// solution in minimum-remaining-values order, we count the steps where MORE
// THAN ONE rectangle fits the clue LOCALLY (in bounds, no overlap, swallowing
// no other clue). 0 means every clue has a single locally-valid rectangle, so
// the board can be filled greedily with no thought (trivial). A higher count
// means more clues are locally ambiguous and the player must cross-reference
// neighbours to resolve them. (Globally, every uniquely-solvable Shikaku is
// "forced" given enough look-ahead — this measures the local ambiguity a human
// actually has to work through, which is the felt difficulty.)
// ---------------------------------------------------------------------------

/// Rectangles of exactly `clues[pos]` cells that cover [pos], stay in bounds,
/// avoid already-labelled cells, and swallow no clue other than [pos].
int _candidateCount(List<int> label, int rows, int cols, List<int> clues, int pos) {
  final area = clues[pos];
  final pr = pos ~/ cols, pc = pos % cols;
  int count = 0;
  for (int h = 1; h <= math.min(area, rows); h++) {
    if (area % h != 0) continue;
    final w = area ~/ h;
    if (w > cols) continue;
    for (int tr = math.max(0, pr - h + 1); tr <= math.min(pr, rows - h); tr++) {
      for (int tc = math.max(0, pc - w + 1); tc <= math.min(pc, cols - w); tc++) {
        bool ok = true;
        for (int r = tr; r < tr + h && ok; r++) {
          for (int c = tc; c < tc + w && ok; c++) {
            final idx = r * cols + c;
            if (label[idx] >= 0) {
              ok = false;
            } else if (clues[idx] > 0 && idx != pos) {
              ok = false;
            }
          }
        }
        if (ok) count++;
      }
    }
  }
  return count;
}

/// See header above: counts the minimum-remaining-values steps along the unique
/// solution where more than one rectangle fits the clue locally. Cheap relative
/// to a full solve; runs once per accepted puzzle during generation.
int patchesToughness(PatchesLevelResult p) {
  final rows = p.rows, cols = p.cols, n = rows * cols;
  final clues = p.clues, sol = p.solution;
  final label = List<int>.filled(n, -1);
  final solCells = <int, List<int>>{};
  for (int i = 0; i < n; i++) {
    solCells.putIfAbsent(sol[i], () => []).add(i);
  }
  final cluePos = <int>[];
  for (int i = 0; i < n; i++) {
    if (clues[i] > 0) cluePos.add(i);
  }
  final placed = List<bool>.filled(cluePos.length, false);
  int remaining = cluePos.length;
  int guesses = 0;
  while (remaining > 0) {
    int bestIdx = -1, bestCount = 1 << 30;
    for (int k = 0; k < cluePos.length; k++) {
      if (placed[k]) continue;
      final c = _candidateCount(label, rows, cols, clues, cluePos[k]);
      if (c < bestCount) {
        bestCount = c;
        bestIdx = k;
        if (bestCount <= 1) break; // nothing beats a forced move
      }
    }
    if (bestCount > 1) guesses++;
    final pos = cluePos[bestIdx];
    final id = sol[pos];
    for (final cell in solCells[id]!) {
      label[cell] = id;
    }
    placed[bestIdx] = true;
    remaining--;
  }
  return guesses;
}

/// Difficulty bands over [patchesToughness]. Calibrated against the size
/// distributions in [_maxAreaFor] so each band is fillable to 10k.
///   Easy   → 0    : no locally-ambiguous clues — fill greedily.
///   Medium → 1..4 : a few clues need disambiguation.
///   Hard   → ≥5   : many ambiguous clues (and Hard additionally hides some
///                   clue numbers — see [derivePatchesPresentation]).
bool _toughnessOk(int diffIndex, int toughness) {
  switch (diffIndex) {
    case 0:
      return toughness == 0;
    case 1:
      return toughness >= 1 && toughness <= 4;
    default:
      return toughness >= 5;
  }
}

// ---------------------------------------------------------------------------
// Player-facing presentation + uniqueness
//
// The on-screen hints (shape of each patch, and — on Hard — which clue numbers
// are hidden) are derived here from the puzzle alone, so the generator can
// verify uniqueness against EXACTLY what the player will see, and the runtime
// UI can render the identical thing. Keeping this in one place is what makes
// "every level has a single solution under the real rules" provable.
// ---------------------------------------------------------------------------

enum PatchesShape { square, tall, wide, any }

class PatchesPresentation {
  /// clue-cell index → shape class drawn for it.
  final Map<int, PatchesShape> shapes;

  /// clue-cell indices whose area number is hidden (the shape is still shown).
  final Set<int> hidden;

  const PatchesPresentation(this.shapes, this.hidden);
}

PatchesShape _trueShape(List<int> sol, int rows, int cols, int clueCell) {
  final id = sol[clueCell];
  final n = rows * cols;
  int minR = rows, maxR = 0, minC = cols, maxC = 0;
  for (int i = 0; i < n; i++) {
    if (sol[i] != id) continue;
    final r = i ~/ cols, c = i % cols;
    if (r < minR) minR = r;
    if (r > maxR) maxR = r;
    if (c < minC) minC = c;
    if (c > maxC) maxC = c;
  }
  final h = maxR - minR + 1, w = maxC - minC + 1;
  if (h == w) return PatchesShape.square;
  return h > w ? PatchesShape.tall : PatchesShape.wide;
}

/// Deterministic. Both [buildPatchesPuzzle] (for verification) and the runtime
/// screen call this, so what the solver proves unique is exactly what the
/// player sees. A hidden clue always shows its TRUE shape (never "any"), so the
/// player keeps a usable hint — that is what lets a hidden-number puzzle stay
/// uniquely solvable.
PatchesPresentation derivePatchesPresentation(PatchesLevelResult p, int diffIndex) {
  final rows = p.rows, cols = p.cols, n = rows * cols;
  final shapes = <int, PatchesShape>{};
  final hidden = <int>{};
  int ci = 0;
  for (int i = 0; i < n; i++) {
    final area = p.clues[i];
    if (area <= 0) continue;
    final isHidden = diffIndex == 2 && area > 1 && ci % 5 == 0;
    var kind = _trueShape(p.solution, rows, cols, i);
    if (!isHidden && area > 1 && diffIndex >= 1) {
      final threshold = diffIndex == 1 ? 4 : 3;
      if (ci % threshold == 0) kind = PatchesShape.any;
    }
    shapes[i] = kind;
    if (isHidden) hidden.add(i);
    ci++;
  }
  return PatchesPresentation(shapes, hidden);
}

bool _shapeAllows(PatchesShape s, int h, int w) {
  switch (s) {
    case PatchesShape.square:
      return h == w;
    case PatchesShape.tall:
      return h > w;
    case PatchesShape.wide:
      return h < w;
    case PatchesShape.any:
      return true;
  }
}

/// Counts tilings consistent with what the PLAYER can actually see:
///   * a visible clue is pinned to its exact area (any orientation), and
///   * a hidden clue may take ANY area but must match the shown shape class.
/// Returns at most [cap]. `== 1` proves the puzzle is uniquely solvable under
/// the real game mechanics. (For Easy/Medium there are no hidden clues, so this
/// is equivalent to [countPatchesSolutions].)
int countPatchesSolutionsForPlayer(
  PatchesLevelResult puzzle,
  PatchesPresentation pres, {
  int cap = 2,
}) {
  final rows = puzzle.rows, cols = puzzle.cols, n = rows * cols;
  final clues = puzzle.clues;
  final label = List<int>.filled(n, -1);
  int count = 0;
  int nextId = 0;

  // Visible clues are far more constrained, so resolve them first to prune the
  // grid before the open-ended hidden clues.
  final visible = <int>[];
  final hiddenList = <int>[];
  for (int i = 0; i < n; i++) {
    if (clues[i] <= 0) continue;
    if (pres.hidden.contains(i)) {
      hiddenList.add(i);
    } else {
      visible.add(i);
    }
  }
  final order = [...visible, ...hiddenList];

  bool fits(int h, int w, int tr, int tc, int pos) {
    for (int r = tr; r < tr + h; r++) {
      for (int c = tc; c < tc + w; c++) {
        final idx = r * cols + c;
        if (label[idx] >= 0) return false;
        if (clues[idx] > 0 && idx != pos) return false;
      }
    }
    return true;
  }

  void fill(int h, int w, int tr, int tc, int v) {
    for (int r = tr; r < tr + h; r++) {
      for (int c = tc; c < tc + w; c++) {
        label[r * cols + c] = v;
      }
    }
  }

  void solve(int oi) {
    if (count >= cap) return;
    if (oi == order.length) {
      if (!label.contains(-1)) count++;
      return;
    }
    final pos = order[oi];
    if (label[pos] >= 0) {
      solve(oi + 1);
      return;
    }
    final pr = pos ~/ cols, pc = pos % cols;
    final id = nextId++;
    final isHidden = pres.hidden.contains(pos);

    if (!isHidden) {
      final area = clues[pos];
      for (int h = 1; h <= math.min(area, rows); h++) {
        if (area % h != 0) continue;
        final w = area ~/ h;
        if (w > cols) continue;
        for (int tr = math.max(0, pr - h + 1); tr <= math.min(pr, rows - h); tr++) {
          for (int tc = math.max(0, pc - w + 1); tc <= math.min(pc, cols - w); tc++) {
            if (!fits(h, w, tr, tc, pos)) continue;
            fill(h, w, tr, tc, id);
            solve(oi + 1);
            fill(h, w, tr, tc, -1);
            if (count >= cap) {
              nextId--;
              return;
            }
          }
        }
      }
    } else {
      final shape = pres.shapes[pos] ?? PatchesShape.any;
      for (int h = 1; h <= rows; h++) {
        for (int w = 1; w <= cols; w++) {
          if (!_shapeAllows(shape, h, w)) continue;
          for (int tr = math.max(0, pr - h + 1); tr <= math.min(pr, rows - h); tr++) {
            for (int tc = math.max(0, pc - w + 1); tc <= math.min(pc, cols - w); tc++) {
              if (!fits(h, w, tr, tc, pos)) continue;
              fill(h, w, tr, tc, id);
              solve(oi + 1);
              fill(h, w, tr, tc, -1);
              if (count >= cap) {
                nextId--;
                return;
              }
            }
          }
        }
      }
    }
    nextId--;
  }

  solve(0);
  return count;
}

/// True when the puzzle has exactly one solution under the player-visible
/// information for [diffIndex].
bool patchesPlayerSolvable(PatchesLevelResult p, int diffIndex) {
  final pres = derivePatchesPresentation(p, diffIndex);
  return countPatchesSolutionsForPlayer(p, pres, cap: 2) == 1;
}

PatchesLevelResult? buildPatchesPuzzle(int diffIndex, math.Random rng) {
  final rows = patchesRows(diffIndex);
  final cols = patchesCols(diffIndex);
  final label = _generatePartition(rows, cols, rng, diffIndex);
  if (label == null) return null;
  if (label.contains(-1)) return null;

  final clues = _makeClues(label, rows, cols, rng);
  final result = PatchesLevelResult(rows: rows, cols: cols, clues: clues, solution: label);

  // 1. Unique by the numbers alone (sound for any visible clue).
  if (countPatchesSolutions(result, cap: 2) != 1) return null;

  // 2. Lands in the difficulty band.
  if (!_toughnessOk(diffIndex, patchesToughness(result))) return null;

  // 3. Still unique once Hard hides some numbers (no-op for Easy/Medium).
  if (diffIndex == 2 && !patchesPlayerSolvable(result, diffIndex)) return null;

  return result;
}

String patchesSignature(PatchesLevelResult r) {
  final sb = StringBuffer('${r.rows}x${r.cols}|');
  sb.write(r.clues.join(','));
  return sb.toString();
}

int patchesStrideBytes(int rows, int cols) {
  final n = rows * cols;
  final clueBits = n * 5;
  final solBits = n * 8;
  return (clueBits + solBits + 7) >> 3;
}

Uint8List patchesEncodeLevel(PatchesLevelResult r) {
  final n = r.rows * r.cols;
  final out = Uint8List(patchesStrideBytes(r.rows, r.cols));
  int bit = 0;
  void putBits(int val, int count) {
    for (int i = 0; i < count; i++) {
      if ((val >> i) & 1 != 0) out[bit >> 3] |= 1 << (bit & 7);
      bit++;
    }
  }
  for (int i = 0; i < n; i++) {
    putBits(r.clues[i], 5);
  }
  for (int i = 0; i < n; i++) {
    putBits(r.solution[i], 8);
  }
  return out;
}

PatchesLevelResult patchesDecodeLevel(int rows, int cols, Uint8List bytes) {
  final n = rows * cols;
  int bit = 0;
  int getBits(int count) {
    int val = 0;
    for (int i = 0; i < count; i++) {
      val |= ((bytes[bit >> 3] >> (bit & 7)) & 1) << i;
      bit++;
    }
    return val;
  }
  final clues = List<int>.generate(n, (_) => getBits(5));
  final solution = List<int>.generate(n, (_) => getBits(8));
  return PatchesLevelResult(rows: rows, cols: cols, clues: clues, solution: solution);
}

final List<Uint8List?> _packedCache = List<Uint8List?>.filled(3, null);

Uint8List _packedBytes(int diffIndex) {
  final cached = _packedCache[diffIndex];
  if (cached != null) return cached;
  final bytes = base64Decode(patchesPacked[diffIndex]);
  _packedCache[diffIndex] = bytes;
  return bytes;
}

PatchesLevelResult generatePatchesLevel(int level, int diffIndex) {
  final rows = patchesRows(diffIndex);
  final cols = patchesCols(diffIndex);
  final stride = patchesStrideBytes(rows, cols);
  final idx = (level - 1) % patchesLevelsPerDifficulty;
  final bytes = _packedBytes(diffIndex);
  final view = Uint8List.sublistView(bytes, idx * stride, (idx + 1) * stride);
  return patchesDecodeLevel(rows, cols, view);
}
