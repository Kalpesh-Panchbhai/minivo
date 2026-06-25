import 'package:flutter_test/flutter_test.dart';

import 'package:minivo/games/block_escape/block_escape_level_gen.dart';
import 'package:minivo/games/block_escape/block_escape_seeds.g.dart';

// ---------------------------------------------------------------------------
// LOAD-TIME budget.
//
// Product requirement: a level must load (board fully reconstructed and ready
// to render) in well under 10ms so play starts instantly. The device path is
// generateBlockEscapeLevel -> buildBlockEscapeBoardOnly: a pure seeded
// reconstruction with NO solver run. (The old path re-ran a BFS at load and
// spiked to ~250ms — see git history.)
//
// The CI host is faster than a low-end phone, so we hold the per-level decode
// to a strict 2ms ceiling here. That leaves a comfortable margin even if a
// budget phone is ~4x slower than this host: 2ms * 4 = 8ms < 10ms.
// ---------------------------------------------------------------------------

void main() {
  const perLevelBudgetMs = 2.0;

  group('Block Escape load time', () {
    test('single-level decode stays under the budget across the table', () {
      // Warm up (JIT, lazy seed-table decode).
      for (int i = 0; i < 100; i++) {
        generateBlockEscapeLevel((i % beLevelsPerDifficulty) + 1, i % 3);
      }

      final worst = <String, double>{};
      double globalMax = 0;
      int over = 0;
      int n = 0;

      // Sample evenly across the whole table for every difficulty, including
      // the densest (HARD) boards and a wrapped index.
      final step = (beLevelsPerDifficulty / 400).ceil().clamp(1, 1 << 30);
      for (int diff = 0; diff < 3; diff++) {
        for (int level = 1;
            level <= beLevelsPerDifficulty + 5;
            level += step) {
          final sw = Stopwatch()..start();
          final p = generateBlockEscapeLevel(level, diff);
          sw.stop();
          // Touch the result so the call can't be optimised away.
          expect(p.blocks, isNotEmpty);
          final ms = sw.elapsedMicroseconds / 1000.0;
          globalMax = ms > globalMax ? ms : globalMax;
          if (ms > perLevelBudgetMs) over++;
          n++;
          final key = ['easy', 'medium', 'hard'][diff];
          if (ms > (worst[key] ?? 0)) worst[key] = ms;
        }
      }

      expect(
        over,
        0,
        reason: 'samples over ${perLevelBudgetMs}ms: $over / $n; '
            'worst per difficulty (ms): $worst; global max ${globalMax.toStringAsFixed(3)}ms',
      );
    });

    test('bulk decode of 3000 levels is fast (amortised)', () {
      // Simulates a player advancing quickly; the seed table is decoded once
      // and cached, every lookup after that is O(1) board reconstruction.
      final sw = Stopwatch()..start();
      int blocks = 0;
      for (int i = 0; i < 3000; i++) {
        final p = generateBlockEscapeLevel((i % beLevelsPerDifficulty) + 1, i % 3);
        blocks += p.blocks.length;
      }
      sw.stop();
      expect(blocks, greaterThan(0));
      final perCall = sw.elapsedMicroseconds / 1000.0 / 3000.0;
      expect(
        perCall,
        lessThan(perLevelBudgetMs),
        reason: 'amortised per-level decode ${perCall.toStringAsFixed(4)}ms '
            'exceeds ${perLevelBudgetMs}ms',
      );
    });

    test('baked solution length is present and positive for every sample', () {
      for (int diff = 0; diff < 3; diff++) {
        for (final level in const [1, 2, 137, 5000, 9999, 10000, 10001]) {
          final p = generateBlockEscapeLevel(level, diff);
          expect(p.solutionLength, greaterThan(0),
              reason: 'diff $diff level $level missing baked depth');
          expect(p.solution.length, p.solutionLength,
              reason: 'diff $diff level $level: solution list length != solutionLength');
        }
      }
    });
  });
}
