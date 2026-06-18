import 'package:flutter_test/flutter_test.dart';

import 'package:minivo/games/arrow_puzzle/arrow_puzzle_level_gen.dart';
import 'package:minivo/games/arrow_puzzle/arrow_puzzle_seeds.g.dart';

const _diffNames = ['EASY', 'MEDIUM', 'HARD'];

// Smallest supported device (see test/helpers/screen_sizes.dart): 320x568.
// Board area after HUD/hint/padding is ~288x~330px; at the 24px minimum cell
// that means a board may be at most ~12 wide x ~13 tall to stay tappable
// without zoom on every iOS + Android device.
const _maxCols = 12;
const _maxRows = 13;

/// Independent solver — sequential greedy free-one-at-a-time, a DIFFERENT code
/// path from the Kahn removalDepth() used during generation. Cross-validates
/// solvability so the suite doesn't just re-run the generator's own logic.
bool seqSolvable(List<ArrowData> arrows) {
  final n = arrows.length;
  final freed = List<bool>.filled(n, false);
  int rem = n;
  bool progress = true;
  while (rem > 0 && progress) {
    progress = false;
    for (int i = 0; i < n; i++) {
      if (freed[i]) continue;
      bool blocked = false;
      for (int j = 0; j < n; j++) {
        if (i == j || freed[j]) continue;
        if (arrows[i].isBlockedBy(arrows[j])) {
          blocked = true;
          break;
        }
      }
      if (!blocked) {
        freed[i] = true;
        rem--;
        progress = true;
      }
    }
  }
  return rem == 0;
}

/// null if [level] is well-formed: fully packed (no gaps), solvable by two
/// independent solvers, enough arrows, inside its tier's depth band, and fits
/// the smallest device.
String? validateLevel(int level, int diffIdx) {
  final r = generateArrowLevel(level, diffIdx);
  if (r.arrows.length < 4) return 'too few arrows (${r.arrows.length})';
  if (r.gridCols > _maxCols || r.gridRows > _maxRows) {
    return 'board ${r.gridCols}x${r.gridRows} exceeds device cap';
  }
  if (!fullyCovered(r)) return 'not fully packed (has gaps)';
  for (final a in r.arrows) {
    if (a.segments.length < 2) return 'degenerate arrow ${a.id}';
    // Arrows must be STRAIGHT bars (all cells share a row or a column). This is
    // what makes head-direction blocking == real full-body flight physics, so an
    // arrow can never be blocked by its own body or sweep through another.
    final sameRow = a.segments.every((p) => p.dy == a.segments.first.dy);
    final sameCol = a.segments.every((p) => p.dx == a.segments.first.dx);
    if (!sameRow && !sameCol) return 'arrow ${a.id} is bent (not a straight bar)';
    if (arrowSelfBlocks(a)) return 'arrow ${a.id} points into its own body';
  }

  final depth = removalDepth(r.arrows); // Kahn
  if (depth < 0) return 'unsolvable (deadlock)';
  if (!seqSolvable(r.arrows)) return 'unsolvable (independent solver)';

  final s = arrowSpec(diffIdx);
  if (depth < s.depthMin || depth > s.depthMax) {
    return 'depth $depth outside [${s.depthMin},${s.depthMax}]';
  }
  return null;
}

String signatureOf(int level, int diffIdx) =>
    arrowSignature(generateArrowLevel(level, diffIdx));

void main() {
  test('seed table is fully populated', () {
    expect(arrowLevelsPerDifficulty, 10000);
  });

  group('Arrow Puzzle solvable + packed + in band', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('all levels 1-$arrowLevelsPerDifficulty on ${_diffNames[diffIdx]} '
          'are valid', () {
        final failures = <String>[];
        for (int level = 1; level <= arrowLevelsPerDifficulty; level++) {
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

  group('Arrow Puzzle cross-level uniqueness', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('all $arrowLevelsPerDifficulty levels on ${_diffNames[diffIdx]} '
          'are distinct', () {
        final seen = <String, int>{};
        final dupes = <String>[];
        for (int level = 1; level <= arrowLevelsPerDifficulty; level++) {
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
        expect(seen.length, arrowLevelsPerDifficulty);
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
  });

  group('Arrow Puzzle determinism', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('${_diffNames[diffIdx]} levels rebuild identically', () {
        for (final level in const [1, 2, 7, 50, 137, 5000, 9999]) {
          expect(signatureOf(level, diffIdx), signatureOf(level, diffIdx));
        }
      });
    }
  });

  group('Arrow Puzzle wrap-around', () {
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
