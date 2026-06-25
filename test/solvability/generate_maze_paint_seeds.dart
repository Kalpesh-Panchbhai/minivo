// Offline generator for the Maze Paint seed table.
//
// Spawns parallel isolates that draw random irregular mazes, keep only those
// that are STRICTLY solvable (exactly one irredundant route) AND land in the
// difficulty's toughness band, then dedups by signature until 10k unique levels
// per difficulty are collected. The verified levels are bit-packed into
// lib/games/maze_paint/maze_paint_seeds.g.dart, which the device only decodes —
// no solver ever runs on a device.
//
// Run from the project root:
//   dart run test/solvability/generate_maze_paint_seeds.dart [levelsPerDifficulty]

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:minivo/games/maze_paint/maze_paint_level_gen.dart';

const _defaultLevels = 10000;
const _diffNames = ['EASY', 'MEDIUM', 'HARD'];

class _Record {
  final String sig;
  final Uint8List bytes;
  _Record(this.sig, this.bytes);
}

class _Job {
  final SendPort port;
  final int diff;
  final int seed;
  _Job(this.port, this.diff, this.seed);
}

void _worker(_Job job) {
  final rng = math.Random(job.seed);
  while (true) {
    final lvl = buildMazePaintCandidate(job.diff, rng);
    if (lvl == null) continue;
    job.port.send([mpSignature(lvl), Uint8List.fromList(mpEncodeLevel(lvl))]);
  }
}

