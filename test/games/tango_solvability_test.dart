import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:minivo/games/tango/tango_level_gen.dart';
import 'package:minivo/games/tango/tango_seeds.g.dart';

// ---------------------------------------------------------------------------
// FULL-TABLE verification of every generated Tango level (10000 per difficulty,
// 30000 total). Proves the four guarantees the game depends on:
//
//   1. UNIQUE        — no two levels within a difficulty are identical.
//   2. SINGLE SOLUTION — each puzzle has exactly one completion (strictly
//                        solvable, one answer per the game mechanics).
//   3. RULE-VALID    — the stored solution obeys balance / no-three / clues.
//   4. GRADED + LOGIC-SOLVABLE — each puzzle is solvable by pure deduction at
//                        its difficulty's tier (no guessing), and requires
//                        exactly that tier: Easy=1, Medium=2, Hard=3. This is
//                        what makes Easy easy, Medium tougher and Hard hard.
//
// Tier definitions live in tango_level_gen.dart:
//   tier 1 = basic forced moves, tier 2 = one-ply forcing chains,
//   tier 3 = two-ply forcing chains.
// ---------------------------------------------------------------------------

const _diffNames = ['Easy', 'Medium', 'Hard'];

// Generous timeout: the tier pass runs a two-ply solver over 10000 hard
// puzzles. Comfortably finishes well under this on CI.
const _heavy = Timeout(Duration(minutes: 8));

