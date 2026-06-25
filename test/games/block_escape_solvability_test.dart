import 'package:flutter_test/flutter_test.dart';

import 'package:minivo/games/block_escape/block_escape_level_gen.dart';
import 'package:minivo/games/block_escape/block_escape_seeds.g.dart';

const _diffNames = ['EASY', 'MEDIUM', 'HARD'];

// ---------------------------------------------------------------------------
// Ground-truth verification for EVERY shipped level.
//
// For each (level, difficulty) we:
//  1. Rebuild the offline candidate from its baked salt — this re-runs the BFS
//     solver and re-enforces the move-count band, so a non-null result proves
//     the level is solvable AND in band at the salt we shipped.
//  2. Reconstruct the device-side board (generateBlockEscapeLevel, no solver)
//     and assert it is byte-identical to the verified candidate.
//  3. REPLAY the optimal solution move-by-move with full legality checks and
//     assert the target piece actually reaches the exit — an independent proof
//     that doesn't trust the solver's own "I found a path" claim.
//  4. Assert the baked solution length equals the true optimal and sits inside
//     the difficulty band.
// ---------------------------------------------------------------------------

/// Replays [p.solution] on a copy of [p.blocks], validating every single-cell
/// step is in-bounds (the target may slide out through the right edge) and does
/// not collide with another piece. Returns null on success, else the reason the
/// stored solution is not a legal winning sequence.
String? replayCheck(BlockEscapeLevel p) {
  final cur = <int, Block>{for (final b in p.blocks) b.id: b};

  for (final (id, delta) in p.solution) {
    final b0 = cur[id];
    if (b0 == null) return 'move references unknown block $id';
    if (delta == 0) return 'zero-delta move (should be compressed out)';
    var b = b0;
    final step = delta > 0 ? 1 : -1;
    for (int k = 0; k < delta.abs(); k++) {
      final nb = b.moved(step);
      for (final (r, c) in nb.cells) {
        final exiting = b.isTarget && b.dir == BlockDir.horizontal && c >= p.cols;
        if (!exiting && (r < 0 || r >= p.rows || c < 0 || c >= p.cols)) {
          return 'block $id moved out of bounds at ($r,$c)';
        }
        for (final o in cur.values) {
          if (o.id == id) continue;
          for (final (or, oc) in o.cells) {
            if (or == r && oc == c) return 'block $id collided with ${o.id} at ($r,$c)';
          }
        }
      }
      b = nb;
    }
    cur[id] = b;
  }

  final target = cur.values.firstWhere((x) => x.isTarget);
  if (target.col + target.length < p.cols) {
    return 'target did not reach the exit (col=${target.col} len=${target.length})';
  }
  return null;
}

/// Full structural + solvability + band validation for one level. Returns null
/// when the level is correct, else a human-readable failure reason.
String? validateLevel(int level, int diffIdx) {
  // Levels past the table wrap (level N+1 replays puzzle 1). The device rebuilds
  // the wrapped puzzle from the effective index, so the candidate must be
  // verified at that same index — not the raw level, whose RNG seed differs.
  final eff = (level - 1) % beLevelsPerDifficulty + 1;
  final salt = beSaltFor(eff, diffIdx);

  // (1) Offline candidate: solvable + in band at the shipped salt.
  final cand = buildBlockEscapeCandidate(eff, diffIdx, salt);
  if (cand == null) {
    return 'salt $salt no longer yields a solvable in-band level';
  }

  // (2) Device reconstruction matches the verified candidate exactly.
  final rt = generateBlockEscapeLevel(level, diffIdx);
  if (rt.rows != 6 || rt.cols != 6) return 'wrong dimensions ${rt.rows}x${rt.cols}';
  if (beSignature(rt) != beSignature(cand)) {
    return 'device board != verified board\n  rt:   ${beSignature(rt)}\n  cand: ${beSignature(cand)}';
  }

  final targets = rt.blocks.where((b) => b.isTarget).toList();
  if (targets.length != 1) return '${targets.length} target blocks (expected 1)';
  final target = targets.first;
  if (target.dir != BlockDir.horizontal) return 'target not horizontal';
  if (target.row != rt.exitRow) return 'target row ${target.row} != exitRow ${rt.exitRow}';

  final occupied = <(int, int)>{};
  for (final b in rt.blocks) {
    for (final cell in b.cells) {
      if (!occupied.add(cell)) return 'overlap at $cell';
      if (cell.$1 < 0 || cell.$1 >= rt.rows || cell.$2 < 0 || cell.$2 >= rt.cols) {
        return 'block ${b.id} out of bounds at $cell';
      }
    }
  }

  // (3) Independent replay proof.
  final replay = replayCheck(cand);
  if (replay != null) return 'replay failed: $replay';

  // (4) Baked depth correctness + band contract.
  if (rt.solutionLength != cand.solution.length) {
    return 'baked depth ${rt.solutionLength} != optimal ${cand.solution.length}';
  }
  final len = cand.solution.length;
  final lo = beMinSolLen(diffIdx), hi = beMaxSolLen(diffIdx);
  if (len < lo || len > hi) return 'depth $len outside band [$lo..$hi]';

  return null;
}

