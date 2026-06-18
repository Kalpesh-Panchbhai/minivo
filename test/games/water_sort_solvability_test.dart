import 'package:flutter_test/flutter_test.dart';

import 'package:minivo/games/water_sort/water_sort_level_gen.dart';
import 'package:minivo/games/water_sort/water_sort_seeds.g.dart';

const _diffNames = ['EASY', 'MEDIUM', 'HARD'];

// Smallest supported device is 320x568. The responsive tube layout must fit
// every level, so cap the totals we allow.
const _maxTubes = 18;
const _maxCap = 5;

/// Definitive solvability check: ask the solver for a concrete pour sequence,
/// then INDEPENDENTLY REPLAY it here — verifying every move is legal and the
/// board ends fully sorted. Proves >=1 real solution exists (no re-search, so no
/// node-cap false negatives).
String? verifySolution(List<List<int>> puzzle, int cap) {
  final sol = waterSortSolution(puzzle, cap);
  if (sol == null) return 'no solution found';
  final t = [for (final x in puzzle) List<int>.from(x)];
  for (final mv in sol) {
    final from = mv[0], to = mv[1];
    if (from == to) return 'illegal move (from==to)';
    if (t[from].isEmpty) return 'illegal move (empty source)';
    final col = t[from].last;
    if (t[to].length >= cap) return 'illegal move (dest full)';
    if (t[to].isNotEmpty && t[to].last != col) return 'illegal move (colour mismatch)';
    int run = 0;
    for (int i = t[from].length - 1; i >= 0 && t[from][i] == col; i--) {
      run++;
    }
    final moved = run < (cap - t[to].length) ? run : (cap - t[to].length);
    for (int k = 0; k < moved; k++) {
      t[from].removeLast();
      t[to].add(col);
    }
  }
  final solved =
      t.every((x) => x.isEmpty || (x.length == cap && x.toSet().length == 1));
  return solved ? null : 'replayed solution did not solve the board';
}

String? validateLevel(int level, int diffIdx) {
  final r = generateWaterSortLevel(level, diffIdx);
  final cap = r.params.tubeCapacity;
  final n = r.params.numColors;

  if (r.tubes.length != n + 3) return 'tube count ${r.tubes.length} != ${n + 3}';
  if (r.tubes.length > _maxTubes) return 'too many tubes (${r.tubes.length})';
  if (cap > _maxCap) return 'cap $cap > $_maxCap';

  // last 3 tubes: 2 free empty + 1 ad-extra, all empty at start.
  for (int i = n; i < r.tubes.length; i++) {
    if (r.tubes[i].isNotEmpty) return 'tube $i should start empty';
  }
  // each colour appears exactly cap times across the puzzle.
  final counts = <int, int>{};
  for (int i = 0; i < n; i++) {
    if (r.tubes[i].length != cap) return 'colour tube $i not full';
    for (final u in r.tubes[i]) {
      counts[u] = (counts[u] ?? 0) + 1;
    }
  }
  for (int c = 0; c < n; c++) {
    if (counts[c] != cap) return 'colour $c count ${counts[c]} != $cap';
  }

  final puzzle = puzzleTubes(r); // excludes ad-extra
  // must not start already solved
  if (puzzle.every((t) => t.isEmpty || (t.length == cap && t.toSet().length == 1))) {
    return 'starts already solved';
  }
  // solvable with the 2 free empties — proven by replaying a concrete solution
  final solErr = verifySolution(puzzle, cap);
  if (solErr != null) return solErr;
  return null;
}

String signatureOf(int level, int diffIdx) =>
    waterSortSignature(generateWaterSortLevel(level, diffIdx));

void main() {
  test('seed table is fully populated', () {
    expect(waterSortLevelsPerDifficulty, 10000);
  });

  group('Water Sort solvable + well-formed', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('all levels 1-$waterSortLevelsPerDifficulty on ${_diffNames[diffIdx]} '
          'are valid', () {
        final failures = <String>[];
        for (int level = 1; level <= waterSortLevelsPerDifficulty; level++) {
          final err = validateLevel(level, diffIdx);
          if (err != null) {
            failures.add('level $level: $err');
            if (failures.length > 20) break;
          }
        }
        expect(failures, isEmpty,
            reason: '${_diffNames[diffIdx]} failures: $failures');
      }, timeout: const Timeout(Duration(minutes: 45)));
    }
  });

  group('Water Sort cross-level uniqueness', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('all $waterSortLevelsPerDifficulty levels on ${_diffNames[diffIdx]} '
          'are distinct', () {
        final seen = <String, int>{};
        final dupes = <String>[];
        for (int level = 1; level <= waterSortLevelsPerDifficulty; level++) {
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
        expect(seen.length, waterSortLevelsPerDifficulty);
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
  });

  group('Water Sort determinism', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('${_diffNames[diffIdx]} levels rebuild identically', () {
        for (final level in const [1, 2, 7, 50, 137, 5000, 9999]) {
          expect(signatureOf(level, diffIdx), signatureOf(level, diffIdx));
        }
      });
    }
  });

  group('Water Sort wrap-around', () {
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

      test('${_diffNames[diffIdx]} wrapped levels stay valid', () {
        for (final level in const [10001, 15000, 20000, 99999]) {
          expect(validateLevel(level, diffIdx), isNull,
              reason: 'wrapped level $level not valid');
        }
      });
    }
  });
}
