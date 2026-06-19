import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/models/game_info.dart';
import '../../lib/games/game_registry.dart';
import '../../lib/games/game_wrapper.dart';
import '../../lib/games/patches/patches_level_gen.dart';
import '../../lib/games/shared/level_complete_overlay.dart';
import '../../lib/games/shared/spinning_slider.dart';

import '../helpers/game_drivers.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

const _gameId = 'patches';

Widget _build() =>
    GameWrapper(gameId: _gameId, child: GameRegistry.buildGame(_gameId));

/// Cells of each solution patch, keyed by patch id.
Map<int, List<int>> _patchesOf(PatchesLevelResult p) {
  final out = <int, List<int>>{};
  for (int i = 0; i < p.rows * p.cols; i++) {
    out.putIfAbsent(p.solution[i], () => []).add(i);
  }
  return out;
}

/// Global point at fractional cell coords (row+fr, col+fc) — fc/fr in [0,1)
/// within the cell — derived from the rendered grid container.
Offset _cellPoint(WidgetTester tester, PatchesLevelResult p, double r, double c) {
  const bw = 2.0;
  final rect = tester.getRect(find.byKey(const Key('patches_grid')));
  final cellSz = (rect.width - 2 * bw) / p.cols;
  return Offset(rect.left + bw + c * cellSz, rect.top + bw + r * cellSz);
}

Offset _cellCenter(WidgetTester tester, PatchesLevelResult p, int r, int c) =>
    _cellPoint(tester, p, r + 0.5, c + 0.5);