void main() {
  test('seed table is fully populated (10000 per difficulty)', () {
    expect(tangoLevelsPerDifficulty, 10000);
    expect(tangoPacked.length, 3);
    for (final p in tangoPacked) {
      expect(p, isNotEmpty);
    }
  });

  for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
    final name = _diffNames[diffIdx];
    final n = tangoGridSize(diffIdx);
    final half = n ~/ 2;
    final tier = tangoTierFor(diffIdx);
    final total = tangoLevelsPerDifficulty;

    group('Tango $name ($n×$n, tier $tier) — all $total levels', () {
      test('every level is unique (no duplicate layouts)', () {
        final sigs = <String>{};
        for (int lvl = 1; lvl <= total; lvl++) {
          final sig = tangoSignature(generateTangoLevel(lvl, diffIdx));
          expect(sigs.add(sig), true,
              reason: '$name level $lvl duplicates an earlier level');
        }
        expect(sigs.length, total);
      }, timeout: _heavy);

      test('every level has exactly one solution', () {
        for (int lvl = 1; lvl <= total; lvl++) {
          final r = generateTangoLevel(lvl, diffIdx);
          final sols = countTangoSolutions(r, cap: 2);
          expect(sols, 1,
              reason: '$name level $lvl has $sols solutions (expected 1)');
        }
      }, timeout: _heavy);

      test('every stored solution obeys all rules + grid size', () {
        for (int lvl = 1; lvl <= total; lvl++) {
          final r = generateTangoLevel(lvl, diffIdx);
          expect(r.gridSize, n, reason: '$name $lvl wrong grid size');
          expect(r.solution.length, n * n);
          final sol = r.solution;

          // balanced rows + columns
          for (int row = 0; row < n; row++) {
            int suns = 0;
            for (int c = 0; c < n; c++) {
              if (sol[row * n + c] == 0) suns++;
            }
            expect(suns, half, reason: '$name $lvl row $row not balanced');
          }
          for (int col = 0; col < n; col++) {
            int suns = 0;
            for (int row = 0; row < n; row++) {
              if (sol[row * n + col] == 0) suns++;
            }
            expect(suns, half, reason: '$name $lvl col $col not balanced');
          }
          // no three-in-a-row, horizontal + vertical
          for (int row = 0; row < n; row++) {
            for (int c = 0; c < n - 2; c++) {
              final a = sol[row * n + c],
                  b = sol[row * n + c + 1],
                  d = sol[row * n + c + 2];
              expect(a == b && b == d, false,
                  reason: '$name $lvl 3-in-row at ($row,$c)');
            }
          }
          for (int col = 0; col < n; col++) {
            for (int row = 0; row < n - 2; row++) {
              final a = sol[row * n + col],
                  b = sol[(row + 1) * n + col],
                  d = sol[(row + 2) * n + col];
              expect(a == b && b == d, false,
                  reason: '$name $lvl 3-in-col at ($row,$col)');
            }
          }
          // clues consistent with the solution
          for (final e in r.hClues.entries) {
            final a = sol[e.key], b = sol[e.key + 1];
            if (e.value == 0) {
              expect(a, b, reason: '$name $lvl hClue ${e.key} "=" violated');
            } else {
              expect(a != b, true,
                  reason: '$name $lvl hClue ${e.key} "×" violated');
            }
          }
          for (final e in r.vClues.entries) {
            final a = sol[e.key], b = sol[e.key + n];
            if (e.value == 0) {
              expect(a, b, reason: '$name $lvl vClue ${e.key} "=" violated');
            } else {
              expect(a != b, true,
                  reason: '$name $lvl vClue ${e.key} "×" violated');
            }
          }
        }
      }, timeout: _heavy);

      test('every level is logic-solvable and requires exactly tier $tier', () {
        for (int lvl = 1; lvl <= total; lvl++) {
          final r = generateTangoLevel(lvl, diffIdx);
          final rt = tangoRequiredTier(r);
          expect(rt, tier,
              reason: '$name level $lvl required tier $rt (expected $tier); '
                  '99 would mean it needs guessing');
        }
      }, timeout: _heavy);

      test('every level round-trips through the bit codec', () {
        final stride = tangoStrideBytes(n);
        for (int lvl = 1; lvl <= total; lvl++) {
          final r = generateTangoLevel(lvl, diffIdx);
          final bytes = tangoEncodeLevel(r);
          expect(bytes.length, stride);
          final r2 = tangoDecodeLevel(n, Uint8List.fromList(bytes));
          expect(tangoSignature(r2), tangoSignature(r),
              reason: '$name level $lvl codec round-trip mismatch');
          // Every puzzle needs at least one pre-fill: a full clue set alone is
          // symmetric under swapping all suns/moons, so a single solution is
          // only possible once a pre-fill pins the parity.
          expect(r.prefilled, isNotEmpty,
              reason: '$name level $lvl has no pre-fill — would be ambiguous');
          for (final i in r.prefilled) {
            expect(r.solution[i] == 0 || r.solution[i] == 1, true,
                reason: '$name level $lvl pre-fill $i has a non-symbol value');
          }
        }
      }, timeout: _heavy);

      test('deterministic — same level always decodes to the same puzzle', () {
        for (int lvl = 1; lvl <= 25; lvl++) {
          expect(tangoSignature(generateTangoLevel(lvl, diffIdx)),
              tangoSignature(generateTangoLevel(lvl, diffIdx)));
        }
      });

      test('levels wrap around the table', () {
        expect(tangoSignature(generateTangoLevel(1, diffIdx)),
            tangoSignature(generateTangoLevel(total + 1, diffIdx)));
        expect(tangoSignature(generateTangoLevel(7, diffIdx)),
            tangoSignature(generateTangoLevel(total + 7, diffIdx)));
      });
    });
  }

  group('Difficulty is genuinely graded', () {
    // Sample-based human-readable ordering checks (the full per-level tier
    // proof above is the hard guarantee; this documents the curve).
    const sampleStep = 100; // 100 samples per difficulty

    List<int> tierAndGivens(int diffIdx) {
      int tierSum = 0, givensSum = 0, count = 0;
      for (int lvl = 1; lvl <= tangoLevelsPerDifficulty; lvl += sampleStep) {
        final r = generateTangoLevel(lvl, diffIdx);
        tierSum += tangoRequiredTier(r);
        givensSum += r.prefilled.length + r.hClues.length + r.vClues.length;
        count++;
      }
      return [tierSum ~/ count, givensSum ~/ count];
    }

    test('required deduction tier rises Easy < Medium < Hard', () {
      final easy = tangoRequiredTier(generateTangoLevel(1, 0));
      // exact tier already asserted per-level; assert the ladder explicitly.
      expect(tangoTierFor(0) < tangoTierFor(1), true);
      expect(tangoTierFor(1) < tangoTierFor(2), true);
      expect(easy, tangoTierFor(0));
    });

    test('no difficulty ever requires guessing (100% logic-solvable sample)',
        () {
      for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
        for (int lvl = 1; lvl <= tangoLevelsPerDifficulty; lvl += sampleStep) {
          final rt = tangoRequiredTier(generateTangoLevel(lvl, diffIdx));
          expect(rt <= 3, true,
              reason: '${_diffNames[diffIdx]} level $lvl needs guessing');
        }
      }
    });

    test('Hard uses fewer givens than Medium on the same 6×6 board', () {
      final med = tierAndGivens(1)[1];
      final hard = tierAndGivens(2)[1];
      expect(hard <= med, true,
          reason: 'Hard avg givens $hard should be <= Medium avg $med');
    });
  });
}
