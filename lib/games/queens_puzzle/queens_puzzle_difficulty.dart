// Graded logical difficulty rater for Queens Puzzle levels.
//
// The board has N rows, N columns and N colour regions. A solved board places
// exactly one queen per row, per column and per region, with no two queens in
// the 8 king-adjacent cells. Every generated level has exactly one solution.
//
// This solver never guesses. It applies human-style deduction techniques in
// increasing order of difficulty and records the deepest tier it had to reach
// to fully solve the board:
//
//   Tier 1 (EASY)   — naked singles: some row / column / region has exactly one
//                     legal cell left, so a queen is forced there.
//   Tier 2 (MEDIUM) — line / region locking (pointing & claiming): a region
//                     whose candidates all share one row owns that row, etc.
//   Tier 3 (HARD)   — subset / Hall reasoning: k units whose candidates span
//                     exactly k lines own those lines, eliminating elsewhere.
//
// A level rates EASY when Tier 1 alone solves it, MEDIUM when it needs Tier 2
// but never Tier 3, and HARD when it needs Tier 3. If even Tier 3 stalls before
// the board is solved the level would require guessing — it returns tier 0 and
// is rejected by the generator so no shipped level is ever guess-only.

import 'queens_puzzle_level_gen.dart';

/// Result of grading a puzzle by the logical solver.
class QueensDifficultyGrade {
  /// 1 = easy, 2 = medium, 3 = hard, 0 = unsolvable by pure logic (would need
  /// guessing) — rejected by the generator.
  final int tier;

  /// Weighted cost of the deductions used, for within-band ordering / tuning.
  /// Tier-1 steps cost 1, Tier-2 eliminations 6, Tier-3 eliminations 25.
  final int score;

  const QueensDifficultyGrade(this.tier, this.score);

  bool get solvedByLogic => tier >= 1;
}

const int _unknown = 0;
const int _queen = 1;
const int _blocked = 2;

const int _scoreTier1 = 1;
const int _scoreTier2 = 6;
const int _scoreTier3 = 25;

class _Solver {
  final int n;
  final List<int> regionOf;
  final List<int> state; // per cell: unknown / queen / blocked
  int placed = 0;
  int maxTier = 0;
  int score = 0;

  _Solver(this.n, this.regionOf) : state = List<int>.filled(n * n, _unknown);

  int _row(int idx) => idx ~/ n;
  int _col(int idx) => idx % n;

  // Candidate cells (still unknown) of a unit, given the unit's cell indices.
  // Returns null sentinel via empty list; callers distinguish solved units.
  List<int> _candidates(List<int> cells) {
    final res = <int>[];
    for (final idx in cells) {
      if (state[idx] == _unknown) res.add(idx);
    }
    return res;
  }

  bool _unitHasQueen(List<int> cells) {
    for (final idx in cells) {
      if (state[idx] == _queen) return true;
    }
    return false;
  }

  List<int> _rowCells(int r) => List<int>.generate(n, (c) => r * n + c);
  List<int> _colCells(int c) => List<int>.generate(n, (r) => r * n + c);

  late final List<List<int>> _regionCells = _buildRegionCells();

  List<List<int>> _buildRegionCells() {
    final res = List.generate(n, (_) => <int>[]);
    for (int idx = 0; idx < n * n; idx++) {
      final g = regionOf[idx];
      if (g >= 0 && g < n) res[g].add(idx);
    }
    return res;
  }

