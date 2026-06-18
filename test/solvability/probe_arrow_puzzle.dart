// Per-shape coverage + depth probe — tells us which shapes pack 100% solid and
// what removal-depth they produce, so we prune un-packable shapes and set the
// difficulty bands.
//
//   dart run test/solvability/probe_arrow_puzzle.dart [levels] [saltScan]

import 'dart:io';

import 'package:minivo/games/arrow_puzzle/arrow_puzzle_level_gen.dart';

void main(List<String> args) {
  final levels = args.isNotEmpty ? int.parse(args[0]) : 400;
  final saltScan = args.length > 1 ? int.parse(args[1]) : 20;

  for (int diff = 0; diff < 3; diff++) {
    final name = const ['EASY', 'MEDIUM', 'HARD'][diff];
    stdout.write('\n=== $name ===\n');
    final builds = <String, int>{};
    final covered = <String, int>{};
    final depths = <String, List<int>>{};

    for (int level = 1; level <= levels; level++) {
      final shape = shapeForLevel(diff, level).name;
      for (int salt = 0; salt < saltScan; salt++) {
        final r = generateArrowLevelWithSalt(level, diff, salt);
        builds[shape] = (builds[shape] ?? 0) + 1;
        if (fullyCovered(r)) {
          covered[shape] = (covered[shape] ?? 0) + 1;
          final d = removalDepth(r.arrows);
          if (d >= 0) (depths[shape] ??= []).add(d);
        }
      }
    }

    final names = builds.keys.toList()..sort();
    for (final s in names) {
      final cov = (covered[s] ?? 0) / builds[s]! * 100;
      final ds = depths[s] ?? [];
      ds.sort();
      final dmin = ds.isEmpty ? 0 : ds.first;
      final dmed = ds.isEmpty ? 0 : ds[ds.length ~/ 2];
      final dmax = ds.isEmpty ? 0 : ds.last;
      stdout.write('  ${s.padRight(14)} cover ${cov.toStringAsFixed(0).padLeft(3)}%  '
          'depth $dmin/$dmed/$dmax (min/med/max)\n');
    }
  }
}
