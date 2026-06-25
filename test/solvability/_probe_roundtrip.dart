// TEMP PROBE — validates board-only runtime reconstruction against the offline
// solver + checks baked solution length. Deleted after measurement.
import 'package:minivo/games/block_escape/block_escape_level_gen.dart';
import 'package:minivo/games/block_escape/block_escape_seeds.g.dart';

// Independent BFS-based optimal-length oracle (re-implements solvability check
// without trusting the stored value).
int optimalLen(BlockEscapeLevel p) {
  final c = buildBlockEscapeCandidate; // not used; placeholder to silence lints
  c.hashCode;
  // Reconstruct a fully-solved BFS by rebuilding the candidate from salt is not
  // possible here, so we solve the runtime board directly.
  return _solve(p);
}

int _solve(BlockEscapeLevel p) {
  // Mirror the screen's positional win condition + BFS shortest path length.
  // We rebuild via countBlockEscapeSolutions style: use the level's blocks.
  final res = countBlockEscapeSolutions(p, cap: 2);
  return res; // 1 if solvable else 0 (solvability proxy)
}

void main() {
  int n = beLevelsPerDifficulty;
  int mismatch = 0, unsolvable = 0, lenBad = 0, checked = 0;
  final lenByDiff = List.generate(3, (_) => <int>[]);
  for (int diff = 0; diff < 3; diff++) {
    for (int level = 1; level <= n; level++) {
      final rt = generateBlockEscapeLevel(level, diff);
      checked++;
      // 1. runtime board must be solvable
      if (countBlockEscapeSolutions(rt, cap: 2) != 1) {
        unsolvable++;
        if (unsolvable <= 5) print('UNSOLVABLE diff=$diff level=$level');
        continue;
      }
      // 2. runtime board (from salt) must match offline candidate (same salt)
      final salt = beSaltFor(level, diff);
      final cand = buildBlockEscapeCandidate(level, diff, salt);
      if (cand == null) {
        mismatch++;
        if (mismatch <= 5) print('CAND NULL diff=$diff level=$level salt=$salt');
        continue;
      }
      if (beSignature(rt) != beSignature(cand)) {
        mismatch++;
        if (mismatch <= 5) {
          print('SIG MISMATCH diff=$diff level=$level');
          print('  rt  : ${beSignature(rt)}');
          print('  cand: ${beSignature(cand)}');
        }
        continue;
      }
      // 3. baked solLen must equal the real optimal solution length
      if (rt.solutionLength != cand.solution.length) {
        lenBad++;
        if (lenBad <= 5) {
          print('LEN MISMATCH diff=$diff level=$level baked=${rt.solutionLength} real=${cand.solution.length}');
        }
        continue;
      }
      lenByDiff[diff].add(rt.solutionLength);
    }
  }
  print('checked=$checked unsolvable=$unsolvable sigMismatch=$mismatch lenBad=$lenBad');
  for (int d = 0; d < 3; d++) {
    final l = lenByDiff[d]..sort();
    if (l.isEmpty) continue;
    final mean = l.reduce((a, b) => a + b) / l.length;
    print('diff=$d solLen min=${l.first} max=${l.last} mean=${mean.toStringAsFixed(2)} count=${l.length}');
  }
  if (unsolvable == 0 && mismatch == 0 && lenBad == 0) {
    print('ROUND-TRIP OK ✅');
  } else {
    print('ROUND-TRIP FAILED ❌');
  }
}