  // Place a queen and propagate all of its direct eliminations.
  void _place(int idx) {
    state[idx] = _queen;
    placed++;
    final r = _row(idx), c = _col(idx), g = regionOf[idx];

    void block(int i) {
      if (state[i] == _unknown) state[i] = _blocked;
    }

    for (int cc = 0; cc < n; cc++) {
      block(r * n + cc);
    }
    for (int rr = 0; rr < n; rr++) {
      block(rr * n + c);
    }
    for (final i in _regionCells[g]) {
      block(i);
    }
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        final nr = r + dr, nc = c + dc;
        if (nr < 0 || nr >= n || nc < 0 || nc >= n) continue;
        block(nr * n + nc);
      }
    }
  }

  // Tier 1: any unsatisfied row / column / region with exactly one candidate
  // forces a queen. Returns true if it placed at least one queen.
  // Sets [contradiction] true if an unsatisfied unit has zero candidates.
  bool _tier1() {
    bool any = false;
    bool again = true;
    while (again) {
      again = false;
      for (int u = 0; u < 3 * n; u++) {
        final List<int> cells;
        if (u < n) {
          cells = _rowCells(u);
        } else if (u < 2 * n) {
          cells = _colCells(u - n);
        } else {
          cells = _regionCells[u - 2 * n];
        }
        if (_unitHasQueen(cells)) continue;
        final cand = _candidates(cells);
        if (cand.isEmpty) {
          _contradiction = true;
          return any;
        }
        if (cand.length == 1) {
          _place(cand[0]);
          score += _scoreTier1;
          any = true;
          again = true;
        }
      }
    }
    return any;
  }

  bool _contradiction = false;

  // Tier 2: line/region locking. Returns true if it eliminated any candidate.
  bool _tier2() {
    bool changed = false;

    // Region confined to a single row/column => that row/column belongs to the
    // region; eliminate candidates of that line that lie in other regions.
    for (int g = 0; g < n; g++) {
      final cells = _regionCells[g];
      if (_unitHasQueen(cells)) continue;
      final cand = _candidates(cells);
      if (cand.isEmpty) continue;
      final rows = <int>{};
      final cols = <int>{};
      for (final idx in cand) {
        rows.add(_row(idx));
        cols.add(_col(idx));
      }
      if (rows.length == 1) {
        final r = rows.first;
        for (final idx in _rowCells(r)) {
          if (state[idx] == _unknown && regionOf[idx] != g) {
            state[idx] = _blocked;
            changed = true;
          }
        }
      }
      if (cols.length == 1) {
        final c = cols.first;
        for (final idx in _colCells(c)) {
          if (state[idx] == _unknown && regionOf[idx] != g) {
            state[idx] = _blocked;
            changed = true;
          }
        }
      }
    }

    // Row confined to a single region => that region's queen is in this row;
    // eliminate the region's candidates outside this row. Same for columns.
    for (int r = 0; r < n; r++) {
      final cells = _rowCells(r);
      if (_unitHasQueen(cells)) continue;
      final cand = _candidates(cells);
      if (cand.isEmpty) continue;
      final regs = <int>{};
      for (final idx in cand) {
        regs.add(regionOf[idx]);
      }
      if (regs.length == 1) {
        final g = regs.first;
        for (final idx in _regionCells[g]) {
          if (state[idx] == _unknown && _row(idx) != r) {
            state[idx] = _blocked;
            changed = true;
          }
        }
      }
    }
    for (int c = 0; c < n; c++) {
      final cells = _colCells(c);
      if (_unitHasQueen(cells)) continue;
      final cand = _candidates(cells);
      if (cand.isEmpty) continue;
      final regs = <int>{};
      for (final idx in cand) {
        regs.add(regionOf[idx]);
      }
      if (regs.length == 1) {
        final g = regs.first;
        for (final idx in _regionCells[g]) {
          if (state[idx] == _unknown && _col(idx) != c) {
            state[idx] = _blocked;
            changed = true;
          }
        }
      }
    }

    if (changed) score += _scoreTier2;
    return changed;
  }

  // Tier 3: subset (Hall) reasoning across region<->column and region<->row,
  // plus the symmetric line<->region direction, for subset sizes 2..3.
  bool _tier3() {
    if (_subsetRegionsToLines(byColumn: true)) return true;
    if (_subsetRegionsToLines(byColumn: false)) return true;
    if (_subsetLinesToRegions(byColumn: true)) return true;
    if (_subsetLinesToRegions(byColumn: false)) return true;
    return false;
  }

  // k regions whose candidates collectively occupy exactly k columns (or rows)
  // own those lines: eliminate the lines' candidates that belong to regions
  // outside the subset.
  bool _subsetRegionsToLines({required bool byColumn}) {
    final units = <int>[]; // region ids that are unsolved
    final lineSets = <Set<int>>[];
    for (int g = 0; g < n; g++) {
      final cells = _regionCells[g];
      if (_unitHasQueen(cells)) continue;
      final cand = _candidates(cells);
      if (cand.isEmpty) continue;
      final lines = <int>{};
      for (final idx in cand) {
        lines.add(byColumn ? _col(idx) : _row(idx));
      }
      units.add(g);
      lineSets.add(lines);
    }
    return _applySubset(
      units: units,
      lineSets: lineSets,
      eliminate: (lines, subsetRegions) {
        bool changed = false;
        for (final line in lines) {
          final cells = byColumn ? _colCells(line) : _rowCells(line);
          for (final idx in cells) {
            if (state[idx] == _unknown && !subsetRegions.contains(regionOf[idx])) {
              state[idx] = _blocked;
              changed = true;
            }
          }
        }
        return changed;
      },
    );
  }

  // k lines (rows or columns) whose candidates collectively occupy exactly k
  // regions own those regions: eliminate those regions' candidates outside the
  // subset of lines.
  bool _subsetLinesToRegions({required bool byColumn}) {
    final units = <int>[]; // line ids
    final regionSets = <Set<int>>[];
    for (int line = 0; line < n; line++) {
      final cells = byColumn ? _colCells(line) : _rowCells(line);
      if (_unitHasQueen(cells)) continue;
      final cand = _candidates(cells);
      if (cand.isEmpty) continue;
      final regs = <int>{};
      for (final idx in cand) {
        regs.add(regionOf[idx]);
      }
      units.add(line);
      regionSets.add(regs);
    }
    return _applySubset(
      units: units,
      lineSets: regionSets,
      eliminate: (regions, subsetLines) {
        bool changed = false;
        for (final g in regions) {
          for (final idx in _regionCells[g]) {
            if (state[idx] != _unknown) continue;
            final line = byColumn ? _col(idx) : _row(idx);
            if (!subsetLines.contains(line)) {
              state[idx] = _blocked;
              changed = true;
            }
          }
        }
        return changed;
      },
    );
  }

  // Generic subset finder over sizes 2..3: pick k units whose value-sets union
  // to exactly k values, then run [eliminate] with (union values, subset unit
  // ids). Returns true on the first elimination that changes the board.
  bool _applySubset({
    required List<int> units,
    required List<Set<int>> lineSets,
    required bool Function(Set<int> values, Set<int> subsetUnits) eliminate,
  }) {
    final m = units.length;
    for (int k = 2; k <= 3 && k <= m; k++) {
      final combo = List<int>.generate(k, (i) => i);
      while (true) {
        final union = <int>{};
        for (final ci in combo) {
          union.addAll(lineSets[ci]);
        }
        if (union.length == k) {
          final subsetUnits = <int>{for (final ci in combo) units[ci]};
          if (eliminate(union, subsetUnits)) return true;
        }
        // advance the k-combination over [0, m)
        int p = k - 1;
        while (p >= 0 && combo[p] == m - k + p) {
          p--;
        }
        if (p < 0) break;
        combo[p]++;
        for (int q = p + 1; q < k; q++) {
          combo[q] = combo[q - 1] + 1;
        }
      }
    }
    return false;
  }

  QueensDifficultyGrade solve() {
    while (placed < n) {
      _contradiction = false;
      if (_tier1()) {
        if (maxTier < 1) maxTier = 1;
        if (_contradiction) return const QueensDifficultyGrade(0, 0);
        continue;
      }
      if (_contradiction) return const QueensDifficultyGrade(0, 0);
      if (_tier2()) {
        if (maxTier < 2) maxTier = 2;
        continue;
      }
      if (_tier3()) {
        score += _scoreTier3;
        if (maxTier < 3) maxTier = 3;
        continue;
      }
      // No technique made progress and board isn't solved -> needs guessing.
      return const QueensDifficultyGrade(0, 0);
    }
    return QueensDifficultyGrade(maxTier == 0 ? 1 : maxTier, score);
  }
}

/// Grades a generated level by the deepest logical technique needed to solve it.
QueensDifficultyGrade gradeQueensPuzzle(QueensPuzzleLevelResult r) {
  final n = r.boardSize;
  final regionOf = List<int>.filled(n * n, -1);
  for (int g = 0; g < r.regions.length; g++) {
    for (final idx in r.regions[g]) {
      regionOf[idx] = g;
    }
  }
  return _Solver(n, regionOf).solve();
}

/// Convenience: the logical difficulty tier (1/2/3, or 0 if guess-only).
int queensPuzzleDifficultyTier(QueensPuzzleLevelResult r) =>
    gradeQueensPuzzle(r).tier;

/// Target logical tier for a difficulty band (0=easy, 1=medium, 2=hard).
int queensTargetTierFor(int diffIndex) => diffIndex + 1;
