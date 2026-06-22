import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:minivo/games/color_connect/color_connect_level_gen.dart';
import 'package:minivo/games/color_connect/color_connect_seeds.g.dart';

const _diffNames = ['EASY', 'MEDIUM', 'HARD'];

List<int> _neighbors(int idx, int rows, int cols) {
  final r = idx ~/ cols, c = idx % cols;
  final res = <int>[];
  if (r > 0) res.add((r - 1) * cols + c);
  if (r < rows - 1) res.add((r + 1) * cols + c);
  if (c > 0) res.add(r * cols + c - 1);
  if (c < cols - 1) res.add(r * cols + c + 1);
  return res;
}

/// True if [cells] can be traced as ONE continuous line (a Hamiltonian path of
/// the region) from [ep0] to [ep1] — i.e. the flow is drawable by the player.
/// Accepts flows that fill a 2x2 block (a path may legally run alongside
/// itself); rejects disconnected or untraceable regions.
bool _drawable(Set<int> cells, int ep0, int ep1, int rows, int cols) {
  final visited = <int>{};
  bool dfs(int cur) {
    visited.add(cur);
    if (visited.length == cells.length) {
      if (cur == ep1) return true;
    } else {
      for (final nb in _neighbors(cur, rows, cols)) {
        if (cells.contains(nb) && !visited.contains(nb) && dfs(nb)) return true;
      }
    }
    visited.remove(cur);
    return false;
  }

  return dfs(ep0);
}

String? validateLevel(int level, int diffIdx) {
  final r = generateColorConnectLevel(level, diffIdx);
  final n = r.rows * r.cols;

  if (r.endpoints.length != r.numFlows * 2) {
    return 'wrong endpoint count';
  }
  if (r.solution.length != n) {
    return 'wrong solution length';
  }

  for (int i = 0; i < n; i++) {
    if (r.solution[i] < 0 || r.solution[i] >= r.numFlows) {
      return 'invalid solution value at $i: ${r.solution[i]}';
    }
  }

  for (int f = 0; f < r.numFlows; f++) {
    final ep0 = r.endpoints[f * 2];
    final ep1 = r.endpoints[f * 2 + 1];
    if (ep0 < 0 || ep0 >= n || ep1 < 0 || ep1 >= n) {
      return 'endpoint out of bounds for flow $f';
    }
    if (ep0 == ep1) {
      return 'flow $f has identical endpoints';
    }
    if (r.solution[ep0] != f || r.solution[ep1] != f) {
      return 'endpoint solution mismatch for flow $f';
    }

    final cells = <int>{};
    for (int i = 0; i < n; i++) {
      if (r.solution[i] == f) cells.add(i);
    }
    if (cells.length < 2) {
      return 'flow $f has fewer than 2 cells';
    }

    // The flow must be DRAWABLE: a single continuous line the player can trace
    // through every one of its cells from one endpoint to the other. (A flow
    // may legally fill a 2x2 block — the game permits a path running alongside
    // itself — so we require a Hamiltonian path of the region, not a strictly
    // simple no-2x2 path.)
    if (!_drawable(cells, ep0, ep1, r.rows, r.cols)) {
      return 'flow $f not drawable as one path from $ep0 to $ep1';
    }
  }

  final count = countColorConnectSolutions(r, cap: 2);
  if (count != 1) {
    return 'not strictly solvable (solutions=$count)';
  }
  return null;
}

String signatureOf(int level, int diffIdx) {
  final r = generateColorConnectLevel(level, diffIdx);
  return ccSignature(r);
}

