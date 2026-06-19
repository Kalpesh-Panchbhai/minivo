import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:minivo/games/queens_puzzle/queens_puzzle_level_gen.dart';
import 'package:minivo/games/queens_puzzle/queens_puzzle_difficulty.dart';

// Salts are scanned until a level lands in its target difficulty band. Hard
// (tier 3) puzzles are rare (~0.1% of unique-solution boards), so the budget is
// generous; the vast majority of levels resolve in far fewer than this.
const int _maxSalt = 200000;

// Each difficulty band requires an EXACT logical-solver tier so the gradient is
// strict: easy = forced singles only, medium = needs line/region locking, hard
// = needs subset/Hall reasoning. Every band is still strictly 1-solution and
// fully solvable by pure logic (no guessing).
int _targetTier(int diffIdx) => queensTargetTierFor(diffIdx);

String signatureOf(QueensPuzzleLevelResult r) {
  final regSigs = r.regions.map((reg) {
    final sorted = List<int>.from(reg)..sort();
    return sorted.join(',');
  }).toList()
    ..sort();
  return '${r.boardSize}|${r.queenCols.join(',')}|${regSigs.join('|')}';
}

// Finds the first salt whose puzzle for [level]/[diffIdx] is strictly
// 1-solution, lands in the target tier, and has a layout not already taken.
(int, String)? findBandedSalt(int level, int diffIdx,
    {int startSalt = 0, Set<String>? taken}) {
  final target = _targetTier(diffIdx);
  for (int s = startSalt; s <= _maxSalt; s++) {
    final r = generateQueensPuzzleLevelWithSalt(level, diffIdx, s);
    if (countQueensPuzzleSolutions(r, cap: 2) != 1) continue;
    if (gradeQueensPuzzle(r).tier != target) continue;
    final sig = signatureOf(r);
    if (taken != null && taken.contains(sig)) continue;
    return (s, sig);
  }
  return null;
}

class _Job {
  final SendPort port;
  final int diffIdx;
  final int startLevel;
  final int endLevel;
  _Job(this.port, this.diffIdx, this.startLevel, this.endLevel);
}

void _worker(_Job job) {
  for (int level = job.startLevel; level <= job.endLevel; level++) {
    final res = findBandedSalt(level, job.diffIdx);
    if (res == null) {
      job.port.send([level, -1, '']);
    } else {
      job.port.send([level, res.$1, res.$2]);
    }
  }
  job.port.send('done');
}

Future<void> runDifficulty(
  int diffIdx,
  int levels,
  int numIsolates,
  List<int> saltsOut,
  List<String?> sigsOut,
) async {
  final chunk = (levels / numIsolates).ceil();
  final ports = <ReceivePort>[];
  for (int i = 0; i < numIsolates; i++) {
    final start = i * chunk + 1;
    final end = math.min((i + 1) * chunk, levels);
    if (start > levels) break;
    final rp = ReceivePort();
    ports.add(rp);
    await Isolate.spawn(_worker, _Job(rp.sendPort, diffIdx, start, end));
  }

  final controller = StreamController<dynamic>();
  for (final rp in ports) {
    rp.listen(controller.add);
  }

  int done = 0, doneLevels = 0;
  final diffName = const ['EASY', 'MEDIUM', 'HARD'][diffIdx];
  await for (final msg in controller.stream) {
    if (msg == 'done') {
      if (++done == ports.length) break;
      continue;
    }
    final data = msg as List<dynamic>;
    final level = data[0] as int;
    saltsOut[level - 1] = data[1] as int;
    sigsOut[level - 1] = (data[2] as String).isEmpty ? null : data[2] as String;
    doneLevels++;
    if (doneLevels % 250 == 0 || doneLevels == levels) {
      stdout.write('\r  [$diffName] $doneLevels / $levels');
    }
  }
  stdout.write('\n');
  for (final rp in ports) {
    rp.close();
  }
  await controller.close();
}

