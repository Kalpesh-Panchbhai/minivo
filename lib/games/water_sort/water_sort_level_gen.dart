import 'dart:math' as math;

import 'water_sort_seeds.g.dart';

class WaterSortParams {
  final int numColors;
  final int tubeCapacity;
  final int emptyTubes; // FREE empty tubes the player starts with (excludes ad-extra)
  int get numTubes => numColors + emptyTubes;
  const WaterSortParams({
    required this.numColors,
    required this.tubeCapacity,
    required this.emptyTubes,
  });
}

class WaterSortLevelResult {
  /// Tubes in display order: [N mixed colour tubes, 2 free empty tubes, 1
  /// ad-extra tube (last, starts unusable)]. The solver/uniqueness only use the
  /// first N+2 (the ad-extra is a pure assist, never required to win).
  final List<List<int>> tubes;
  final WaterSortParams params;
  WaterSortLevelResult({required this.tubes, required this.params});
}

// ---------------------------------------------------------------------------
// Difficulty design
//
// Classic water sort: pour the top run of one tube onto another when the
// destination is empty or its top colour matches. A level is solvable when some
// pour order leaves every colour gathered in one tube — using ONLY the 2 free
// empty tubes (the ad-extra tube is a bonus, never needed). Multiple solutions
// are fine; we require >= 1. Difficulty scales with colour count and tube
// capacity, both ramping with level.
// ---------------------------------------------------------------------------

const int kFreeEmptyTubes = 2;

class WaterSortSpec {
  final int colorMin, colorMax;
  final int capMin, capMax;
  final int colorStep, capStep; // levels per +1
  const WaterSortSpec({
    required this.colorMin,
    required this.colorMax,
    required this.capMin,
    required this.capMax,
    required this.colorStep,
    required this.capStep,
  });
}

const List<WaterSortSpec> waterSortSpecs = [
  // EASY
  WaterSortSpec(colorMin: 4, colorMax: 7, capMin: 3, capMax: 4, colorStep: 5, capStep: 12),
  // MEDIUM
  WaterSortSpec(colorMin: 8, colorMax: 11, capMin: 4, capMax: 5, colorStep: 4, capStep: 12),
  // HARD
  WaterSortSpec(colorMin: 12, colorMax: 14, capMin: 4, capMax: 5, colorStep: 3, capStep: 10),
];

WaterSortSpec waterSortSpec(int diffIndex) => waterSortSpecs[diffIndex];

int colorsForLevel(int diffIndex, int level) {
  final s = waterSortSpec(diffIndex);
  final eff = (level - 1) % waterSortLevelsPerDifficulty + 1;
  return (s.colorMin + (eff - 1) ~/ s.colorStep).clamp(s.colorMin, s.colorMax);
}

int capForLevel(int diffIndex, int level) {
  final s = waterSortSpec(diffIndex);
  final eff = (level - 1) % waterSortLevelsPerDifficulty + 1;
  return (s.capMin + (eff - 1) ~/ s.capStep).clamp(s.capMin, s.capMax);
}

// ---------------------------------------------------------------------------
// Build (pure deterministic function of level, diffIndex, salt)
// ---------------------------------------------------------------------------

int _seed(int level, int diffIndex, int salt) {
  int h = level * 1000003 + diffIndex * 9176 + salt * 2654435761;
  h = ((h >> 16) ^ h) * 0x45d9f3b;
  h = ((h >> 16) ^ h) * 0x45d9f3b;
  h = (h >> 16) ^ h;
  return h.abs();
}

/// The N mixed colour tubes + [kFreeEmptyTubes] empty tubes (the playable
/// puzzle, excluding the ad-extra).
List<List<int>> _buildPuzzle(int numColors, int cap, math.Random rng) {
  final units = <int>[];
  for (int c = 0; c < numColors; c++) {
    for (int i = 0; i < cap; i++) {
      units.add(c);
    }
  }
  units.shuffle(rng);
  final tubes = <List<int>>[];
  for (int t = 0; t < numColors; t++) {
    tubes.add(units.sublist(t * cap, (t + 1) * cap));
  }
  for (int e = 0; e < kFreeEmptyTubes; e++) {
    tubes.add(<int>[]);
  }
  return tubes;
}

