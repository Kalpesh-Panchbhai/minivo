// Probe Water Sort: solvable-yield (fraction of random salts that are solvable
// with the 2 free empties) + solver speed, so the offline gen is feasible.
//
//   dart run test/solvability/probe_water_sort.dart [saltScan]

import 'dart:io';

import 'package:minivo/games/water_sort/water_sort_level_gen.dart';

void main(List<String> args) {
  final scan = args.isNotEmpty ? int.parse(args[0]) : 300;
  const probeLevels = [1, 30, 100, 1000];

  for (int diff = 0; diff < 3; diff++) {
    final name = const ['EASY', 'MEDIUM', 'HARD'][diff];
    stdout.write('\n=== $name ===\n');
    for (final level in probeLevels) {
      final colors = colorsForLevel(diff, level);
      final cap = capForLevel(diff, level);
      int solv = 0, firstSalt = -1;
      final sw = Stopwatch()..start();
      for (int salt = 0; salt < scan; salt++) {
        final r = generateWaterSortLevelWithSalt(level, diff, salt);
        if (meetsWaterSortBand(r)) {
          solv++;
          if (firstSalt < 0) firstSalt = salt;
        }
      }
      sw.stop();
      stdout.write('  L$level: $colors colors cap $cap — solvable '
          '${(solv / scan * 100).toStringAsFixed(0)}% (first salt $firstSalt), '
          '${(sw.elapsedMilliseconds / scan).toStringAsFixed(1)} ms/candidate\n');
    }
  }
}
