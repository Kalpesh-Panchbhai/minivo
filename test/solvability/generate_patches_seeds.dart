import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:minivo/games/patches/patches_level_gen.dart';

const _defaultLevels = 10000;

const _diffNames = ['EASY', 'MEDIUM', 'HARD'];

class _Job {
  final SendPort port;
  final int diff;
  final int seed;
  _Job(this.port, this.diff, this.seed);
}

void _worker(_Job job) {
  final rng = math.Random(job.seed);
  while (true) {
    final p = buildPatchesPuzzle(job.diff, rng);
    if (p == null) continue;
    job.port.send([patchesSignature(p), patchesEncodeLevel(p)]);
  }
}

Future<List<Uint8List>> generateDifficulty(
    int diff, int levels, int numIsolates) async {
  final unique = <String, Uint8List>{};
  final isolates = <Isolate>[];
  final ports = <ReceivePort>[];
  final controller = StreamController<dynamic>();

  for (int i = 0; i < numIsolates; i++) {
    final rp = ReceivePort();
    ports.add(rp);
    rp.listen(controller.add);
    final seed = 0x5DEECE6 + diff * 1000003 + i * 2654435761;
    isolates.add(await Isolate.spawn(
        _worker, _Job(rp.sendPort, diff, seed & 0x3FFFFFFF)));
  }

  final name = _diffNames[diff];
  final sw = Stopwatch()..start();
  int received = 0, sinceNew = 0;
  const maxStall = 400000;
  const maxSeconds = 1800;

  await for (final msg in controller.stream) {
    received++;
    final data = msg as List<dynamic>;
    final sig = data[0] as String;
    final before = unique.length;
    unique[sig] = data[1] as Uint8List;
    if (unique.length > before) {
      sinceNew = 0;
    } else {
      sinceNew++;
    }
    if (unique.length % 500 == 0 && unique.length > before) {
      stdout.write('\r  [$name] ${unique.length} / $levels unique '
          '($received produced, ${sw.elapsed.inSeconds}s)   ');
    }
    if (unique.length >= levels) break;
    if (sinceNew >= maxStall) {
      stdout.write('\n  [$name] STALLED: only ${unique.length} unique '
          'reachable ($received produced).\n');
      break;
    }
    if (sw.elapsed.inSeconds >= maxSeconds) {
      stdout.write('\n  [$name] TIMEOUT after ${maxSeconds}s with '
          '${unique.length} unique.\n');
      break;
    }
  }
  stdout.write('\r  [$name] ${unique.length} / $levels unique '
      '($received produced, ${sw.elapsed.inSeconds}s)        \n');

  for (final iso in isolates) {
    iso.kill(priority: Isolate.immediate);
  }
  for (final rp in ports) {
    rp.close();
  }
  await controller.close();

  return unique.values.take(levels).toList();
}

void main(List<String> args) async {
  final levels = args.isNotEmpty ? int.parse(args[0]) : _defaultLevels;
  final numIsolates = Platform.numberOfProcessors.clamp(2, 16);
  final sw = Stopwatch()..start();

  stdout.write('Generating $levels Patches puzzles x 3 difficulties '
      '($numIsolates isolates)\n');
  stdout.write('Grid sizes: Easy 5x5, Medium 7x7, Hard 9x9.\n\n');

  final perDiff = <List<Uint8List>>[];
  for (int diff = 0; diff < 3; diff++) {
    final records = await generateDifficulty(diff, levels, numIsolates);
    if (records.length < levels) {
      stdout.write('\nFAILED: ${_diffNames[diff]} produced only '
          '${records.length}/$levels. Aborting.\n');
      exit(1);
    }
    perDiff.add(records);
  }

  stdout.write('\nVerifying decode round-trip + uniqueness + difficulty...\n');
  for (int diff = 0; diff < 3; diff++) {
    final rows = patchesRows(diff);
    final cols = patchesCols(diff);
    final stride = patchesStrideBytes(rows, cols);
    final sigs = <String>{};
    int bad = 0;
    final toughHist = <int, int>{};
    for (int i = 0; i < levels; i++) {
      final rec = perDiff[diff][i];
      if (rec.length != stride) {
        bad++;
        continue;
      }
      final p = patchesDecodeLevel(rows, cols, rec);
      if (!sigs.add(patchesSignature(p))) bad++;
      // Sample the (expensive) solver checks; every level passed these at
      // build time, this just guards the encode/decode round-trip.
      if (i % 50 == 0) {
        final t = patchesToughness(p);
        toughHist[t] = (toughHist[t] ?? 0) + 1;
        if (countPatchesSolutions(p, cap: 2) != 1) bad++;
        // Single solution under the real (hidden-number) game mechanics.
        if (!patchesPlayerSolvable(p, diff)) bad++;
        // Difficulty band sanity.
        final inBand = diff == 0
            ? t == 0
            : diff == 1
                ? (t >= 1 && t <= 4)
                : t >= 5;
        if (!inBand) bad++;
      }
    }
    final tk = toughHist.keys.toList()..sort();
    stdout.write('  [${_diffNames[diff]}] ${sigs.length} unique, '
        '$bad problems, toughness(sampled) '
        '${tk.map((t) => "$t:${toughHist[t]}").join(" ")}\n');
    if (bad > 0 || sigs.length != levels) {
      stdout.write('FAILED verification for ${_diffNames[diff]}.\n');
      exit(1);
    }
  }

  final packed = <String>[];
  for (int diff = 0; diff < 3; diff++) {
    final rows = patchesRows(diff);
    final cols = patchesCols(diff);
    final stride = patchesStrideBytes(rows, cols);
    final buf = Uint8List(stride * levels);
    for (int i = 0; i < levels; i++) {
      buf.setRange(i * stride, (i + 1) * stride, perDiff[diff][i]);
    }
    packed.add(base64Encode(buf));
  }

  final out = StringBuffer()
    ..writeln('// GENERATED FILE — do not edit by hand.')
    ..writeln('//')
    ..writeln('// $levels unique, solvable Patches puzzles per difficulty,')
    ..writeln('// packed as bitmaps (clues 5-bit + solution 8-bit per cell).')
    ..writeln('//')
    ..writeln('// Grids: Easy 5x5, Medium 7x7, Hard 9x9.')
    ..writeln('// Every puzzle has exactly one solution.')
    ..writeln('//')
    ..writeln('// Regenerate with:')
    ..writeln('//   dart run test/solvability/generate_patches_seeds.dart')
    ..writeln()
    ..writeln('const int patchesLevelsPerDifficulty = $levels;')
    ..writeln()
    ..writeln('const List<String> patchesPacked = [');
  for (final s in packed) {
    out.writeln("  '$s',");
  }
  out.writeln('];');

  File('lib/games/patches/patches_seeds.g.dart').writeAsStringSync(out.toString());
  sw.stop();
  stdout.write('\nWrote lib/games/patches/patches_seeds.g.dart in ${sw.elapsed}.\n');
}
