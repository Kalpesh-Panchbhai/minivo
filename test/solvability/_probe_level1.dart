import 'package:minivo/games/block_escape/block_escape_level_gen.dart';
import 'package:minivo/games/block_escape/block_escape_seeds.g.dart';

void _dump(int level, int diff) {
  final name = const ['EASY', 'MEDIUM', 'HARD'][diff];
  final salt = beSaltFor(level, diff);
  final dev = generateBlockEscapeLevel(level, diff);
  final cand = buildBlockEscapeCandidate(level, diff, salt);

  print('=== $name level $level (salt=$salt) ===');
  print('rows=${dev.rows} cols=${dev.cols} exitRow=${dev.exitRow} '
      'solLen=${dev.solutionLength}');
  final t = dev.blocks.firstWhere((b) => b.isTarget);
  print('TARGET: row=${t.row} col=${t.col} len=${t.length} dir=${t.dir} '
      '-> target.row==exitRow? ${t.row == dev.exitRow}');
  for (final b in dev.blocks) {
    print('  block ${b.id}: row=${b.row} col=${b.col} len=${b.length} '
        'dir=${b.dir.name} target=${b.isTarget}');
  }
  print('candidate solvable+in-band? ${cand != null}');
  if (cand != null) {
    print('optimal solution (${cand.solution.length} moves): ${cand.solution}');
  }

  // ASCII grid: '.'=empty, 'R'=target, letters for others, '>' = exit gate row.
  final grid = List.generate(dev.rows, (_) => List.filled(dev.cols, '.'));
  for (final b in dev.blocks) {
    final ch = b.isTarget ? 'R' : String.fromCharCode(97 + b.id);
    for (final (r, c) in b.cells) {
      if (r >= 0 && r < dev.rows && c >= 0 && c < dev.cols) grid[r][c] = ch;
    }
  }
  for (int r = 0; r < dev.rows; r++) {
    final gate = r == dev.exitRow ? '  <== EXIT GATE' : '';
    print('  ${grid[r].join(' ')}$gate');
  }
  print('');
}

void main() {
  for (final lvl in [1, 2, 3]) {
    _dump(lvl, 0);
  }
  _dump(1, 1);
  _dump(1, 2);
}
