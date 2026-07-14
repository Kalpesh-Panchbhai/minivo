// Offline generator for the Frame Rush seed table.
//
// For every difficulty and every level 1..10000 it searches for the first salt
// that yields a level that is FAIR (exactly one alignment window per loop whose
// duration sits inside the difficulty's hittable band) AND whose layout is not
// already used by another level (cross-level uniqueness). The winning salts are
// packed into lib/games/frame_rush/frame_rush_seeds.g.dart, which the on-device
// generator replays — so no solver ever runs on a device.
//
// Run from the project root:
//   dart run test/solvability/generate_frame_rush_seeds.dart [levelsPerDifficulty]

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:minivo/games/frame_rush/frame_rush_level_gen.dart';

const int _maxSalt = 4000;

String signatureOf(FrameRushLevelResult r) => frameRushSignature(r);

/// First salt >= [startSalt] giving a fair level whose signature is not in
/// [taken]. Returns (salt, signature) or null if none within [_maxSalt].
(int, String)? findFairSalt(int level, int diffIdx,
    {int startSalt = 0, Set<String>? taken}) {
  for (int s = startSalt; s <= _maxSalt; s++) {
    final r = generateFrameRushLevelWithSalt(level, diffIdx, s);
    if (!frameRushIsFair(r)) continue;
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
    final res = findFairSalt(level, job.diffIdx);
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

  stdout.write('Generating $levels fair unique levels × 3 difficulties\n');
  stdout.write('Using $numIsolates isolates\n\n');

  final salts = List.generate(3, (_) => List<int>.filled(levels, 0));
  final fails = <String>[];

  for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
    final diffName = const ['EASY', 'MEDIUM', 'HARD'][diffIdx];
    final sigs = List<String?>.filled(levels, null);
    await runDifficulty(diffIdx, levels, numIsolates, salts[diffIdx], sigs);

    // Resolve cross-level signature collisions serially in level order.
    final seen = <String>{};
    int collisions = 0;
    for (int i = 0; i < levels; i++) {
      final level = i + 1;
      if (salts[diffIdx][i] < 0 || sigs[i] == null) {
        fails.add('$diffName level $level: no fair salt within $_maxSalt');
        continue;
      }
      if (seen.add(sigs[i]!)) continue;
      collisions++;
      final res = findFairSalt(level, diffIdx,
          startSalt: salts[diffIdx][i] + 1, taken: seen);
      if (res == null) {
        fails.add('$diffName level $level: no fair non-dup salt');
        continue;
      }
      salts[diffIdx][i] = res.$1;
      seen.add(res.$2);
    }
    stdout.write('  [$diffName] done — $collisions collision(s) resolved, '
        '${seen.length} unique signatures\n\n');
  }

  if (fails.isNotEmpty) {
    stdout.write('FAILURES (${fails.length}):\n');
    for (final f in fails.take(40)) {
      stdout.write('  $f\n');
    }
    stdout.write('Aborting — not writing seed table.\n');
    exit(1);
  }

  // Pack as 3 × Uint16 little-endian arrays.
  final bd = ByteData(3 * levels * 2);
  for (int d = 0; d < 3; d++) {
    for (int i = 0; i < levels; i++) {
      final s = salts[d][i];
      if (s > 0xFFFF) {
        stdout.write('Salt $s overflows Uint16 (d=$d level=${i + 1})\n');
        exit(1);
      }
      bd.setUint16((d * levels + i) * 2, s, Endian.little);
    }
  }
  final b64 = base64Encode(bd.buffer.asUint8List());

  final maxSalt = salts.expand((e) => e).reduce(math.max);
  final out = StringBuffer()
    ..writeln('// GENERATED FILE — do not edit by hand.')
    ..writeln('//')
    ..writeln('// Maps each Frame Rush level to the offline-verified salt that')
    ..writeln('// yields a level with exactly one alignment window (fair for its')
    ..writeln('// difficulty) and a layout unique across the difficulty.')
    ..writeln('// Regenerate with:')
    ..writeln('//   dart run test/solvability/generate_frame_rush_seeds.dart')
    ..writeln('//')
    ..writeln('// Levels: $levels per difficulty. Max salt: $maxSalt.')
    ..writeln('// Verified: every level single-window + fair + unique.')
    ..writeln()
    ..writeln("import 'dart:convert';")
    ..writeln("import 'dart:typed_data';")
    ..writeln()
    ..writeln('const int frameRushLevelsPerDifficulty = $levels;')
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
    ..writeln('  const n = frameRushLevelsPerDifficulty;')
    ..writeln('  c = List.generate(')
    ..writeln('    3,')
    ..writeln('    (d) => List<int>.generate(')
    ..writeln('        n, (i) => bd.getUint16((d * n + i) * 2, Endian.little)),')
    ..writeln('  );')
    ..writeln('  _cache = c;')
    ..writeln('  return c;')
    ..writeln('}')
    ..writeln()
    ..writeln('/// Verified-unique salt for a level (1-based) on a difficulty')
    ..writeln('/// (0=easy, 1=medium, 2=hard). Levels past the table wrap around.')
    ..writeln('int frameRushSaltFor(int level, int diffIndex) {')
    ..writeln('  final idx = (level - 1) % frameRushLevelsPerDifficulty;')
    ..writeln('  return _salts()[diffIndex][idx];')
    ..writeln('}');

  File('lib/games/frame_rush/frame_rush_seeds.g.dart')
      .writeAsStringSync(out.toString());

  sw.stop();
  stdout.write('Wrote lib/games/frame_rush/frame_rush_seeds.g.dart\n');
  stdout.write('Done in ${sw.elapsed}. Max salt used: $maxSalt\n');
}
