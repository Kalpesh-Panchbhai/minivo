import 'package:flutter_test/flutter_test.dart';

import 'package:minivo/games/zip/zip_level_gen.dart';
import 'package:minivo/games/water_sort/water_sort_level_gen.dart';
import 'package:minivo/games/arrow_puzzle/arrow_puzzle_level_gen.dart';

// ---------------------------------------------------------------------------
// PERFORMANCE budget for level generation.
//
// The three level-scaled games generate a fresh board synchronously on the
// build path every time the player taps Play or advances a level. On device
// this is the ONLY heavy work between "tap" and "see the board", so it must
// stay cheap even at the densest level and after the 10k wrap-around (which
// still maps to a real puzzle). A regression that reintroduces an on-device
// solver / unbounded search would make level-start visibly janky — these
// budgets fail fast if generation slows down.
//
// Budgets are generous (CI machines vary) but far below anything a user would
// perceive as a hitch (~16ms/frame). They guard the ORDER OF MAGNITUDE, not
// micro-timings.
// ---------------------------------------------------------------------------

/// Returns average microseconds per call over [iterations] runs.
double _avgMicros(int iterations, void Function() body) {
  // Warm up (JIT, lazy seed-table access) so we measure steady state.
  for (int i = 0; i < 5; i++) {
    body();
  }
  final sw = Stopwatch()..start();
  for (int i = 0; i < iterations; i++) {
    body();
  }
  sw.stop();
  return sw.elapsedMicroseconds / iterations;
}

void main() {
  const budgetMicros = 8000; // 8ms/level — half a frame; comfortably fast.

  group('Zip level generation budget', () {
    for (int diff = 0; diff < 3; diff++) {
      test('diff $diff dense + wrapped levels generate under budget', () {
        // Densest reachable + a wrapped high level (worst realistic inputs).
        for (final level in const [13, 100, 9999, 25013]) {
          final avg = _avgMicros(200, () => generateZipLevel(level, diff));
          expect(avg, lessThan(budgetMicros),
              reason: 'zip diff=$diff level=$level avg=${avg.toStringAsFixed(0)}us');
        }
        // Sanity: hard reaches the 9x9 max grid.
        expect(generateZipLevel(13, 2).gridSize, 9);
      });
    }
  });

  group('Water Sort level generation budget', () {
    for (int diff = 0; diff < 3; diff++) {
      test('diff $diff dense + wrapped levels generate under budget', () {
        for (final level in const [11, 100, 9999, 25011]) {
          final avg = _avgMicros(200, () => generateWaterSortLevel(level, diff));
          expect(avg, lessThan(budgetMicros),
              reason:
                  'water_sort diff=$diff level=$level avg=${avg.toStringAsFixed(0)}us');
        }
        // Sanity: hard maxes at 14 colours / capacity 5.
        final p = generateWaterSortLevel(11, 2).params;
        expect(p.numColors, 14);
        expect(p.tubeCapacity, 5);
      });
    }
  });

  group('Arrow Puzzle level generation budget', () {
    for (int diff = 0; diff < 3; diff++) {
      test('diff $diff dense + wrapped levels generate under budget', () {
        for (final level in const [19, 8365, 9999, 28365]) {
          final avg = _avgMicros(100, () => generateArrowLevel(level, diff));
          expect(avg, lessThan(budgetMicros),
              reason:
                  'arrow_puzzle diff=$diff level=$level avg=${avg.toStringAsFixed(0)}us');
        }
        // Sanity: hard reaches the 12x13 max bounding box.
        final r = generateArrowLevel(8365, 2);
        expect(r.gridCols, 12);
        expect(r.gridRows, 13);
      });
    }
  });
}