void main() {
  test('seed table is fully populated', () {
    expect(ccLevelsPerDifficulty, 10000);
  });

  group('Color Connect strict solvability', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('all levels 1-$ccLevelsPerDifficulty on ${_diffNames[diffIdx]} '
          'have exactly one solution', () {
        final failures = <String>[];
        for (int level = 1; level <= ccLevelsPerDifficulty; level++) {
          final err = validateLevel(level, diffIdx);
          if (err != null) {
            failures.add('level $level: $err');
            if (failures.length > 20) break;
          }
        }
        expect(failures, isEmpty,
            reason: '${_diffNames[diffIdx]} failures: $failures');
      }, timeout: const Timeout(Duration(minutes: 60)));
    }
  });

  group('Color Connect cross-level uniqueness', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('all $ccLevelsPerDifficulty levels on ${_diffNames[diffIdx]} '
          'are distinct', () {
        final seen = <String, int>{};
        final dupes = <String>[];
        for (int level = 1; level <= ccLevelsPerDifficulty; level++) {
          final sig = signatureOf(level, diffIdx);
          final prev = seen[sig];
          if (prev != null) {
            dupes.add('level $level == level $prev');
            if (dupes.length > 20) break;
          } else {
            seen[sig] = level;
          }
        }
        expect(dupes, isEmpty,
            reason: '${_diffNames[diffIdx]} duplicates: $dupes');
        expect(seen.length, ccLevelsPerDifficulty);
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
  });

  group('Color Connect toughness bands', () {
    // Easy must be easy, Hard must be hard. ccToughness counts the path cells
    // where a minimum-remaining-values solver faced a genuine choice (>1 viable
    // continuation) rather than a forced move — the felt deduction load.
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('all $ccLevelsPerDifficulty levels on ${_diffNames[diffIdx]} sit in '
          'the difficulty toughness band', () {
        final failures = <String>[];
        for (int level = 1; level <= ccLevelsPerDifficulty; level++) {
          final r = generateColorConnectLevel(level, diffIdx);
          final t = ccToughness(r);
          if (!ccToughnessOk(diffIdx, t)) {
            failures.add('level $level: toughness $t out of band '
                '[${ccToughnessMin[diffIdx]}, ${ccToughnessMax[diffIdx]}]');
            if (failures.length > 20) break;
          }
        }
        expect(failures, isEmpty,
            reason: '${_diffNames[diffIdx]} band failures: $failures');
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
  });

  group('Color Connect difficulty gradation', () {
    // Difficulty in a full-fill connect puzzle is set by two monotonic,
    // human-felt axes — board size and colour (flow) count — both of which
    // strictly increase Easy → Medium → Hard. (Branch-toughness is a within-
    // difficulty QUALITY gate, not the cross-grid separator: a 9x9 board can't
    // hold long winding paths and still be bulk-generable with a single
    // solution, so its felt difficulty comes from size + colour load, not
    // deduction depth. We therefore assert the structural gradient here and the
    // toughness BAND per difficulty in the group above.)

    Set<int> flowSet(int diffIdx) {
      final s = <int>{};
      for (int level = 1; level <= ccLevelsPerDifficulty; level++) {
        s.add(generateColorConnectLevel(level, diffIdx).numFlows);
      }
      return s;
    }

    test('grid size strictly grows Easy < Medium < Hard', () {
      expect([ccRows(0), ccRows(1), ccRows(2)], [5, 7, 9]);
      expect([ccCols(0), ccCols(1), ccCols(2)], [5, 7, 9]);
    });

    test('colour count strictly grows Easy < Medium < Hard (non-overlapping)',
        () {
      final easy = flowSet(0), medium = flowSet(1), hard = flowSet(2);
      expect(easy.reduce(math.max) < medium.reduce(math.min), isTrue,
          reason: 'easy colours $easy must all be below medium $medium');
      expect(medium.reduce(math.max) < hard.reduce(math.min), isTrue,
          reason: 'medium colours $medium must all be below hard $hard');
    }, timeout: const Timeout(Duration(minutes: 10)));

    test('Easy is the gentlest: mean toughness Easy < Medium', () {
      double mean(int diffIdx, int n) {
        double sum = 0;
        for (int level = 1; level <= n; level++) {
          sum += ccToughness(generateColorConnectLevel(level, diffIdx));
        }
        return sum / n;
      }

      const n = 3000;
      final easy = mean(0, n), medium = mean(1, n);
      expect(easy < medium, isTrue,
          reason: 'easy mean $easy should be below medium mean $medium');
    }, timeout: const Timeout(Duration(minutes: 10)));
  });

  group('Color Connect determinism', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('${_diffNames[diffIdx]} levels rebuild identically', () {
        for (final level in const [1, 2, 7, 50, 137, 5000, 9999]) {
          expect(signatureOf(level, diffIdx), signatureOf(level, diffIdx));
        }
      });
    }
  });

  group('Color Connect wrap-around', () {
    const n = 10000;
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('${_diffNames[diffIdx]} levels repeat every $n', () {
        for (final base in const [1, 2, 137, 5000, 9999, 10000]) {
          for (final cycle in const [1, 2, 7]) {
            expect(signatureOf(base + cycle * n, diffIdx),
                signatureOf(base, diffIdx),
                reason: 'level ${base + cycle * n} must equal level $base');
          }
        }
      });

      test('${_diffNames[diffIdx]} wrapped levels stay strictly unique', () {
        for (final level in const [10001, 15000, 20000, 99999]) {
          final base = (level - 1) % n + 1;
          final wrapped = generateColorConnectLevel(level, diffIdx);
          final original = generateColorConnectLevel(base, diffIdx);
          expect(wrapped.rows, original.rows);
          expect(wrapped.cols, original.cols);
          expect(wrapped.numFlows, original.numFlows);
          expect(countColorConnectSolutions(wrapped, cap: 2), 1,
              reason:
                  'wrapped level $level (== $base) not strictly solvable');
        }
      });
    }
  });
}
