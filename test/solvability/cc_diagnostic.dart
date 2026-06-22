import 'dart:math' as math;
import 'package:minivo/games/color_connect/color_connect_level_gen.dart';

void main() {
  final configs = [
    [7, 7, 10], [7, 7, 11], [7, 7, 12],
    [8, 8, 10], [8, 8, 11], [8, 8, 12], [8, 8, 13], [8, 8, 14],
    [9, 9, 14], [9, 9, 16], [9, 9, 18], [9, 9, 20],
  ];
  for (final cfg in configs) {
    final rows = cfg[0], cols = cfg[1], flows = cfg[2];
    int generated = 0, unique = 0, multi = 0;
    final rng = math.Random(42);
    final dSw = Stopwatch()..start();
    for (int i = 0; i < 200; i++) {
      final p = buildColorConnectPuzzle(rows, cols, flows, rng);
      if (p == null) continue;
      generated++;
      final s = countColorConnectSolutions(p, cap: 2, nodeLimit: 4000000);
      if (s == 1) unique++;
      else if (s >= 2) multi++;
    }
    dSw.stop();
    final yieldPct = generated > 0 ? (unique * 100 ~/ generated) : 0;
    print('${rows}x${cols} ${flows}f: $generated gen, $unique uniq ($yieldPct%), '
        '$multi multi, ${dSw.elapsedMilliseconds}ms');
  }
}