void main(List<String> args) async {
  final levels = args.isNotEmpty ? int.parse(args[0]) : 10000;
  // Second arg = "dry": measure fill/timing without overwriting the seed table.
  final dryRun = args.length > 1 && args[1] == 'dry';
  final numIsolates = Platform.numberOfProcessors.clamp(2, 16);
  final sw = Stopwatch()..start();

  stdout.write('Generating $levels banded Queens Puzzle levels × 3 difficulties'
      '${dryRun ? ' (DRY RUN)' : ''}\n');
  stdout.write('Bands: easy=tier1(forced) medium=tier2(locking) '
      'hard=tier3(subset/Hall). Using $numIsolates isolates.\n\n');

  final salts = List.generate(3, (_) => List<int>.filled(levels, 0));
  final maxSaltSeen = List<int>.filled(3, 0);
  final fails = <String>[];

  for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
    final diffName = const ['EASY', 'MEDIUM', 'HARD'][diffIdx];
    final sigs = List<String?>.filled(levels, null);
    final dsw = Stopwatch()..start();
    await runDifficulty(diffIdx, levels, numIsolates, salts[diffIdx], sigs);
    dsw.stop();

    final seen = <String>{};
    int collisions = 0;
    for (int i = 0; i < levels; i++) {
      final level = i + 1;
      if (salts[diffIdx][i] < 0 || sigs[i] == null) {
        fails.add('$diffName level $level: no banded salt within $_maxSalt');
        continue;
      }
      if (seen.add(sigs[i]!)) continue;
      collisions++;
      final res = findBandedSalt(level, diffIdx,
          startSalt: salts[diffIdx][i] + 1, taken: seen);
      if (res == null) {
        fails.add('$diffName level $level: no banded non-dup salt');
        continue;
      }
      salts[diffIdx][i] = res.$1;
      seen.add(res.$2);
    }
    for (final s in salts[diffIdx]) {
      if (s > maxSaltSeen[diffIdx]) maxSaltSeen[diffIdx] = s;
    }
    stdout.write('  [$diffName] done in ${dsw.elapsed} — $collisions collision(s) '
        'resolved, ${seen.length} unique, max salt ${maxSaltSeen[diffIdx]}\n\n');
  }

  if (fails.isNotEmpty) {
    stdout.write('FAILURES (${fails.length}):\n');
    for (final f in fails.take(40)) {
      stdout.write('  $f\n');
    }
    stdout.write('Aborting — not writing seed table.\n');
    exit(1);
  }

  final maxSalt = salts.expand((e) => e).reduce(math.max);
  sw.stop();

  if (dryRun) {
    stdout.write('DRY RUN ok — all bands filled. Max salt $maxSalt. '
        'Total ${sw.elapsed}.\n');
    return;
  }

  // Pack salts as little-endian Uint32 (band tier search can push salts past
  // the old Uint16 ceiling on rare hard levels).
  final bd = ByteData(3 * levels * 4);
  for (int d = 0; d < 3; d++) {
    for (int i = 0; i < levels; i++) {
      bd.setUint32((d * levels + i) * 4, salts[d][i], Endian.little);
    }
  }
  final b64 = base64Encode(bd.buffer.asUint8List());

  final out = StringBuffer()
    ..writeln('// GENERATED FILE — do not edit by hand.')
    ..writeln('//')
    ..writeln('// Maps each Queens Puzzle level to the offline-verified salt that yields a')
    ..writeln('// puzzle with exactly one solution, a layout unique across the difficulty,')
    ..writeln('// and a logical-solver tier matching its difficulty band:')
    ..writeln('//   easy   = tier 1 (forced singles only)')
    ..writeln('//   medium = tier 2 (needs line/region locking)')
    ..writeln('//   hard   = tier 3 (needs subset/Hall reasoning)')
    ..writeln('// Every band is fully solvable by pure logic — never guessing.')
    ..writeln('//')
    ..writeln('// Regenerate with:')
    ..writeln('//   dart run test/solvability/generate_queens_puzzle_seeds.dart')
    ..writeln('//')
    ..writeln('// Levels: $levels per difficulty. Max salt: $maxSalt.')
    ..writeln()
    ..writeln("import 'dart:convert';")
    ..writeln("import 'dart:typed_data';")
    ..writeln()
    ..writeln('const int queensPuzzleLevelsPerDifficulty = $levels;')
    ..writeln()
    ..writeln('const String _packed =')
    ..writeln("    '$b64';")
    ..writeln()
    ..writeln('List<List<int>>? _cache;')
    ..writeln()
    ..writeln('List<List<int>> _salts() {')
    ..writeln('  var c = _cache;')
    ..writeln('  if (c != null) return c;')
    ..writeln('  final bd = ByteData.sublistView(base64Decode(_packed));')
    ..writeln('  const n = queensPuzzleLevelsPerDifficulty;')
    ..writeln('  c = List.generate(')
    ..writeln('    3,')
    ..writeln('    (d) => List<int>.generate(')
    ..writeln('        n, (i) => bd.getUint32((d * n + i) * 4, Endian.little)),')
    ..writeln('  );')
    ..writeln('  _cache = c;')
    ..writeln('  return c;')
    ..writeln('}')
    ..writeln()
    ..writeln('/// Verified-banded salt for a level (1-based) on a difficulty')
    ..writeln('/// (0=easy, 1=medium, 2=hard). Levels past the table wrap around.')
    ..writeln('int queensPuzzleSaltFor(int level, int diffIndex) {')
    ..writeln('  final idx = (level - 1) % queensPuzzleLevelsPerDifficulty;')
    ..writeln('  return _salts()[diffIndex][idx];')
    ..writeln('}');

  File('lib/games/queens_puzzle/queens_puzzle_seeds.g.dart').writeAsStringSync(out.toString());

  stdout.write('Wrote lib/games/queens_puzzle/queens_puzzle_seeds.g.dart\n');
  stdout.write('Done in ${sw.elapsed}. Max salt used: $maxSalt '
      '(easy ${maxSaltSeen[0]}, medium ${maxSaltSeen[1]}, hard ${maxSaltSeen[2]})\n');
}
