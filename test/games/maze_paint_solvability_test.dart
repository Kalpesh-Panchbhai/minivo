import 'package:flutter_test/flutter_test.dart';

import 'package:minivo/games/maze_paint/maze_paint_level_gen.dart';
import 'package:minivo/games/maze_paint/maze_paint_seeds.g.dart';

// ---------------------------------------------------------------------------
// Exhaustive verification of the baked Maze Paint table: every one of the
// 10,000 levels per difficulty is strictly solvable (EXACTLY one irredundant
// route), cross-level unique, sits in its toughness band, and the three
// difficulties form a clean, monotonic difficulty gradient.
// ---------------------------------------------------------------------------

const _diffNames = ['EASY', 'MEDIUM', 'HARD'];

bool _floorConnected(MazePaintLevel r) {
  final area = r.rows * r.cols;
  final floor = <int>{};
  for (int i = 0; i < area; i++) {
    if (!r.walls.contains(i)) floor.add(i);
  }
  if (floor.isEmpty) return false;
  final seen = <int>{floor.first};
  final stack = <int>[floor.first];
  while (stack.isNotEmpty) {
    final cur = stack.removeLast();
    final cr = cur ~/ r.cols, cc = cur % r.cols;
    for (final d in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
      final nr = cr + d.$1, nc = cc + d.$2;
      if (nr < 0 || nr >= r.rows || nc < 0 || nc >= r.cols) continue;
      final ni = nr * r.cols + nc;
      if (floor.contains(ni) && seen.add(ni)) stack.add(ni);
    }
  }
  return seen.length == floor.length;
}

String? validateLevel(int level, int diffIdx) {
  final r = generateMazePaintLevel(level, diffIdx);
  final area = r.rows * r.cols;

  if (r.rows != mpRows(diffIdx) || r.cols != mpCols(diffIdx)) {
    return 'wrong dimensions ${r.rows}x${r.cols}';
  }
  if (r.start < 0 || r.start >= area) return 'start out of bounds ${r.start}';
  if (r.walls.contains(r.start)) return 'start is on a wall';
  if (r.paintableCount < 4) return 'too few floor tiles (${r.paintableCount})';
  // Requirement #7: the board is NOT a full rectangle — it is an irregular
  // shape with some cells walled off.
  if (r.paintableCount >= area) return 'board is a full rectangle (not irregular)';
  if (!_floorConnected(r)) return 'floor region is disconnected';
  if (r.solution.isEmpty) return 'empty solution';

  // The baked solution must paint every floor tile when replayed.
  if (mpReplay(r).length != r.paintableCount) {
    return 'baked solution does not cover all tiles';
  }

  // Strictly solvable: exactly one irredundant route exists.
  final count = countMazePaintSolutions(r, cap: 2);
  if (count != 1) return 'not strictly solvable (solutions=$count)';
  return null;
}

