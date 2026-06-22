import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:minivo/games/color_connect/color_connect_level_gen.dart';

const _defaultLevels = 10000;

const _diffNames = ['EASY', 'MEDIUM', 'HARD'];

class _LevelRecord {
  final String sig;
  final Uint8List bytes;
  final int numFlows;
  _LevelRecord(this.sig, this.bytes, this.numFlows);
}

class _Job {
  final SendPort port;
  final int diff;
  final int seed;
  _Job(this.port, this.diff, this.seed);
}

void _worker(_Job job) {
  final rng = math.Random(job.seed);
  final rows = ccRows(job.diff);
  final cols = ccCols(job.diff);
  final flowSet = ccFlowSets[job.diff];
  while (true) {
    // Pick a colour count from the difficulty's candidate set each attempt so
    // shipped levels vary in colour count while every one stays in band.
    final numFlows = flowSet[rng.nextInt(flowSet.length)];
    final p = buildColorConnectPuzzle(rows, cols, numFlows, rng);
    if (p == null) continue;
    if (!ccSolvable(p)) continue; // strictly one solution
    if (!ccToughnessOk(job.diff, ccToughness(p))) continue; // difficulty band
    job.port.send([ccSignature(p), ccEncodeLevel(p), numFlows]);
  }
}

Future<List<_LevelRecord>> generateDifficulty(
    int diff, int levels, int numIsolates) async {
  final unique = <String, _LevelRecord>{};
  final isolates = <Isolate>[];
  final ports = <ReceivePort>[];
  final controller = StreamController<dynamic>();

  for (int i = 0; i < numIsolates; i++) {
    final rp = ReceivePort();
    ports.add(rp);
    rp.listen(controller.add);
    final seed = 0xCC00EC7 + diff * 1000003 + i * 2654435761;
    isolates.add(await Isolate.spawn(
        _worker, _Job(rp.sendPort, diff, seed & 0x3FFFFFFF)));
  }

  final name = _diffNames[diff];
  final sw = Stopwatch()..start();
  int received = 0, sinceNew = 0;
  const maxStall = 800000;
  const maxSeconds = 3600;

  await for (final msg in controller.stream) {
    received++;
    final data = msg as List<dynamic>;
    final sig = data[0] as String;
    final before = unique.length;
    unique[sig] = _LevelRecord(sig, data[1] as Uint8List, data[2] as int);
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

  stdout.write('Generating $levels Color Connect puzzles x 3 difficulties '
      '($numIsolates isolates)\n');
  stdout.write('Grids: Easy 5x5 (${ccFlowSets[0]} flows), '
      'Medium 7x7 (${ccFlowSets[1]}), Hard 9x9 (${ccFlowSets[2]}).\n');
  stdout.write('Toughness bands: '
      'Easy [${ccToughnessMin[0]}, ${ccToughnessMax[0]}], '
      'Medium [${ccToughnessMin[1]}, ${ccToughnessMax[1]}], '
      'Hard [${ccToughnessMin[2]}, ∞).\n\n');

  final perDiff = <List<_LevelRecord>>[];
  for (int diff = 0; diff < 3; diff++) {
    final records = await generateDifficulty(diff, levels, numIsolates);
    if (records.length < levels) {
      stdout.write('\nFAILED: ${_diffNames[diff]} produced only '
          '${records.length}/$levels. Aborting.\n');
      exit(1);
    }
    perDiff.add(records);
  }

  stdout.write('\nVerifying decode round-trip + uniqueness + bands...\n');
  for (int diff = 0; diff < 3; diff++) {
    final rows = ccRows(diff);
    final cols = ccCols(diff);
    final sigs = <String>{};
    int bad = 0;
    final flowCounts = <int, int>{};
    final tough = <int>[];
    for (int i = 0; i < levels; i++) {
      final rec = perDiff[diff][i];
      final numFlows = rec.numFlows;
      final stride = ccStrideBytes(rows, cols, numFlows);
      if (rec.bytes.length != stride) {
        bad++;
        continue;
      }
      final p = ccDecodeLevel(rows, cols, numFlows, rec.bytes);
      if (!sigs.add(ccSignature(p))) bad++;
      flowCounts[numFlows] = (flowCounts[numFlows] ?? 0) + 1;
      final t = ccToughness(p);
      tough.add(t);
      if (!ccToughnessOk(diff, t)) bad++; // out-of-band leaked through
      if (i % 100 == 0) {
        if (countColorConnectSolutions(p, cap: 2) != 1) bad++;
      }
    }
    tough.sort();
    final mean = tough.reduce((a, b) => a + b) / tough.length;
    final p50 = tough[tough.length ~/ 2];
    final p90 = tough[(tough.length * 9) ~/ 10];
    stdout.write('  [${_diffNames[diff]}] ${sigs.length} unique, '
        '$bad problems | flows=$flowCounts | '
        'toughness mean=${mean.toStringAsFixed(2)} p50=$p50 p90=$p90 '
        'max=${tough.last}\n');
    if (bad > 0 || sigs.length != levels) {
      stdout.write('FAILED verification for ${_diffNames[diff]}.\n');
      exit(1);
    }
  }

  final flowCountsPerDiff = <List<int>>[];
  final offsetsPerDiff = <List<int>>[];
  final packedPerDiff = <String>[];

  for (int diff = 0; diff < 3; diff++) {
    final flowCounts = <int>[];
    final offsets = <int>[];
    final chunks = <Uint8List>[];
    int currentOffset = 0;

    for (int i = 0; i < levels; i++) {
      final rec = perDiff[diff][i];
      flowCounts.add(rec.numFlows);
      offsets.add(currentOffset);
      chunks.add(rec.bytes);
      currentOffset += rec.bytes.length;
    }

    final buf = Uint8List(currentOffset);
    int pos = 0;
    for (final chunk in chunks) {
      buf.setRange(pos, pos + chunk.length, chunk);
      pos += chunk.length;
    }
    packedPerDiff.add(base64Encode(buf));
    flowCountsPerDiff.add(flowCounts);
    offsetsPerDiff.add(offsets);
  }

  final out = StringBuffer()
    ..writeln('// GENERATED FILE — do not edit by hand.')
    ..writeln('//')
    ..writeln('// $levels unique, solvable Color Connect puzzles per difficulty,')
    ..writeln('// packed as bitmaps (endpoints 8-bit + solution 8-bit per cell).')
    ..writeln('//')
    ..writeln('// Grids:  Easy 5x5 (${ccFlowSets[0]} flows),'
        ' Medium 7x7 (${ccFlowSets[1]}), Hard 9x9 (${ccFlowSets[2]}).')
    ..writeln('// Bands:  toughness Easy [${ccToughnessMin[0]},${ccToughnessMax[0]}],'
        ' Medium [${ccToughnessMin[1]},${ccToughnessMax[1]}], Hard [${ccToughnessMin[2]},inf).')
    ..writeln('// Every puzzle has exactly one solution and sits in its band.')
    ..writeln('//')
    ..writeln('// Regenerate with:')
    ..writeln('//   dart run test/solvability/generate_color_connect_seeds.dart')
    ..writeln()
    ..writeln('const int ccLevelsPerDifficulty = $levels;')
    ..writeln();

  out.writeln('const List<List<int>> ccFlowCounts = [');
  for (final fc in flowCountsPerDiff) {
    out.writeln('  [${fc.join(", ")}],');
  }
  out.writeln('];');
  out.writeln();

  out.writeln('const List<List<int>> ccOffsets = [');
  for (final off in offsetsPerDiff) {
    out.writeln('  [${off.join(", ")}],');
  }
  out.writeln('];');
  out.writeln();

  out.writeln('const List<String> ccPacked = [');
  for (final s in packedPerDiff) {
    out.writeln("  '$s',");
  }
  out.writeln('];');

  File('lib/games/color_connect/color_connect_seeds.g.dart')
      .writeAsStringSync(out.toString());
  sw.stop();
  stdout.write(
      '\nWrote lib/games/color_connect/color_connect_seeds.g.dart in ${sw.elapsed}.\n');
}
