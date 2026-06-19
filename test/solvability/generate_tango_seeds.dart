import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:minivo/games/tango/tango_level_gen.dart';

// ---------------------------------------------------------------------------
// Offline generator for the Tango seed table.
//
// Produces `levelsPerDiff` UNIQUE, strictly-solvable puzzles per difficulty and
// packs each into bitmaps written to lib/games/tango/tango_seeds.g.dart.
//
// Every puzzle is built by clue REDUCTION and is guaranteed:
//   * solvable by pure logic at its difficulty's tier (Easy 1 / Medium 2 /
//     Hard 3) — never by guessing,
//   * therefore having EXACTLY ONE solution (every cell is forced),
//   * unique within its difficulty (deduped by full signature).
//
// Difficulty toughness (grid size fixed at 4 / 6 / 6):
//   Easy   — basic forced moves, generous givens.
//   Medium — needs one-ply forcing chains, fewer givens.
//   Hard   — needs two-ply forcing chains, minimal givens.
//
// Run:  dart run test/solvability/generate_tango_seeds.dart [levels]
// ---------------------------------------------------------------------------

const _defaultLevels = 10000;

// Easy keeps >= 6 givens so 4x4 puzzles stay gentle AND there is enough clue
// variety to fill the table with distinct layouts. Medium/Hard reduce fully.
const _givenFloors = [6, 0, 0];

const _diffNames = ['EASY', 'MEDIUM', 'HARD'];

class _Job {
  final SendPort port;
  final int diff;
  final int seed;
  final int floor;
  _Job(this.port, this.diff, this.seed, this.floor);
}

// A worker streams valid (signature, packed-bytes) pairs forever; the main
// isolate dedups and stops it once the target count is reached.
void _worker(_Job job) {
  final rng = math.Random(job.seed);
  while (true) {
    final p = buildTangoPuzzle(job.diff, rng, givenFloor: job.floor);
    if (p == null) continue;
    job.port.send([tangoSignature(p), tangoEncodeLevel(p)]);
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
    // Distinct, well-separated seeds so isolate RNG streams don't overlap.
    final seed = 0x5DEECE6 + diff * 1000003 + i * 2654435761;
    isolates.add(await Isolate.spawn(
        _worker, _Job(rp.sendPort, diff, seed & 0x3FFFFFFF, _givenFloors[diff])));
  }

  final name = _diffNames[diff];
  final sw = Stopwatch()..start();
  int received = 0, sinceNew = 0;
  const maxStall = 400000; // abort if this many produced with no new unique
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
          'reachable ($received produced). Raise the given floor.\n');
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

  stdout.write('Generating $levels Tango puzzles x 3 difficulties '
      '($numIsolates isolates)\n');
  stdout.write('Tiers: Easy=1 (basic)  Medium=2 (1-ply)  Hard=3 (2-ply). '
      'All logic-solvable, single-solution.\n\n');

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

  // Independent verification pass (the generator already guarantees these, but
  // verify a chunk per difficulty to catch any encode/decode mismatch).
  stdout.write('\nVerifying decode round-trip + uniqueness...\n');
  for (int diff = 0; diff < 3; diff++) {
    final n = tangoGridSize(diff);
    final stride = tangoStrideBytes(n);
    final tier = tangoTierFor(diff);
    final sigs = <String>{};
    int bad = 0;
    for (int i = 0; i < levels; i++) {
      final rec = perDiff[diff][i];
      if (rec.length != stride) {
        bad++;
        continue;
      }
      final p = tangoDecodeLevel(n, rec);
      if (!sigs.add(tangoSignature(p))) bad++;
      // Spot-verify 1-in-50 (full verification runs in the test suite).
      if (i % 50 == 0) {
        if (countTangoSolutions(p, cap: 2) != 1) bad++;
        if (tangoRequiredTier(p) != tier) bad++;
      }
    }
    stdout.write('  [${_diffNames[diff]}] ${sigs.length} unique, '
        '$bad problems\n');
    if (bad > 0 || sigs.length != levels) {
      stdout.write('FAILED verification for ${_diffNames[diff]}.\n');
      exit(1);
    }
  }

  // Pack: concatenate stride-sized records per difficulty, base64 each.
  final packed = <String>[];
  for (int diff = 0; diff < 3; diff++) {
    final n = tangoGridSize(diff);
    final stride = tangoStrideBytes(n);
    final buf = Uint8List(stride * levels);
    for (int i = 0; i < levels; i++) {
      buf.setRange(i * stride, (i + 1) * stride, perDiff[diff][i]);
    }
    packed.add(base64Encode(buf));
  }

  final out = StringBuffer()
    ..writeln('// GENERATED FILE — do not edit by hand.')
    ..writeln('//')
    ..writeln('// $levels unique, logic-solvable Tango puzzles per difficulty,')
    ..writeln('// packed as bitmaps (solution + clue-present + prefill-present).')
    ..writeln('// Clue and prefill VALUES are derived from the solution at')
    ..writeln('// decode time, so they are not stored.')
    ..writeln('//')
    ..writeln('// Grids: Easy 4x4, Medium 6x6, Hard 6x6.')
    ..writeln('// Tiers: Easy=1 (basic), Medium=2 (1-ply), Hard=3 (2-ply).')
    ..writeln('// Every puzzle has exactly one solution, reachable by pure logic.')
    ..writeln('//')
    ..writeln('// Regenerate with:')
    ..writeln('//   dart run test/solvability/generate_tango_seeds.dart')
    ..writeln()
    ..writeln('const int tangoLevelsPerDifficulty = $levels;')
    ..writeln()
    ..writeln('const List<String> tangoPacked = [');
  for (final s in packed) {
    out.writeln("  '$s',");
  }
  out.writeln('];');

  File('lib/games/tango/tango_seeds.g.dart').writeAsStringSync(out.toString());
  sw.stop();
  stdout.write('\nWrote lib/games/tango/tango_seeds.g.dart in ${sw.elapsed}.\n');
}