void main() {
  test('seed table is fully populated', () {
    expect(mpLevelsPerDifficulty, 10000);
  });

  group('Maze Paint strict solvability', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test(
          'all $mpLevelsPerDifficulty levels on ${_diffNames[diffIdx]} have '
          'exactly one solution', () {
        final failures = <String>[];
        for (int level = 1; level <= mpLevelsPerDifficulty; level++) {
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

  group('Maze Paint cross-level uniqueness', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('all $mpLevelsPerDifficulty levels on ${_diffNames[diffIdx]} are '
          'distinct', () {
        final seen = <String, int>{};
        final dupes = <String>[];
        for (int level = 1; level <= mpLevelsPerDifficulty; level++) {
          final sig = mpSignature(generateMazePaintLevel(level, diffIdx));
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
        expect(seen.length, mpLevelsPerDifficulty);
      }, timeout: const Timeout(Duration(minutes: 10)));
    }

    test('all 30,000 levels are globally distinct across difficulties', () {
      final seen = <String>{};
      var collisions = 0;
      for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
        for (int level = 1; level <= mpLevelsPerDifficulty; level++) {
          // Dimensions are part of the signature, so cross-difficulty
          // collisions are structurally impossible — assert it anyway.
          if (!seen.add(mpSignature(generateMazePaintLevel(level, diffIdx)))) {
            collisions++;
          }
        }
      }
      expect(collisions, 0);
      expect(seen.length, 30000);
    }, timeout: const Timeout(Duration(minutes: 10)));
  });

  group('Maze Paint toughness bands', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('all $mpLevelsPerDifficulty levels on ${_diffNames[diffIdx]} sit in '
          'the difficulty toughness band', () {
        final failures = <String>[];
        for (int level = 1; level <= mpLevelsPerDifficulty; level++) {
          final t = mpToughness(generateMazePaintLevel(level, diffIdx));
          if (!mpToughnessOk(diffIdx, t)) {
            failures.add('level $level: toughness $t out of band '
                '[${mpToughnessMin[diffIdx]}, ${mpToughnessMax[diffIdx]}]');
            if (failures.length > 20) break;
          }
        }
        expect(failures, isEmpty,
            reason: '${_diffNames[diffIdx]} band failures: $failures');
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
  });

  group('Maze Paint difficulty gradation', () {
    double meanOf(int diffIdx, int n, int Function(MazePaintLevel) metric) {
      double sum = 0;
      for (int level = 1; level <= n; level++) {
        sum += metric(generateMazePaintLevel(level, diffIdx));
      }
      return sum / n;
    }

    test('board size strictly grows Easy < Medium < Hard', () {
      expect([mpRows(0), mpRows(1), mpRows(2)], [5, 6, 7]);
      expect([mpCols(0), mpCols(1), mpCols(2)], [5, 6, 7]);
    });

    test('mean floor count grows Easy < Medium < Hard', () {
      const n = 3000;
      final e = meanOf(0, n, (l) => l.paintableCount);
      final m = meanOf(1, n, (l) => l.paintableCount);
      final h = meanOf(2, n, (l) => l.paintableCount);
      expect(e < m, isTrue, reason: 'floor easy $e !< medium $m');
      expect(m < h, isTrue, reason: 'floor medium $m !< hard $h');
    });

    test('mean solution length grows Easy < Medium < Hard', () {
      const n = 3000;
      final e = meanOf(0, n, (l) => l.solution.length);
      final m = meanOf(1, n, (l) => l.solution.length);
      final h = meanOf(2, n, (l) => l.solution.length);
      expect(e < m, isTrue, reason: 'solLen easy $e !< medium $m');
      expect(m < h, isTrue, reason: 'solLen medium $m !< hard $h');
    });

    test('mean branch toughness grows Easy < Medium < Hard', () {
      const n = 3000;
      final e = meanOf(0, n, mpToughness);
      final m = meanOf(1, n, mpToughness);
      final h = meanOf(2, n, mpToughness);
      expect(e < m, isTrue, reason: 'toughness easy $e !< medium $m');
      expect(m < h, isTrue, reason: 'toughness medium $m !< hard $h');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('Maze Paint determinism + wrap-around', () {
    const n = 10000;
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('${_diffNames[diffIdx]} levels rebuild identically', () {
        for (final level in const [1, 2, 50, 137, 5000, 9999, 10000]) {
          final a = mpSignature(generateMazePaintLevel(level, diffIdx));
          final b = mpSignature(generateMazePaintLevel(level, diffIdx));
          expect(a, b);
        }
      });

      test('${_diffNames[diffIdx]} levels repeat every $n', () {
        for (final base in const [1, 137, 5000, 10000]) {
          for (final cycle in const [1, 2, 7]) {
            expect(
              mpSignature(generateMazePaintLevel(base + cycle * n, diffIdx)),
              mpSignature(generateMazePaintLevel(base, diffIdx)),
            );
          }
        }
      });

      test('${_diffNames[diffIdx]} wrapped levels stay strictly solvable', () {
        for (final level in const [10001, 15000, 23456, 99999]) {
          final r = generateMazePaintLevel(level, diffIdx);
          expect(mpReplay(r).length, r.paintableCount);
          expect(countMazePaintSolutions(r, cap: 2), 1,
              reason: 'wrapped level $level not strictly solvable');
        }
      });
    }
  });

  group('Maze Paint encode/decode round-trip', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('${_diffNames[diffIdx]} levels survive encode→decode', () {
        for (final level in const [1, 2, 99, 1000, 9999]) {
          final r = generateMazePaintLevel(level, diffIdx);
          final back =
              mpDecodeLevel(r.rows, r.cols, mpEncodeLevel(r));
          expect(back.start, r.start);
          expect(back.walls, r.walls);
          expect(back.solution, r.solution);
        }
      });
    }
  });
}
