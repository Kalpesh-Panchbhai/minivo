import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:minivo/games/block_escape/block_escape_level_gen.dart';

const int _maxSalt = 8000;

/// First salt (>= [startSalt]) that yields a solvable, in-band, layout-unique
/// puzzle. [buildBlockEscapeCandidate] already runs the BFS solver and enforces
/// the move-count band, returning null otherwise — so a non-null result is
/// guaranteed solvable and in-band; we only additionally reject layouts whose
/// signature is already [taken]. Returns (salt, signature, optimalSolLen).
(int, String, int)? findUniqueSalt(int level, int diffIdx,
    {int startSalt = 0, Set<String>? taken}) {
  for (int s = startSalt; s <= _maxSalt; s++) {
    final r = generateBlockEscapeLevelWithSalt(level, diffIdx, s);
    if (r == null) continue;
    final sig = beSignature(r);
    if (taken != null && taken.contains(sig)) continue;
    return (s, sig, r.solution.length);
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
    final res = findUniqueSalt(level, job.diffIdx);
    if (res == null) {
      job.port.send([level, -1, '', 0]);
    } else {
      job.port.send([level, res.$1, res.$2, res.$3]);
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
  List<int> solLensOut,
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
    solLensOut[level - 1] = data[3] as int;
    doneLevels++;
    if (doneLevels % 500 == 0 || doneLevels == levels) {
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
  final numIsolates = Platform.numberOfProcessors.clamp(2, 16);
  final sw = Stopwatch()..start();

  stdout.write('Generating $levels unique-solution Block Escape levels × 3 difficulties\n');
  stdout.write('Using $numIsolates isolates\n\n');

  final salts = List.generate(3, (_) => List<int>.filled(levels, 0));
  final solLens = List.generate(3, (_) => List<int>.filled(levels, 0));
  final fails = <String>[];

  for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
    final diffName = const ['EASY', 'MEDIUM', 'HARD'][diffIdx];
    final sigs = List<String?>.filled(levels, null);
    await runDifficulty(
        diffIdx, levels, numIsolates, salts[diffIdx], sigs, solLens[diffIdx]);

    final seen = <String>{};
    int collisions = 0;
    for (int i = 0; i < levels; i++) {
      final level = i + 1;
      if (salts[diffIdx][i] < 0 || sigs[i] == null) {
        fails.add('$diffName level $level: no unique salt within $_maxSalt');
        continue;
      }
      if (seen.add(sigs[i]!)) continue;
      collisions++;
      final res = findUniqueSalt(level, diffIdx,
          startSalt: salts[diffIdx][i] + 1, taken: seen);
      if (res == null) {
        fails.add('$diffName level $level: no unique non-dup salt');
        continue;
      }
      salts[diffIdx][i] = res.$1;
      solLens[diffIdx][i] = res.$3;
      seen.add(res.$2);
    }

    // Difficulty-band sanity over the final, collision-resolved set.
    final lens = solLens[diffIdx];
    final minLen = lens.reduce(math.min);
    final maxLen = lens.reduce(math.max);
    final meanLen = lens.reduce((a, b) => a + b) / levels;
    stdout.write('  [$diffName] done — $collisions collision(s) resolved, '
        '${seen.length} unique signatures\n');
    stdout.write('  [$diffName] solLen min=$minLen max=$maxLen '
        'mean=${meanLen.toStringAsFixed(2)}\n\n');
  }

  if (fails.isNotEmpty) {
    stdout.write('FAILURES (${fails.length}):\n');
    for (final f in fails.take(40)) {
      stdout.write('  $f\n');
    }
    stdout.write('Aborting — not writing seed table.\n');
    exit(1);
  }

  // Salts -> Uint16 little-endian; solution lengths -> Uint8 (depth <= 255).
  final saltBd = ByteData(3 * levels * 2);
  final lenBytes = Uint8List(3 * levels);
  for (int d = 0; d < 3; d++) {
    for (int i = 0; i < levels; i++) {
      final s = salts[d][i];
      if (s > 0xFFFF) {
        stdout.write('Salt $s overflows Uint16 (d=$d level=${i + 1})\n');
        exit(1);
      }
      saltBd.setUint16((d * levels + i) * 2, s, Endian.little);
      final len = solLens[d][i];
      if (len < 1 || len > 0xFF) {
        stdout.write('solLen $len out of Uint8 range (d=$d level=${i + 1})\n');
        exit(1);
      }
      lenBytes[d * levels + i] = len;
    }
  }
  final saltB64 = base64Encode(saltBd.buffer.asUint8List());
  final lenB64 = base64Encode(lenBytes);

  final maxSalt = salts.expand((e) => e).reduce(math.max);
  final maxLen = solLens.expand((e) => e).reduce(math.max);
  final out = StringBuffer()
    ..writeln('// GENERATED FILE — do not edit by hand.')
    ..writeln('//')
    ..writeln('// Maps each Block Escape level to the offline-verified salt that')
    ..writeln('// yields a solvable puzzle with a layout unique across the')
    ..writeln('// difficulty, plus the optimal solution length (puzzle depth).')
    ..writeln('// The device rebuilds the board from the salt WITHOUT running the')
    ..writeln('// solver (see buildBlockEscapeBoardOnly) — pure, instant decode.')
    ..writeln('// Regenerate with:')
    ..writeln('//   dart run test/solvability/generate_block_escape_seeds.dart')
    ..writeln('//')
    ..writeln('// Levels: $levels per difficulty. Max salt: $maxSalt. Max depth: $maxLen.')
    ..writeln('// Verified offline: every level solvable + layout-unique + in band.')
    ..writeln()
    ..writeln("import 'dart:convert';")
    ..writeln("import 'dart:typed_data';")
    ..writeln()
    ..writeln('const int beLevelsPerDifficulty = $levels;')
    ..writeln()
    ..writeln('const String _packedSalts =')
    ..writeln("    '$saltB64';")
    ..writeln()
    ..writeln('const String _packedLens =')
    ..writeln("    '$lenB64';")
    ..writeln()
    ..writeln('List<List<int>>? _saltCache;')
    ..writeln('List<List<int>>? _lenCache;')
    ..writeln()
    ..writeln('List<List<int>> _salts() {')
    ..writeln('  var c = _saltCache;')
    ..writeln('  if (c != null) return c;')
    ..writeln('  final bd = ByteData.sublistView(base64Decode(_packedSalts));')
    ..writeln('  const n = beLevelsPerDifficulty;')
    ..writeln('  c = List.generate(')
    ..writeln('    3,')
    ..writeln('    (d) => List<int>.generate(')
    ..writeln('        n, (i) => bd.getUint16((d * n + i) * 2, Endian.little)),')
    ..writeln('  );')
    ..writeln('  _saltCache = c;')
    ..writeln('  return c;')
    ..writeln('}')
    ..writeln()
    ..writeln('List<List<int>> _lens() {')
    ..writeln('  var c = _lenCache;')
    ..writeln('  if (c != null) return c;')
    ..writeln('  final b = base64Decode(_packedLens);')
    ..writeln('  const n = beLevelsPerDifficulty;')
    ..writeln('  c = List.generate(')
    ..writeln('    3,')
    ..writeln('    (d) => List<int>.generate(n, (i) => b[d * n + i]),')
    ..writeln('  );')
    ..writeln('  _lenCache = c;')
    ..writeln('  return c;')
    ..writeln('}')
    ..writeln()
    ..writeln('int beSaltFor(int level, int diffIndex) {')
    ..writeln('  final idx = (level - 1) % beLevelsPerDifficulty;')
    ..writeln('  return _salts()[diffIndex][idx];')
    ..writeln('}')
    ..writeln()
    ..writeln('int beSolLenFor(int level, int diffIndex) {')
    ..writeln('  final idx = (level - 1) % beLevelsPerDifficulty;')
    ..writeln('  return _lens()[diffIndex][idx];')
    ..writeln('}');

  File('lib/games/block_escape/block_escape_seeds.g.dart')
      .writeAsStringSync(out.toString());

  sw.stop();
  stdout.write('Wrote lib/games/block_escape/block_escape_seeds.g.dart\n');
  stdout.write('Done in ${sw.elapsed}. Max salt: $maxSalt. Max depth: $maxLen\n');
}