/// Drives the screen to a win by placing every solution patch: a tap for a
/// 1-cell patch, a multi-step drag for the rest.
///
/// The drag starts just inside the start cell's near corner and advances in
/// sub-cell steps, so the pan recognizer fires onPanStart while the pointer is
/// still inside the start cell (Flutter's DragStartBehavior.start otherwise
/// snaps the drag origin to wherever slop is crossed, which a single big jump
/// would push into the next cell — leaving the placed rectangle a cell short).
Future<void> _solveByDrag(WidgetTester tester, PatchesLevelResult p) async {
  for (final cells in _patchesOf(p).values) {
    int minR = p.rows, maxR = 0, minC = p.cols, maxC = 0;
    for (final idx in cells) {
      final r = idx ~/ p.cols, c = idx % p.cols;
      if (r < minR) minR = r;
      if (r > maxR) maxR = r;
      if (c < minC) minC = c;
      if (c > maxC) maxC = c;
    }
    if (cells.length == 1) {
      await tester.tapAt(_cellCenter(tester, p, minR, minC));
    } else {
      final start = _cellPoint(tester, p, minR + 0.2, minC + 0.2);
      final end = _cellPoint(tester, p, maxR + 0.8, maxC + 0.8);
      final steps = (math.max(maxR - minR, maxC - minC) + 1) * 4;
      final g = await tester.startGesture(start);
      for (int s = 1; s <= steps; s++) {
        await g.moveTo(Offset.lerp(start, end, s / steps)!);
      }
      await g.up();
    }
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  group('Patches registry', () {
    test('is registered with correct metadata', () {
      final info = GameRegistry.getById(_gameId);
      expect(info, isNotNull);
      expect(info!.name, 'Patches');
      expect(info.category, GameCategory.puzzle);
      expect(info.howToPlay, isNotEmpty);
    });
  });

  group('Patches picker', () {
    for (final device in allTestDevices) {
      group('${device.name} (${device.width}x${device.height})', () {
        setUp(() async => initGameTest());

        testWidgets('renders picker without overflow', (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          expect(find.text('Patches'), findsWidgets);
          expectNoOverflow(device, 'Patches picker');
          cleanUp(tester);
        });

        testWidgets('play button starts game', (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          await selectAndPlay(tester, 0, 'Play Patches');
          expect(find.byType(SpinningSlider), findsNothing,
              reason: 'still on picker');
          expect(find.text('LEVEL'), findsOneWidget);
          expectNoOverflow(device, 'Patches playing');
          cleanUp(tester);
        });
      });
    }
  });

  group('Patches gameplay per difficulty', () {
    for (final device in allTestDevices) {
      for (int stop = 0; stop < 3; stop++) {
        final diff = const ['Easy', 'Medium', 'Hard'][stop];
        group('$diff on ${device.name}', () {
          setUp(() async => initGameTest());

          testWidgets('renders without overflow', (tester) async {
            await pumpScreen(tester, device, _build(), settle: false);
            await selectAndPlay(tester, stop, 'Play Patches');
            expect(find.byType(SpinningSlider), findsNothing);
            expect(find.text('LEVEL'), findsOneWidget);
            await tester.pump(const Duration(milliseconds: 400));
            expectNoOverflow(device, 'Patches $diff');
            cleanUp(tester);
          });
        });
      }
    }
  });

  group('Patches dynamic states', () {
    const tightDevices = [
      TestDevice(name: 'Small Android', width: 320, height: 568, pixelRatio: 2.0, platform: TargetPlatform.android),
      TestDevice(name: 'iPhone SE', width: 320, height: 568, pixelRatio: 2.0, platform: TargetPlatform.iOS),
    ];

    for (final device in tightDevices) {
      group('${device.name}', () {
        setUp(() async => initGameTest());

        testWidgets('hint button renders without overflow', (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          await selectAndPlay(tester, 0, 'Play Patches');
          expect(find.text('HINT'), findsOneWidget);
          await tester.tap(find.text('HINT'), warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 300));
          expectNoOverflow(device, 'Patches hint');
          cleanUp(tester);
        });

        testWidgets('idle nudge appears without overflow', (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          await selectAndPlay(tester, 0, 'Play Patches');
          await tester.pump(const Duration(seconds: 9));
          expect(find.text('Stuck? Try a hint!'), findsOneWidget);
          expectNoOverflow(device, 'Patches idle nudge');
          cleanUp(tester);
        });

        testWidgets('pause overlay renders without overflow', (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          await selectAndPlay(tester, 0, 'Play Patches');
          expect(find.text('LEVEL'), findsOneWidget);
          expectNoOverflow(device, 'Patches pause');
          cleanUp(tester);
        });
      });
    }
  });

  // A representative spread (tightest + a mid phone + a large tablet, both
  // platforms) where we actually SOLVE a board, exercising drag placement, the
  // win check, and the level-complete overlay without overflow.
  group('Patches win flow', () {
    const winDevices = [
      TestDevice(name: 'Small Android', width: 320, height: 568, pixelRatio: 2.0, platform: TargetPlatform.android),
      TestDevice(name: 'iPhone SE', width: 320, height: 568, pixelRatio: 2.0, platform: TargetPlatform.iOS),
      TestDevice(name: 'iPhone 13/14', width: 390, height: 844, pixelRatio: 3.0, platform: TargetPlatform.iOS),
      TestDevice(name: 'iPad Pro', width: 1024, height: 1366, pixelRatio: 2.0, platform: TargetPlatform.iOS),
    ];

    for (final device in winDevices) {
      for (int stop = 0; stop < 3; stop++) {
        final diff = const ['Easy', 'Medium', 'Hard'][stop];
        testWidgets('solving a $diff board wins without overflow on '
            '${device.name}', (tester) async {
          await initGameTest(extra: {levelCurrentKey(_gameId, const ['easy', 'medium', 'hard'][stop]): 1});
          await pumpScreen(tester, device, _build(), settle: false);
          await selectAndPlay(tester, stop, 'Play Patches');
          expect(find.text('LEVEL'), findsOneWidget);

          // Level 1 of this difficulty is what the screen loaded.
          final puzzle = generatePatchesLevel(1, stop);
          await _solveByDrag(tester, puzzle);
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(LevelCompleteOverlay), findsOneWidget,
              reason: 'solving the board should trigger the win overlay');
          expectNoOverflow(device, 'Patches $diff win');
          cleanUp(tester);
        });
      }
    }
  });

  group('Patches interaction', () {
    const device = TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android);

    testWidgets('tap places a 1-cell clue then tap removes it', (tester) async {
      await initGameTest(extra: {levelCurrentKey(_gameId, 'easy'): 1});
      await pumpScreen(tester, device, _build(), settle: false);
      await selectAndPlay(tester, 0, 'Play Patches');

      final puzzle = generatePatchesLevel(1, 0);
      final total = puzzle.rows * puzzle.cols;
      // Find a 1-cell patch (clue area 1).
      int? singleCell;
      for (final cells in _patchesOf(puzzle).values) {
        if (cells.length == 1) {
          singleCell = cells.first;
          break;
        }
      }
      expect(singleCell, isNotNull,
          reason: 'easy level 1 should contain a 1-cell patch');
      final r = singleCell! ~/ puzzle.cols, c = singleCell % puzzle.cols;

      expect(find.text('0/$total'), findsOneWidget);
      await tester.tapAt(_cellCenter(tester, puzzle, r, c));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('1/$total'), findsOneWidget,
          reason: 'tapping a 1-clue should fill one cell');
      await tester.tapAt(_cellCenter(tester, puzzle, r, c));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('0/$total'), findsOneWidget,
          reason: 'tapping an existing patch should remove it');
      expectNoOverflow(device, 'Patches interaction');
      cleanUp(tester);
    });
  });
}