void main() {
  test('seed table is fully populated', () {
    expect(beLevelsPerDifficulty, 10000);
  });

  group('Block Escape solvability + replay + band', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('all $beLevelsPerDifficulty levels on ${_diffNames[diffIdx]} verify', () {
        final failures = <String>[];
        for (int level = 1; level <= beLevelsPerDifficulty; level++) {
          final err = validateLevel(level, diffIdx);
          if (err != null) {
            failures.add('level $level: $err');
            if (failures.length > 20) break;
          }
        }
        expect(failures, isEmpty,
            reason: '${_diffNames[diffIdx]} failures: $failures');
      }, timeout: const Timeout(Duration(minutes: 90)));
    }
  });

  group('Block Escape cross-level uniqueness', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('all $beLevelsPerDifficulty levels on ${_diffNames[diffIdx]} are distinct', () {
        final seen = <String, int>{};
        final dupes = <String>[];
        for (int level = 1; level <= beLevelsPerDifficulty; level++) {
          final sig = beSignature(generateBlockEscapeLevel(level, diffIdx));
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
        expect(seen.length, beLevelsPerDifficulty);
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
  });

  group('Block Escape determinism + wrap-around', () {
    const n = 10000;
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('${_diffNames[diffIdx]} levels rebuild identically', () {
        for (final level in const [1, 2, 50, 137, 5000, 9999, 10000]) {
          final a = beSignature(generateBlockEscapeLevel(level, diffIdx));
          final b = beSignature(generateBlockEscapeLevel(level, diffIdx));
          expect(a, b);
          final la = generateBlockEscapeLevel(level, diffIdx).solutionLength;
          final lb = generateBlockEscapeLevel(level, diffIdx).solutionLength;
          expect(la, lb);
        }
      });

      test('${_diffNames[diffIdx]} levels repeat every $n', () {
        for (final base in const [1, 137, 5000, 10000]) {
          for (final cycle in const [1, 2, 7]) {
            expect(
              beSignature(generateBlockEscapeLevel(base + cycle * n, diffIdx)),
              beSignature(generateBlockEscapeLevel(base, diffIdx)),
            );
          }
        }
      });

      test('${_diffNames[diffIdx]} wrapped levels stay solvable + in band', () {
        for (final level in const [10001, 15000, 23456]) {
          final err = validateLevel(level, diffIdx);
          expect(err, isNull, reason: 'wrapped level $level: $err');
        }
      });
    }
  });

  group('Block Escape difficulty gradation', () {
    // Sample the table; rebuilding candidates runs the solver, so cap the size.
    const n = 600;

    ({double mean, int min, int max, int median, double p90}) solStats(int diffIdx) {
      final lens = <int>[];
      for (int level = 1; level <= n; level++) {
        lens.add(generateBlockEscapeLevel(level, diffIdx).solutionLength);
      }
      lens.sort();
      final mean = lens.reduce((a, b) => a + b) / lens.length;
      return (
        mean: mean,
        min: lens.first,
        max: lens.last,
        median: lens[lens.length ~/ 2],
        p90: lens[(lens.length * 0.9).floor()].toDouble(),
      );
    }

    double meanBlockCount(int diffIdx) {
      double sum = 0;
      for (int level = 1; level <= n; level++) {
        sum += generateBlockEscapeLevel(level, diffIdx).blocks.length;
      }
      return sum / n;
    }

    test('every sampled depth sits inside its difficulty band', () {
      for (int d = 0; d < 3; d++) {
        final s = solStats(d);
        expect(s.min, greaterThanOrEqualTo(beMinSolLen(d)),
            reason: '${_diffNames[d]} min depth ${s.min} < band ${beMinSolLen(d)}');
        expect(s.max, lessThanOrEqualTo(beMaxSolLen(d)),
            reason: '${_diffNames[d]} max depth ${s.max} > band ${beMaxSolLen(d)}');
      }
    });

    test('tier medians are clearly separated — a real jump per tier', () {
      // Bands overlap slightly by design (see beMinSolLen docs): move count
      // alone is a weak difficulty proxy. What a player feels is the clean
      // separation of the typical (median) depth, which must step up firmly
      // from one tier to the next.
      final em = solStats(0).median, mm = solStats(1).median, hm = solStats(2).median;
      expect(em, lessThan(mm), reason: 'easy median $em !< medium median $mm');
      expect(mm, lessThan(hm), reason: 'medium median $mm !< hard median $hm');
      // And the jump is a real one, not a single move.
      expect(mm - em, greaterThanOrEqualTo(2), reason: 'easy->medium jump too small');
      expect(hm - mm, greaterThanOrEqualTo(2), reason: 'medium->hard jump too small');
    });

    test('mean depth grows Easy < Medium < Hard', () {
      final e = solStats(0).mean, m = solStats(1).mean, h = solStats(2).mean;
      expect(e < m, isTrue, reason: 'depth easy $e !< medium $m');
      expect(m < h, isTrue, reason: 'depth medium $m !< hard $h');
    });

    test('Easy stays genuinely easy; Hard stays genuinely hard', () {
      final e = solStats(0), h = solStats(2);
      // Easy: most levels short enough for high first-try success.
      expect(e.p90, lessThanOrEqualTo(beMaxSolLen(0).toDouble()));
      expect(e.mean, lessThan(beMinSolLen(1).toDouble()),
          reason: 'easy mean ${e.mean} not clearly below medium floor');
      // Hard: average depth well above the medium ceiling.
      expect(h.mean, greaterThan(beMaxSolLen(1).toDouble()),
          reason: 'hard mean ${h.mean} not clearly above medium ceiling');
    });

    test('mean block count grows Easy < Medium < Hard', () {
      final e = meanBlockCount(0), m = meanBlockCount(1), h = meanBlockCount(2);
      expect(e < m, isTrue, reason: 'blocks easy $e !< medium $m');
      expect(m < h, isTrue, reason: 'blocks medium $m !< hard $h');
    });
  });
}
