import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:minivo/games/patches/patches_level_gen.dart';
import 'package:minivo/games/patches/patches_seeds.g.dart';

const _diffNames = ['Easy', 'Medium', 'Hard'];

const _heavy = Timeout(Duration(minutes: 8));

/// True bounding-box shape of the solution patch that owns [clueCell].
PatchesShape _trueShapeOf(PatchesLevelResult r, int clueCell) {
  final id = r.solution[clueCell];
  int minR = r.rows, maxR = 0, minC = r.cols, maxC = 0;
  for (int i = 0; i < r.rows * r.cols; i++) {
    if (r.solution[i] != id) continue;
    final cr = i ~/ r.cols, cc = i % r.cols;
    if (cr < minR) minR = cr;
    if (cr > maxR) maxR = cr;
    if (cc < minC) minC = cc;
    if (cc > maxC) maxC = cc;
  }
  final h = maxR - minR + 1, w = maxC - minC + 1;
  if (h == w) return PatchesShape.square;
  return h > w ? PatchesShape.tall : PatchesShape.wide;
}

void main() {
  test('seed table is fully populated (10000 per difficulty)', () {
    expect(patchesLevelsPerDifficulty, 10000);
    expect(patchesPacked.length, 3);
    for (final p in patchesPacked) {
      expect(p, isNotEmpty);
    }
  });

  for (int diffIdx = 0; diffIdx < 3; diffIdx++) {
    final name = _diffNames[diffIdx];
    final rows = patchesRows(diffIdx);
    final cols = patchesCols(diffIdx);
    final total = patchesLevelsPerDifficulty;

    group('Patches $name (${rows}x$cols) — all $total levels', () {
      test('every level is unique (no duplicate layouts)', () {
        final sigs = <String>{};
        for (int lvl = 1; lvl <= total; lvl++) {
          final sig = patchesSignature(generatePatchesLevel(lvl, diffIdx));
          expect(sigs.add(sig), true,
              reason: '$name level $lvl duplicates an earlier level');
        }
        expect(sigs.length, total);
      }, timeout: _heavy);

      test('every level has exactly one solution (by the numbers)', () {
        for (int lvl = 1; lvl <= total; lvl++) {
          final r = generatePatchesLevel(lvl, diffIdx);
          final sols = countPatchesSolutions(r, cap: 2);
          expect(sols, 1,
              reason: '$name level $lvl has $sols solutions (expected 1)');
        }
      }, timeout: _heavy);

      // The decisive guarantee: every level is uniquely solvable using ONLY
      // what the player sees — visible numbers, plus the shape hint for any
      // hidden-number clue (Hard). If this passes for all 30k, no level can
      // strand a player with two valid tilings.
      test('every level has a single solution under player-visible info', () {
        for (int lvl = 1; lvl <= total; lvl++) {
          final r = generatePatchesLevel(lvl, diffIdx);
          final pres = derivePatchesPresentation(r, diffIdx);
          final sols = countPatchesSolutionsForPlayer(r, pres, cap: 2);
          expect(sols, 1,
              reason: '$name level $lvl has $sols player-visible '
                  'solutions (expected 1)');
        }
      }, timeout: _heavy);

      // Easy must be easy, Hard must be hard. Toughness = the number of clues
      // that are locally ambiguous (more than one rectangle fits) along the
      // unique solution — a proxy for how much disambiguation the player does.
      test('every level sits in the $name toughness band', () {
        for (int lvl = 1; lvl <= total; lvl++) {
          final t = patchesToughness(generatePatchesLevel(lvl, diffIdx));
          switch (diffIdx) {
            case 0:
              expect(t, 0,
                  reason: '$name level $lvl toughness $t (expected 0 — fully '
                      'forced)');
            case 1:
              expect(t >= 1 && t <= 4, true,
                  reason: '$name level $lvl toughness $t (expected 1..4)');
            default:
              expect(t >= 5, true,
                  reason: '$name level $lvl toughness $t (expected >= 5)');
          }
        }
      }, timeout: _heavy);

      // The on-screen hints must never lie and must always be usable.
      test('presentation hints are well-formed and truthful', () {
        for (int lvl = 1; lvl <= total; lvl++) {
          final r = generatePatchesLevel(lvl, diffIdx);
          final pres = derivePatchesPresentation(r, diffIdx);

          final clueCells = <int>{};
          for (int i = 0; i < r.clues.length; i++) {
            if (r.clues[i] > 0) clueCells.add(i);
          }
          // Exactly one shape per clue, and only on clue cells.
          expect(pres.shapes.keys.toSet(), clueCells,
              reason: '$name $lvl shapes not exactly on clue cells');
          // A concrete (non-"any") shape must equal the true patch shape.
          for (final e in pres.shapes.entries) {
            if (e.value != PatchesShape.any) {
              expect(e.value, _trueShapeOf(r, e.key),
                  reason: '$name $lvl clue ${e.key} shows a wrong shape');
            }
          }
          // Hidden numbers: Hard only, always area > 1, never "any" (so the
          // player always keeps a usable shape hint), shape always truthful.
          if (diffIdx != 2) {
            expect(pres.hidden, isEmpty,
                reason: '$name $lvl unexpectedly hides clue numbers');
          }
          for (final h in pres.hidden) {
            expect(clueCells.contains(h), true,
                reason: '$name $lvl hides a non-clue cell');
            expect(r.clues[h] > 1, true,
                reason: '$name $lvl hides a 1-cell clue');
            expect(pres.shapes[h] != PatchesShape.any, true,
                reason: '$name $lvl hides number AND shape (no hint left)');
            expect(pres.shapes[h], _trueShapeOf(r, h),
                reason: '$name $lvl hidden clue $h shows a wrong shape');
          }
        }
      }, timeout: _heavy);

      test('every stored solution is valid', () {
        for (int lvl = 1; lvl <= total; lvl++) {
          final r = generatePatchesLevel(lvl, diffIdx);
          expect(r.rows, rows, reason: '$name $lvl wrong rows');
          expect(r.cols, cols, reason: '$name $lvl wrong cols');
          expect(r.clues.length, rows * cols);
          expect(r.solution.length, rows * cols);

          final patchCells = <int, List<int>>{};
          for (int i = 0; i < rows * cols; i++) {
            patchCells.putIfAbsent(r.solution[i], () => []).add(i);
          }
          for (final entry in patchCells.entries) {
            final cells = entry.value;
            int minR = rows, maxR = 0, minC = cols, maxC = 0;
            for (final c in cells) {
              final cr = c ~/ cols, cc = c % cols;
              if (cr < minR) minR = cr;
              if (cr > maxR) maxR = cr;
              if (cc < minC) minC = cc;
              if (cc > maxC) maxC = cc;
            }
            expect((maxR - minR + 1) * (maxC - minC + 1), cells.length,
                reason: '$name $lvl patch ${entry.key} not rectangular');
            int clueCount = 0;
            for (final c in cells) {
              if (r.clues[c] > 0) clueCount++;
            }
            expect(clueCount, 1,
                reason: '$name $lvl patch ${entry.key} has $clueCount clues');
            final clueIdx = cells.firstWhere((c) => r.clues[c] > 0);
            expect(r.clues[clueIdx], cells.length,
                reason: '$name $lvl patch ${entry.key} clue mismatch');
          }
          expect(r.solution.every((v) => v >= 0), true,
              reason: '$name $lvl has uncovered cells');
        }
      }, timeout: _heavy);

      test('every level round-trips through the bit codec (clues AND solution)',
          () {
        final stride = patchesStrideBytes(rows, cols);
        final n = rows * cols;
        int maxClue = 0, maxSolId = 0;
        for (int lvl = 1; lvl <= total; lvl++) {
          final r = generatePatchesLevel(lvl, diffIdx);
          final bytes = patchesEncodeLevel(r);
          expect(bytes.length, stride);
          final r2 = patchesDecodeLevel(rows, cols, Uint8List.fromList(bytes));
          // Signature (grid + clues) is necessary but NOT sufficient — it
          // ignores the solution field, which the runtime relies on. Compare
          // every cell of both arrays.
          for (int i = 0; i < n; i++) {
            expect(r2.clues[i], r.clues[i],
                reason: '$name level $lvl clue[$i] codec mismatch');
            expect(r2.solution[i], r.solution[i],
                reason: '$name level $lvl solution[$i] codec mismatch');
            if (r.clues[i] > maxClue) maxClue = r.clues[i];
            if (r.solution[i] > maxSolId) maxSolId = r.solution[i];
          }
        }
        // The codec packs clues in 5 bits and solution ids in 8 bits.
        expect(maxClue, lessThanOrEqualTo(31), reason: '$name clue overflows 5 bits');
        expect(maxSolId, lessThanOrEqualTo(255),
            reason: '$name solution id overflows 8 bits');
      }, timeout: _heavy);

      test('deterministic — same level always decodes to the same puzzle', () {
        for (int lvl = 1; lvl <= 25; lvl++) {
          expect(patchesSignature(generatePatchesLevel(lvl, diffIdx)),
              patchesSignature(generatePatchesLevel(lvl, diffIdx)));
        }
      });

      test('levels wrap around the table', () {
        expect(patchesSignature(generatePatchesLevel(1, diffIdx)),
            patchesSignature(generatePatchesLevel(total + 1, diffIdx)));
        expect(patchesSignature(generatePatchesLevel(7, diffIdx)),
            patchesSignature(generatePatchesLevel(total + 7, diffIdx)));
      });
    });
  }

  group('Patches difficulty gradation', () {
    test('toughness strictly increases Easy < Medium < Hard (median)', () {
      double median(int diffIdx) {
        final vals = <int>[];
        for (int lvl = 1; lvl <= 3000; lvl++) {
          vals.add(patchesToughness(generatePatchesLevel(lvl, diffIdx)));
        }
        vals.sort();
        return vals[vals.length ~/ 2].toDouble();
      }

      final easy = median(0), medium = median(1), hard = median(2);
      expect(easy < medium, true, reason: 'easy median $easy !< medium $medium');
      expect(medium < hard, true,
          reason: 'medium median $medium !< hard $hard');
    }, timeout: _heavy);

    test('grid size grows with difficulty, all 30k distinct per band', () {
      expect([patchesRows(0), patchesRows(1), patchesRows(2)], [5, 7, 9]);
      expect([patchesCols(0), patchesCols(1), patchesCols(2)], [5, 7, 9]);
    });
  });
}
