import 'package:flutter_test/flutter_test.dart';

import 'package:minivo/games/block_escape/block_escape_level_gen.dart';
import 'package:minivo/games/block_escape/block_escape_seeds.g.dart';

// ---------------------------------------------------------------------------
// HINT-SOLVER correctness.
//
// blockEscapeHintMove is the live, runtime hint used by the play screen
// (_applyHint). It runs the same node-capped int-grid BFS as the offline
// solver and returns the FIRST compressed car-move of a shortest solution from
// the CURRENT board. Nothing else in the suite exercises it — the end-to-end
// play test replays the BAKED solution, never the hint path.
//
// We prove three things per sampled level:
//   1. On a solvable board the hint is never null and is a LEGAL move.
//   2. The hint on the initial board equals the offline-optimal first move
//      (same BFS, same input -> same output).
//   3. Greedily applying the hint move-by-move WINS the level in exactly the
//      optimal number of car-moves — proving each hint strictly advances an
//      optimal path, the solver converges, and the 60k node cap never starves
//      a real 6x6 board (if it did, a hint would come back null mid-solve).
// ---------------------------------------------------------------------------

const _diffNames = ['EASY', 'MEDIUM', 'HARD'];

/// Slides [id] by [delta] on [cur], validating every single-cell step stays
/// in-bounds (the horizontal target may exit through the right wall) and never
/// collides. Returns null on success, else the reason the move is illegal.
String? _applyDelta(Map<int, Block> cur, int id, int delta, int rows, int cols) {
  final b0 = cur[id];
  if (b0 == null) return 'move references unknown block $id';
  if (delta == 0) return 'zero-delta hint (should be compressed out)';
  var b = b0;
  final step = delta > 0 ? 1 : -1;
  for (int k = 0; k < delta.abs(); k++) {
    final nb = b.moved(step);
    for (final (r, c) in nb.cells) {
      final exiting = b.isTarget && b.dir == BlockDir.horizontal && c >= cols;
      if (!exiting && (r < 0 || r >= rows || c < 0 || c >= cols)) {
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
  return null;
}

bool _escaped(Map<int, Block> cur, int cols) {
  final t = cur.values.firstWhere((x) => x.isTarget);
  return t.col + t.length >= cols;
}

void main() {
  // A spread of levels per difficulty incl. the densest HARD boards, where the
  // BFS does the most work and the node cap is most likely to bite.
  const sampleLevels = [1, 2, 17, 50, 137, 500, 1000];

  group('Block Escape hint solver', () {
    for (int diff = 0; diff < 3; diff++) {
      test('${_diffNames[diff]}: hint is legal, optimal-first, and solves greedily',
          () {
        for (final level in sampleLevels) {
          final eff = (level - 1) % beLevelsPerDifficulty + 1;
          final salt = beSaltFor(eff, diff);
          final cand = buildBlockEscapeCandidate(eff, diff, salt)!;
          final ctx = '${_diffNames[diff]} level $level';

          // (1)+(2) hint on the initial board == offline-optimal first move.
          final first = blockEscapeHintMove(cand.blocks, cand.rows, cand.cols);
          expect(first, isNotNull, reason: '$ctx: hint null on a solvable board');
          expect(first, cand.solution.first,
              reason: '$ctx: hint first move != offline optimal first move');

          // (3) greedily follow the hint to a win; must take exactly the
          // optimal number of car-moves.
          final cur = <int, Block>{for (final b in cand.blocks) b.id: b};
          int moves = 0;
          final cap = cand.solution.length * 3 + 6; // generous anti-hang guard
          while (!_escaped(cur, cand.cols)) {
            final hint = blockEscapeHintMove(cur.values.toList(), cand.rows, cand.cols);
            expect(hint, isNotNull,
                reason: '$ctx: hint went null mid-solve (node cap starved?)');
            final err = _applyDelta(cur, hint!.$1, hint.$2, cand.rows, cand.cols);
            expect(err, isNull, reason: '$ctx: illegal hint move — $err');
            moves++;
            expect(moves, lessThanOrEqualTo(cap),
                reason: '$ctx: greedy hint play did not converge');
          }
          expect(moves, cand.solution.length,
              reason: '$ctx: greedy hint play used $moves moves != optimal '
                  '${cand.solution.length}');
        }
      });
    }
  });
}
