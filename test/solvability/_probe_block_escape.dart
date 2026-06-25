// TEMP PROBE — measures runtime load time + generator throughput.
// Deleted after measurement. Does NOT write the seed table.
import 'dart:math' as math;
import 'package:minivo/games/block_escape/block_escape_level_gen.dart';

void main() {
  // ---- 1. Runtime load time of generateBlockEscapeLevel (current path) ----
  // Warm up.
  for (int i = 0; i < 50; i++) {
    generateBlockEscapeLevel((i % 100) + 1, i % 3);
  }
  final List<double> times = [];
  for (int diff = 0; diff < 3; diff++) {
    for (int level = 1; level <= 100; level++) {
      final sw = Stopwatch()..start();
      generateBlockEscapeLevel(level, diff);
      sw.stop();
      times.add(sw.elapsedMicroseconds / 1000.0);
    }
  }
  times.sort();
  double pct(double p) => times[(times.length * p).floor().clamp(0, times.length - 1)];
  final maxT = times.last;
  final avgT = times.reduce((a, b) => a + b) / times.length;
  print('LOAD TIME (current runtime decode, 300 calls):');
  print('  avg=${avgT.toStringAsFixed(3)}ms  p50=${pct(0.5).toStringAsFixed(3)}ms  '
      'p95=${pct(0.95).toStringAsFixed(3)}ms  p99=${pct(0.99).toStringAsFixed(3)}ms  '
      'MAX=${maxT.toStringAsFixed(3)}ms');
  print('  >10ms count: ${times.where((t) => t > 10).length} / ${times.length}');

  // ---- 1b. Board-ONLY reconstruction time (proposed runtime hot path) ----
  // Find a valid salt per (level,diff), then time buildBlockEscapeBoardOnly.
  const maxSaltP = 8000;
  int minSolP(int d) => const [2, 5, 10][d];
  int maxSolP(int d) => const [8, 18, 40][d];
  final boardTimes = <double>[];
  for (int diff = 0; diff < 3; diff++) {
    for (int level = 1; level <= 40; level++) {
      int? goodSalt;
      int goodLen = 0;
      for (int s = 0; s <= maxSaltP; s++) {
        final r = generateBlockEscapeLevelWithSalt(level, diff, s);
        if (r == null) continue;
        if (countBlockEscapeSolutions(r, cap: 2) != 1) continue;
        final sl = r.solution.length;
        if (sl < minSolP(diff) || sl > maxSolP(diff)) continue;
        goodSalt = s;
        goodLen = sl;
        break;
      }
      if (goodSalt == null) continue;
      // warm + timed
      buildBlockEscapeBoardOnly(level, diff, goodSalt, goodLen);
      final sw = Stopwatch()..start();
      for (int rep = 0; rep < 20; rep++) {
        buildBlockEscapeBoardOnly(level, diff, goodSalt, goodLen);
      }
      sw.stop();
      boardTimes.add(sw.elapsedMicroseconds / 1000.0 / 20.0);
    }
  }
  boardTimes.sort();
  final bMax = boardTimes.last;
  final bAvg = boardTimes.reduce((a, b) => a + b) / boardTimes.length;
  print('BOARD-ONLY reconstruction (${boardTimes.length} levels, no BFS):');
  print('  avg=${bAvg.toStringAsFixed(4)}ms  MAX=${bMax.toStringAsFixed(4)}ms  '
      '>10ms count: ${boardTimes.where((t) => t > 10).length}');

  // ---- 2. Generator throughput (current bands) per difficulty ----
  const maxSalt = 8000;
  int minSol(int d) => const [2, 5, 10][d];
  int maxSol(int d) => const [8, 18, 40][d];
  for (int diff = 0; diff < 3; diff++) {
    final sw = Stopwatch()..start();
    int found = 0, saltsTried = 0;
    final solLens = <int>[];
    const sample = 40;
    for (int level = 1; level <= sample; level++) {
      for (int s = 0; s <= maxSalt; s++) {
        saltsTried++;
        final r = generateBlockEscapeLevelWithSalt(level, diff, s);
        if (r == null) continue;
        if (countBlockEscapeSolutions(r, cap: 2) != 1) continue;
        final sl = r.solution.length;
        if (sl < minSol(diff) || sl > maxSol(diff)) continue;
        found++;
        solLens.add(sl);
        break;
      }
    }
    sw.stop();
    final perLevel = sw.elapsedMilliseconds / sample;
    final est10k = perLevel * 10000 / 1000.0;
    solLens.sort();
    final meanSol = solLens.isEmpty ? 0 : solLens.reduce((a, b) => a + b) / solLens.length;
    print('GEN diff=$diff: found=$found/$sample  '
        '${perLevel.toStringAsFixed(1)}ms/level  '
        'avgSaltsTried=${(saltsTried / sample).toStringAsFixed(1)}  '
        'meanSolLen=${(meanSol as num).toStringAsFixed(1)}  '
        'solRange=[${solLens.isEmpty ? "-" : solLens.first}..${solLens.isEmpty ? "-" : solLens.last}]  '
        'est 10k single-thread=${est10k.toStringAsFixed(0)}s');
  }
  print('CPUs=${math.max(1, 1)} (isolates will divide gen time)');
}