Future<List<_Record>> _generateDifficulty(
    int diff, int levels, int numIsolates) async {
  final unique = <String, _Record>{};
  final isolates = <Isolate>[];
  final ports = <ReceivePort>[];
  final controller = StreamController<dynamic>();

  for (int i = 0; i < numIsolates; i++) {
    final rp = ReceivePort();
    ports.add(rp);
    rp.listen(controller.add);
    final seed = 0x4A2E + diff * 1000003 + i * 2654435761;
    isolates.add(
        await Isolate.spawn(_worker, _Job(rp.sendPort, diff, seed & 0x3FFFFFFF)));
  }

  final name = _diffNames[diff];
  final sw = Stopwatch()..start();
  int received = 0, sinceNew = 0;
  const maxStall = 2000000;
  const maxSeconds = 5400;

  await for (final msg in controller.stream) {
    received++;
    final data = msg as List<dynamic>;
    final sig = data[0] as String;
    final before = unique.length;
    unique[sig] = _Record(sig, data[1] as Uint8List);
    if (unique.length > before) {
      sinceNew = 0;
    } else {
      sinceNew++;
    }
    if (unique.length % 500 == 0 && unique.length > before) {
      stdout.write('\r  [$name] ${unique.length} / $levels unique '
          '($received produced, ${sw.elapsed.inSeconds}s)        ');
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

  stdout.write('Generating $levels unique-solution Maze Paint levels x 3 '
      'difficulties ($numIsolates isolates)\n');
  stdout.write('Boxes: Easy ${mpRows(0)}x${mpCols(0)}, '
      'Medium ${mpRows(1)}x${mpCols(1)}, Hard ${mpRows(2)}x${mpCols(2)}.\n');
  stdout.write('Toughness bands: '
      'Easy [${mpToughnessMin[0]}, ${mpToughnessMax[0]}], '
      'Medium [${mpToughnessMin[1]}, ${mpToughnessMax[1]}], '
      'Hard [${mpToughnessMin[2]}, inf).\n\n');

  final perDiff = <List<_Record>>[];
  for (int diff = 0; diff < 3; diff++) {
    final records = await _generateDifficulty(diff, levels, numIsolates);
    if (records.length < levels) {
      stdout.write('\nFAILED: ${_diffNames[diff]} produced only '
          '${records.length}/$levels. Aborting.\n');
      exit(1);
    }
    perDiff.add(records);
  }

  stdout.write('\nVerifying decode round-trip + uniqueness + bands + '
      'sampled solvability...\n');
  for (int diff = 0; diff < 3; diff++) {
    final rows = mpRows(diff), cols = mpCols(diff);
    final sigs = <String>{};
    int bad = 0;
    final tough = <int>[];
    final solLen = <int>[];
    for (int i = 0; i < levels; i++) {
      final p = mpDecodeLevel(rows, cols, perDiff[diff][i].bytes);
      if (!sigs.add(mpSignature(p))) bad++;
      final t = mpToughness(p);
      tough.add(t);
      solLen.add(p.solution.length);
      if (!mpToughnessOk(diff, t)) bad++;
      if (mpReplay(p).length != p.paintableCount) bad++;
      if (i % 200 == 0) {
        if (countMazePaintSolutions(p, cap: 2) != 1) bad++;
      }
    }
    tough.sort();
    final mean = tough.reduce((a, b) => a + b) / tough.length;
    solLen.sort();
    stdout.write('  [${_diffNames[diff]}] ${sigs.length} unique, $bad problems '
        '| toughness mean=${mean.toStringAsFixed(2)} '
        'p50=${tough[tough.length ~/ 2]} '
        'p90=${tough[(tough.length * 9) ~/ 10]} max=${tough.last} '
        '| solLen mean=${(solLen.reduce((a, b) => a + b) / solLen.length).toStringAsFixed(1)} '
        'max=${solLen.last}\n');
    if (bad > 0 || sigs.length != levels) {
      stdout.write('FAILED verification for ${_diffNames[diff]}.\n');
      exit(1);
    }
  }

  // Pack: per difficulty concat all level byte chunks + a cumulative offsets
  // list (length levels+1, last entry = total length).
  final offsetsPerDiff = <List<int>>[];
  final packedPerDiff = <String>[];
  for (int diff = 0; diff < 3; diff++) {
    final offsets = <int>[0];
    int total = 0;
    for (int i = 0; i < levels; i++) {
      total += perDiff[diff][i].bytes.length;
      offsets.add(total);
    }
    final buf = Uint8List(total);
    int pos = 0;
    for (int i = 0; i < levels; i++) {
      final chunk = perDiff[diff][i].bytes;
      buf.setRange(pos, pos + chunk.length, chunk);
      pos += chunk.length;
    }
    offsetsPerDiff.add(offsets);
    packedPerDiff.add(base64Encode(buf));
  }

  final out = StringBuffer()
    ..writeln('// GENERATED FILE — do not edit by hand.')
    ..writeln('//')
    ..writeln('// $levels unique, strictly-solvable Maze Paint levels per')
    ..writeln('// difficulty. Each level is bit-packed: floor bitmap (1 bit/cell)')
    ..writeln('// + start (8 bits) + solution length (8 bits) + 2 bits/move.')
    ..writeln('//')
    ..writeln('// Boxes: Easy ${mpRows(0)}x${mpCols(0)}, '
        'Medium ${mpRows(1)}x${mpCols(1)}, Hard ${mpRows(2)}x${mpCols(2)}.')
    ..writeln('// Bands: toughness Easy [${mpToughnessMin[0]},${mpToughnessMax[0]}], '
        'Medium [${mpToughnessMin[1]},${mpToughnessMax[1]}], Hard [${mpToughnessMin[2]},inf).')
    ..writeln('// Every level has exactly one solution and sits in its band.')
    ..writeln('//')
    ..writeln('// Regenerate with:')
    ..writeln('//   dart run test/solvability/generate_maze_paint_seeds.dart')
    ..writeln()
    ..writeln("import 'dart:convert';")
    ..writeln("import 'dart:typed_data';")
    ..writeln()
    ..writeln('const int mpLevelsPerDifficulty = $levels;')
    ..writeln();

  out.writeln('const List<List<int>> mpOffsets = [');
  for (final off in offsetsPerDiff) {
    out.writeln('  [${off.join(",")}],');
  }
  out.writeln('];');
  out.writeln();

  out.writeln('const List<String> mpPacked = [');
  for (final s in packedPerDiff) {
    out.writeln("  '$s',");
  }
  out.writeln('];');
  out.writeln();

  out
    ..writeln('final List<Uint8List?> _cache = List<Uint8List?>.filled(3, null);')
    ..writeln()
    ..writeln('Uint8List _bytes(int diff) {')
    ..writeln('  final cached = _cache[diff];')
    ..writeln('  if (cached != null) return cached;')
    ..writeln('  final b = base64Decode(mpPacked[diff]);')
    ..writeln('  _cache[diff] = b;')
    ..writeln('  return b;')
    ..writeln('}')
    ..writeln()
    ..writeln('/// Raw encoded bytes for level [idx] (0-based) on [diff].')
    ..writeln('List<int> mpLevelBytes(int diff, int idx) {')
    ..writeln('  final d = diff.clamp(0, 2);')
    ..writeln('  final b = _bytes(d);')
    ..writeln('  return Uint8List.sublistView(b, mpOffsets[d][idx], mpOffsets[d][idx + 1]);')
    ..writeln('}');

  File('lib/games/maze_paint/maze_paint_seeds.g.dart')
      .writeAsStringSync(out.toString());
  sw.stop();
  stdout.write(
      '\nWrote lib/games/maze_paint/maze_paint_seeds.g.dart in ${sw.elapsed}.\n');
}
