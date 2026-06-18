import 'package:flutter_test/flutter_test.dart';

import 'package:minivo/games/zip/zip_level_gen.dart';
import 'package:minivo/games/zip/zip_seeds.g.dart';

const _diffNames = ['EASY', 'MEDIUM', 'HARD'];

bool _adj(int a, int b, int n) {
  final ar = a ~/ n, ac = a % n;
  final br = b ~/ n, bc = b % n;
  return (ar == br && (ac - bc).abs() == 1) ||
      (ac == bc && (ar - br).abs() == 1);
}

/// Returns an error string for [level], or null if the level is well-formed,
/// strictly solvable (exactly one solution), and consistent with the gameplay
/// rules enforced by zip_screen.
String? validateLevel(int level, int diffIdx) {
  final r = generateZipLevel(level, diffIdx);
  final n = r.gridSize;
  final total = n * n;
  final path = r.solutionPath;

  // 1. The stored solution must be a Hamiltonian path.
  if (path.length != total || path.toSet().length != total) {
    return 'path not Hamiltonian (${path.length}/$total)';
  }
  for (int i = 0; i < path.length - 1; i++) {
    if (!_adj(path[i], path[i + 1], n)) {
      return 'non-adjacent step at $i';
    }
    if (r.walls.contains(edgeKey(path[i], path[i + 1]))) {
      return 'wall blocks solution path at $i';
    }
  }

  // 2. Checkpoints: #1 at the start, highest at the end, strictly increasing
  //    by 1 along the path (matches the order zip_screen enforces).
  final entries = r.checkpoints.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  if (entries.isEmpty) return 'no checkpoints';
  if (entries.first.key != 0 || entries.first.value != 1) {
    return 'checkpoint #1 not at path start';
  }
  if (entries.last.key != total - 1) {
    return 'highest checkpoint not at path end';
  }
  for (int i = 0; i < entries.length; i++) {
    if (entries[i].value != i + 1) {
      return 'checkpoint numbering not sequential at $i';
    }
  }

  // 3. Strict solvability: exactly one valid solution.
  final count = countZipSolutions(r, cap: 2);
  if (count != 1) {
    return 'not strictly solvable (solutions=$count)';
  }
  return null;
}

String signatureOf(int level, int diffIdx) {
  final r = generateZipLevel(level, diffIdx);
  final w = r.walls.toList()..sort();
  final cp = r.checkpoints.entries.map((e) => '${e.key}:${e.value}').toList()
    ..sort();
  return '${r.gridSize}|${r.solutionPath.join(',')}|${w.join(',')}|${cp.join(',')}';
}

void main() {
  // The embedded seed table must hold the real 10k entries (run
  // `dart run test/solvability/generate_zip_seeds.dart` first).
  test('seed table is fully populated', () {
    expect(zipLevelsPerDifficulty, 10000);
  });

  group('Zip strict solvability', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('all levels 1-$zipLevelsPerDifficulty on ${_diffNames[diffIdx]} '
          'have exactly one solution', () {
        final failures = <String>[];
        for (int level = 1; level <= zipLevelsPerDifficulty; level++) {
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

  group('Zip cross-level uniqueness', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('all $zipLevelsPerDifficulty levels on ${_diffNames[diffIdx]} '
          'are distinct', () {
        final seen = <String, int>{};
        final dupes = <String>[];
        for (int level = 1; level <= zipLevelsPerDifficulty; level++) {
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
        expect(seen.length, zipLevelsPerDifficulty);
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
  });

  // Determinism: the same level is identical on every device (seeded build +
  // baked salt table), so two independent builds must match byte-for-byte.
  group('Zip determinism', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('${_diffNames[diffIdx]} levels rebuild identically', () {
        for (final level in const [1, 2, 7, 50, 137, 5000, 9999]) {
          expect(signatureOf(level, diffIdx), signatureOf(level, diffIdx));
        }
      });
    }
  });

  // Wrap-around: past 10k the puzzles repeat (10001->1, 10002->2, ...) forever
  // while the displayed level keeps climbing.
  group('Zip wrap-around', () {
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
        // A wrapped level must rebuild the verified-unique original exactly:
        // same grid size AND still exactly one solution.
        for (final level in const [10001, 15000, 20000, 99999]) {
          final base = (level - 1) % n + 1;
          final wrapped = generateZipLevel(level, diffIdx);
          final original = generateZipLevel(base, diffIdx);
          expect(wrapped.gridSize, original.gridSize);
          expect(countZipSolutions(wrapped, cap: 2), 1,
              reason: 'wrapped level $level (== $base) not strictly solvable');
        }
      });
    }
  });
}
