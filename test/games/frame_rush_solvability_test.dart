import 'package:flutter_test/flutter_test.dart';

import 'package:minivo/games/frame_rush/frame_rush_level_gen.dart';
import 'package:minivo/games/frame_rush/frame_rush_seeds.g.dart';

const _diffNames = ['EASY', 'MEDIUM', 'HARD'];

/// Returns an error string for [level], or null if the baked level is
/// well-formed: exactly one alignment window per loop (strictly solvable), that
/// window is fair for the difficulty, and the frame pose is self-consistent.
String? validateLevel(int level, int diffIdx) {
  final r = generateFrameRushLevel(level, diffIdx);

  if (r.posTol <= 0 || r.loopSeconds <= 0) {
    return 'non-positive params';
  }
  if (r.objectType < 0 || r.objectType >= frameRushObjectCount) {
    return 'bad object type ${r.objectType}';
  }

  // The frame must be capturable at its own parameter (the guaranteed aim).
  if (!frameRushIsAligned(r, r.frameS)) {
    return 'frame pose not aligned with itself';
  }

  // Strict solvability: exactly one contiguous alignment window per loop.
  final windows = countFrameRushWindows(r, cap: 2);
  if (windows != 1) return 'not single-window (windows=$windows)';

  // Fairness: the window must be hittable but not trivial.
  final ms = frameRushWindowMs(r);
  if (ms + 1e-6 < frameRushMinWindowMs(diffIdx)) {
    return 'window ${ms.toStringAsFixed(0)}ms < min ${frameRushMinWindowMs(diffIdx)}';
  }
  if (ms - 1e-6 > frameRushMaxWindowMs(diffIdx)) {
    return 'window ${ms.toStringAsFixed(0)}ms > max ${frameRushMaxWindowMs(diffIdx)}';
  }
  if (ms < kFrameRushHardFloorMs) return 'window below hard floor';
  return null;
}

void main() {
  // ── Fast capture-logic sanity (a handful of levels) ──────────────────────
  group('Frame Rush capture logic', () {
    test('the frame pose is a dead-on capture', () {
      for (final diff in [0, 1, 2]) {
        for (final level in const [1, 2, 50, 9999]) {
          final r = generateFrameRushLevel(level, diff);
          expect(frameRushIsAligned(r, r.frameS), isTrue,
              reason: '$level/$diff frame pose should align');
          expect(frameRushAccuracy(r, r.frameS), greaterThan(0.98),
              reason: '$level/$diff accuracy at frame');
          expect(frameRushError(r, r.frameS), lessThan(0.05));
        }
      }
    });

    test('the opposite side of the loop is not a capture', () {
      for (final diff in [0, 1, 2]) {
        for (final level in const [1, 7, 123, 5000]) {
          final r = generateFrameRushLevel(level, diff);
          final opp = (r.frameS + 0.5) % 1.0;
          expect(frameRushIsAligned(r, opp), isFalse,
              reason: '$level/$diff far side should miss');
        }
      }
    });
  });

  test('seed table is fully populated', () {
    expect(frameRushLevelsPerDifficulty, 10000);
  });

  // ── Heavy verification over all 30,000 baked levels ──────────────────────
  group('Frame Rush strict solvability + fairness', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test(
          'all levels 1-$frameRushLevelsPerDifficulty on ${_diffNames[diffIdx]} '
          'are single-window + fair', () {
        final failures = <String>[];
        for (int level = 1; level <= frameRushLevelsPerDifficulty; level++) {
          final err = validateLevel(level, diffIdx);
          if (err != null) {
            failures.add('level $level: $err');
            if (failures.length > 20) break;
          }
        }
        expect(failures, isEmpty,
            reason: '${_diffNames[diffIdx]} failures: $failures');
      }, timeout: const Timeout(Duration(minutes: 30)));
    }
  });

  group('Frame Rush cross-level uniqueness', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('all $frameRushLevelsPerDifficulty levels on ${_diffNames[diffIdx]} '
          'are distinct', () {
        final seen = <String, int>{};
        final dupes = <String>[];
        for (int level = 1; level <= frameRushLevelsPerDifficulty; level++) {
          final sig = frameRushSignature(generateFrameRushLevel(level, diffIdx));
          final prev = seen[sig];
          if (prev != null) {
            dupes.add('level $level == level $prev');
            if (dupes.length > 20) break;
          } else {
            seen[sig] = level;
          }
        }
        expect(dupes, isEmpty,
            reason: '${_diffNames[diffIdx]} duplicates: $dupes');
        expect(seen.length, frameRushLevelsPerDifficulty);
      }, timeout: const Timeout(Duration(minutes: 20)));
    }
  });

  // Same (level, diff) rebuilds identically on every device.
  group('Frame Rush determinism', () {
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('${_diffNames[diffIdx]} levels rebuild identically', () {
        for (final level in const [1, 2, 7, 50, 137, 5000, 9999]) {
          expect(
            frameRushSignature(generateFrameRushLevel(level, diffIdx)),
            frameRushSignature(generateFrameRushLevel(level, diffIdx)),
          );
        }
      });
    }
  });

  // Past 10k the levels repeat while the displayed counter climbs.
  group('Frame Rush wrap-around', () {
    const n = 10000;
    for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
      test('${_diffNames[diffIdx]} levels repeat every $n', () {
        for (final base in const [1, 2, 137, 5000, 9999, 10000]) {
          for (final cycle in const [1, 2, 7]) {
            expect(
              frameRushSignature(
                  generateFrameRushLevel(base + cycle * n, diffIdx)),
              frameRushSignature(generateFrameRushLevel(base, diffIdx)),
              reason: 'level ${base + cycle * n} must equal level $base',
            );
          }
        }
      });

      test('${_diffNames[diffIdx]} wrapped levels stay single-window', () {
        for (final level in const [10001, 15000, 20000, 99999]) {
          final wrapped = generateFrameRushLevel(level, diffIdx);
          expect(countFrameRushWindows(wrapped, cap: 2), 1,
              reason: 'wrapped level $level not single-window');
        }
      });
    }
  });
}