WaterSortLevelResult _build(int level, int diffIndex, int salt) {
  final rng = math.Random(_seed(level, diffIndex, salt));
  final numColors = colorsForLevel(diffIndex, level);
  final cap = capForLevel(diffIndex, level);
  final puzzle = _buildPuzzle(numColors, cap, rng);
  // Append the ad-extra tube (empty, last) for the screen.
  final tubes = [...puzzle.map((t) => List<int>.from(t)), <int>[]];
  return WaterSortLevelResult(
    tubes: tubes,
    params: WaterSortParams(
        numColors: numColors, tubeCapacity: cap, emptyTubes: kFreeEmptyTubes),
  );
}

/// Build a level for an explicit salt — used by the offline generator and tests.
WaterSortLevelResult generateWaterSortLevelWithSalt(
        int level, int diffIndex, int salt) =>
    _build(level, diffIndex, salt);

/// Build the on-device level: replays the offline-verified salt (solvable +
/// unique). Puzzles repeat every 10k (level 10001 == level 1) while the
/// displayed level keeps climbing. No solver runs on device.
WaterSortLevelResult generateWaterSortLevel(int level, int diffIndex) {
  final eff = (level - 1) % waterSortLevelsPerDifficulty + 1;
  return _build(eff, diffIndex, waterSortSaltFor(eff, diffIndex));
}

// ---------------------------------------------------------------------------
// Solver / verification
// ---------------------------------------------------------------------------

/// The playable puzzle = all tubes except the ad-extra (last).
List<List<int>> puzzleTubes(WaterSortLevelResult r) =>
    r.tubes.sublist(0, r.tubes.length - 1);

bool _isSolved(List<List<int>> tubes, int cap) {
  for (final t in tubes) {
    if (t.isEmpty) continue;
    if (t.length != cap) return false;
    final first = t.first;
    for (final u in t) {
      if (u != first) return false;
    }
  }
  return true;
}

String _canonical(List<List<int>> tubes) {
  final reps = tubes.map((t) => t.join(',')).toList()..sort();
  return reps.join('|');
}

/// DFS with a visited set — returns a winning pour sequence (list of [from, to]
/// moves) using only the given tubes (the 2 free empties; ad-extra excluded), or
/// null if none is found within [nodeCap]. Returning the path lets callers
/// *replay and verify* the solution rather than trust the search.
List<List<int>>? waterSortSolution(List<List<int>> puzzle, int cap,
    {int nodeCap = 400000}) {
  final n = puzzle.length;
  final visited = <String>{};
  int nodes = 0;
  final path = <List<int>>[];

  bool dfs(List<List<int>> tubes) {
    if (_isSolved(tubes, cap)) return true;
    if (++nodes > nodeCap) return false;
    final key = _canonical(tubes);
    if (!visited.add(key)) return false;

    for (int from = 0; from < n; from++) {
      final src = tubes[from];
      if (src.isEmpty) continue;
      if (src.length == cap && src.toSet().length == 1) continue;
      final color = src.last;
      int run = 0;
      for (int i = src.length - 1; i >= 0 && src[i] == color; i--) {
        run++;
      }
      final srcAllSame = run == src.length;
      for (int to = 0; to < n; to++) {
        if (to == from) continue;
        final dst = tubes[to];
        if (dst.length >= cap) continue;
        if (dst.isEmpty) {
          if (srcAllSame) continue; // moving a sorted-but-partial tube → pointless
        } else if (dst.last != color) {
          continue;
        }
        final space = cap - dst.length;
        final moved = run < space ? run : space;
        final next = [for (final t in tubes) List<int>.from(t)];
        for (int k = 0; k < moved; k++) {
          next[from].removeLast();
          next[to].add(color);
        }
        path.add([from, to]);
        if (dfs(next)) return true;
        path.removeLast();
      }
    }
    return false;
  }

  return dfs([for (final t in puzzle) List<int>.from(t)]) ? List.of(path) : null;
}

/// True if the puzzle is solvable (>=1 pour order) with the given tubes.
bool isWaterSortSolvable(List<List<int>> puzzle, int cap,
        {int nodeCap = 400000}) =>
    waterSortSolution(puzzle, cap, nodeCap: nodeCap) != null;

/// Solvable (>=1 solution with the 2 free empties), well-mixed (not already
/// solved), and correctly shaped.
bool meetsWaterSortBand(WaterSortLevelResult r) {
  final cap = r.params.tubeCapacity;
  final puzzle = puzzleTubes(r);
  if (_isSolved(puzzle, cap)) return false; // must not start solved
  return isWaterSortSolvable(puzzle, cap);
}

/// Canonical signature of the playable puzzle (tube order doesn't matter).
String waterSortSignature(WaterSortLevelResult r) =>
    '${r.params.numColors}:${r.params.tubeCapacity}:${_canonical(puzzleTubes(r))}';
