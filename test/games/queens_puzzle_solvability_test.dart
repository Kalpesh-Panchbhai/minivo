import 'package:flutter_test/flutter_test.dart';

import 'package:minivo/games/queens_puzzle/queens_puzzle_difficulty.dart';
import 'package:minivo/games/queens_puzzle/queens_puzzle_level_gen.dart';
import 'package:minivo/games/queens_puzzle/queens_puzzle_seeds.g.dart';

const _diffNames = ['EASY', 'MEDIUM', 'HARD'];

// Difficulty band <-> required logical-solver tier:
//   easy = 1 (forced singles), medium = 2 (locking), hard = 3 (subset/Hall).
// Every band stays strictly 1-solution and fully logic-solvable (no guessing).
const _targetTier = [1, 2, 3];

String signatureOf(int level, int diffIdx) {
  final r = generateQueensPuzzleLevel(level, diffIdx);
  final regSigs = r.regions.map((reg) {
    final sorted = List<int>.from(reg)..sort();
    return sorted.join(',');
  }).toList()
    ..sort();
  return '${r.boardSize}|${r.queenCols.join(',')}|${regSigs.join('|')}';
}

String? validateLevel(int level, int diffIdx) {
  final r = generateQueensPuzzleLevel(level, diffIdx);
  final n = r.boardSize;

  if (r.queenCols.length != n) return 'wrong queen count (${r.queenCols.length}/$n)';
  if (r.regions.length != n) return 'wrong region count (${r.regions.length}/$n)';

  final allCells = <int>{};
  for (final reg in r.regions) {
    allCells.addAll(reg);
  }
  if (allCells.length != n * n) return 'cells not fully partitioned (${allCells.length}/${n * n})';

  for (int row = 0; row < n; row++) {
    final col = r.queenCols[row];
    final idx = row * n + col;
    int foundReg = -1;
    for (int reg = 0; reg < n; reg++) {
      if (r.regions[reg].contains(idx)) {
        foundReg = reg;
        break;
      }
    }
    if (foundReg < 0) return 'queen at ($row,$col) not in any region';
  }

  final colSet = r.queenCols.toSet();
  if (colSet.length != n) return 'duplicate queen columns';

  for (int i = 0; i < n - 1; i++) {
    if ((r.queenCols[i] - r.queenCols[i + 1]).abs() <= 1) {
      return 'adjacent queens at rows $i/${i + 1}';
    }
  }

  final count = countQueensPuzzleSolutions(r, cap: 2);
  if (count != 1) return 'not strictly solvable (solutions=$count)';

  final grade = gradeQueensPuzzle(r);
  if (grade.tier == 0) {
    return 'not solvable by pure logic (would need guessing)';
  }
  if (grade.tier != _targetTier[diffIdx]) {
    return 'wrong difficulty tier (got ${grade.tier}, '
        'want ${_targetTier[diffIdx]})';
  }

  return null;
}

void main() {
  test('seed table is fully populated', () {
    expect(queensPuzzleLevelsPerDifficulty, 10000);
  });

  group('Queens Puzzle strict solvability + difficulty band', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('all levels 1-$queensPuzzleLevelsPerDifficulty on ${_diffNames[diffIdx]} '
          'have exactly one solution and tier ${_targetTier[diffIdx]}', () {
        final failures = <String>[];
        for (int level = 1; level <= queensPuzzleLevelsPerDifficulty; level++) {
          final err = validateLevel(level, diffIdx);
          if (err != null) {
            failures.add('level $level: $err');
            if (failures.length > 20) break;
          }
        }
        expect(failures, isEmpty,
            reason: '${_diffNames[diffIdx]} failures: $failures');
      }, timeout: const Timeout(Duration(minutes: 30)));
    }
  });

  group('Queens Puzzle cross-level uniqueness', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('all $queensPuzzleLevelsPerDifficulty levels on ${_diffNames[diffIdx]} '
          'are distinct', () {
        final seen = <String, int>{};
        final dupes = <String>[];
        for (int level = 1; level <= queensPuzzleLevelsPerDifficulty; level++) {
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
        expect(seen.length, queensPuzzleLevelsPerDifficulty);
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
  });

  group('Queens Puzzle determinism', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('${_diffNames[diffIdx]} levels rebuild identically', () {
        for (final level in const [1, 2, 7, 50, 137, 5000, 9999]) {
          expect(signatureOf(level, diffIdx), signatureOf(level, diffIdx));
        }
      });
    }
  });

  group('Queens Puzzle wrap-around', () {
    const n = 10000;
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('${_diffNames[diffIdx]} levels repeat every $n', () {
        for (final base in const [1, 2, 137, 5000, 9999, 10000]) {
          for (final cycle in const [1, 2, 7]) {
            expect(signatureOf(base + cycle * n, diffIdx), signatureOf(base, diffIdx),
                reason: 'level ${base + cycle * n} must equal level $base');
          }
        }
      });

      test('${_diffNames[diffIdx]} wrapped levels stay strictly unique', () {
        for (final level in const [10001, 15000, 20000, 99999]) {
          final base = (level - 1) % n + 1;
          final wrapped = generateQueensPuzzleLevel(level, diffIdx);
          final original = generateQueensPuzzleLevel(base, diffIdx);
          expect(wrapped.boardSize, original.boardSize);
          expect(countQueensPuzzleSolutions(wrapped, cap: 2), 1,
              reason: 'wrapped level $level (== $base) not strictly solvable');
          expect(gradeQueensPuzzle(wrapped).tier, _targetTier[diffIdx],
              reason: 'wrapped level $level (== $base) wrong difficulty tier');
        }
      });
    }
  });

  group('Queens Puzzle difficulty gradient', () {
    // Sampled tier check: every band must hit its exact tier (a fast
    // cross-check of the exhaustive solvability group above).
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('${_diffNames[diffIdx]} sample is exactly tier ${_targetTier[diffIdx]}', () {
        for (int level = 1; level <= queensPuzzleLevelsPerDifficulty; level += 137) {
          final r = generateQueensPuzzleLevel(level, diffIdx);
          expect(gradeQueensPuzzle(r).tier, _targetTier[diffIdx],
              reason: '${_diffNames[diffIdx]} level $level wrong tier');
        }
      });
    }

    test('average logical difficulty strictly increases easy < medium < hard', () {
      final avg = List<double>.filled(3, 0);
      const step = 211;
      for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
        int sum = 0, count = 0;
        for (int level = 1; level <= queensPuzzleLevelsPerDifficulty; level += step) {
          sum += gradeQueensPuzzle(generateQueensPuzzleLevel(level, diffIdx)).score;
          count++;
        }
        avg[diffIdx] = sum / count;
      }
      expect(avg[0] < avg[1], isTrue,
          reason: 'easy(${avg[0]}) must be easier than medium(${avg[1]})');
      expect(avg[1] < avg[2], isTrue,
          reason: 'medium(${avg[1]}) must be easier than hard(${avg[2]})');
    });
  });
}
