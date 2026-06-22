import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/models/game_info.dart';
import '../../lib/games/game_registry.dart';
import '../../lib/games/game_wrapper.dart';
import '../../lib/games/color_connect/color_connect_level_gen.dart' as gen;
import '../../lib/games/shared/level_complete_overlay.dart';
import '../../lib/games/shared/spinning_slider.dart';

import '../helpers/game_drivers.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

const _gameId = 'color_connect';

Widget _build() =>
    GameWrapper(gameId: _gameId, child: GameRegistry.buildGame(_gameId));

// --- Grid geometry (mirrors _buildGrid in color_connect_screen.dart) -------
double _gap(int rows) => rows <= 5 ? 3.0 : (rows <= 7 ? 2.5 : 2.0);

double _cellSize(WidgetTester tester, gen.ColorConnectLevelResult p) {
  const pad = 6.0;
  final gap = _gap(p.rows);
  final rect = tester.getRect(find.byKey(const Key('cc_grid')));
  return (rect.width - 2 * pad - (p.cols - 1) * gap) / p.cols;
}

Offset _cellCenter(WidgetTester tester, gen.ColorConnectLevelResult p, int cell) {
  const pad = 6.0;
  final gap = _gap(p.rows);
  final rect = tester.getRect(find.byKey(const Key('cc_grid')));
  final cellSz = (rect.width - 2 * pad - (p.cols - 1) * gap) / p.cols;
  final r = cell ~/ p.cols, c = cell % p.cols;
  return Offset(
    rect.left + pad + c * (cellSz + gap) + cellSz / 2,
    rect.top + pad + r * (cellSz + gap) + cellSz / 2,
  );
}

List<int> _neighbors(int idx, int rows, int cols) {
  final r = idx ~/ cols, c = idx % cols;
  final res = <int>[];
  if (r > 0) res.add((r - 1) * cols + c);
  if (r < rows - 1) res.add((r + 1) * cols + c);
  if (c > 0) res.add(r * cols + c - 1);
  if (c < cols - 1) res.add(r * cols + c + 1);
  return res;
}

/// The flow's actual routing: a Hamiltonian path of flow [f]'s solution cells
/// from one endpoint to the other. A greedy adjacency walk is NOT enough — a
/// flow region can contain a 2x2 block (cells adjacent but not consecutive in
/// the route), where greedy takes a chord into a dead end and returns a short
/// endpoint-to-endpoint path that leaves cells uncovered. We DFS for the true
/// path (regions are tiny, so this is instant). The puzzle guarantees one
/// exists — it is exactly the segment the generator cut from its Hamiltonian.
List<int> _orderedPath(gen.ColorConnectLevelResult p, int f) {
  final ep0 = p.endpoints[f * 2], ep1 = p.endpoints[f * 2 + 1];
  final cellSet = <int>{};
  for (int i = 0; i < p.rows * p.cols; i++) {
    if (p.solution[i] == f) cellSet.add(i);
  }
  final result = <int>[];
  final visited = <int>{};

  bool dfs(int cur) {
    visited.add(cur);
    result.add(cur);
    if (result.length == cellSet.length) {
      if (cur == ep1) return true;
    } else {
      for (final nb in _neighbors(cur, p.rows, p.cols)) {
        if (cellSet.contains(nb) && !visited.contains(nb) && dfs(nb)) {
          return true;
        }
      }
    }
    visited.remove(cur);
    result.removeLast();
    return false;
  }

  dfs(ep0);
  return result;
}

/// Drag flow [f] from its first endpoint along its solution path to the other.
///
/// The gesture origin is backed off into the endpoint cell, OPPOSITE the first
/// step's direction, so the pan recognizer crosses kTouchSlop while the pointer
/// is still inside the endpoint cell — otherwise onPanStart can land on the
/// next cell (which sets no active flow) on boards whose cells are smaller than
/// the slop radius (small phones, 9x9). Each segment is then walked in sub-cell
/// steps so every cell registers an onPanUpdate.
Future<void> _dragFlow(
    WidgetTester tester, gen.ColorConnectLevelResult p, int f) async {
  final path = _orderedPath(p, f);
  if (path.length < 2) return;
  final cs = _cellSize(tester, p);
  final c0 = _cellCenter(tester, p, path.first);
  final c1 = _cellCenter(tester, p, path[1]);
  final delta = c1 - c0;
  final unit = delta / delta.distance;
  final startPt = c0 - unit * (cs * 0.42);

  final g = await tester.startGesture(startPt);
  var prev = startPt;
  for (int i = 0; i < path.length; i++) {
    final wp = _cellCenter(tester, p, path[i]);
    const sub = 4;
    for (int s = 1; s <= sub; s++) {
      await g.moveTo(Offset.lerp(prev, wp, s / sub)!);
    }
    prev = wp;
  }
  await g.up();
}

/// Drive the board to a win by dragging every flow along its solution path.
Future<void> _solveByDrag(
    WidgetTester tester, gen.ColorConnectLevelResult p) async {
  for (int f = 0; f < p.numFlows; f++) {
    await _dragFlow(tester, p, f);
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  group('Color Connect registry', () {
    test('is registered with correct metadata', () {
      final info = GameRegistry.getById(_gameId);
      expect(info, isNotNull);
      expect(info!.name, 'Color Connect');
      expect(info.category, GameCategory.puzzle);
      expect(info.howToPlay, isNotEmpty);
    });
  });

  group('Color Connect picker', () {
    for (final device in allTestDevices) {
      group('${device.name} (${device.width}x${device.height})', () {
        setUp(() async => initGameTest());

        testWidgets('renders picker without overflow', (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          expect(find.text('Color Connect'), findsWidgets);
          expect(find.text('Play Color Connect'), findsOneWidget);
          expectNoOverflow(device, 'Color Connect picker');
          cleanUp(tester);
        });

        testWidgets('default difficulty is MEDIUM', (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          expect(find.text('MEDIUM'), findsOneWidget);
          cleanUp(tester);
        });

        testWidgets('play button starts the game', (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          await selectAndPlay(tester, 0, 'Play Color Connect');
          expect(find.byType(SpinningSlider), findsNothing,
              reason: 'should have left the picker');
          expect(find.text('LEVEL'), findsOneWidget);
          expectNoOverflow(device, 'Color Connect playing');
          cleanUp(tester);
        });
      });
    }
  });

  group('Color Connect gameplay per difficulty', () {
    for (final device in allTestDevices) {
      for (int stop = 0; stop < 3; stop++) {
        final diff = const ['Easy', 'Medium', 'Hard'][stop];
        group('$diff on ${device.name}', () {
          setUp(() async => initGameTest());

          testWidgets('renders board without overflow', (tester) async {
            await pumpScreen(tester, device, _build(), settle: false);
            await selectAndPlay(tester, stop, 'Play Color Connect');
            expect(find.text('LEVEL'), findsOneWidget);
            expect(find.byKey(const Key('cc_grid')), findsOneWidget);
            await tester.pump(const Duration(milliseconds: 400));
            expectNoOverflow(device, 'Color Connect $diff');
            cleanUp(tester);
          });
        });
      }
    }
  });

  // Solve a real board end-to-end on a representative device spread (tightest
  // phones + a mid phone + a large tablet, both platforms) — exercising drag
  // routing, the win check, and the level-complete overlay without overflow.
  group('Color Connect win flow', () {
    const winDevices = [
      TestDevice(name: 'Small Android', width: 320, height: 568, pixelRatio: 2.0, platform: TargetPlatform.android),
      TestDevice(name: 'iPhone SE', width: 320, height: 568, pixelRatio: 2.0, platform: TargetPlatform.iOS),
      TestDevice(name: 'iPhone 13/14', width: 390, height: 844, pixelRatio: 3.0, platform: TargetPlatform.iOS),
      TestDevice(name: 'iPad Pro', width: 1024, height: 1366, pixelRatio: 2.0, platform: TargetPlatform.iOS),
    ];

    for (final device in winDevices) {
      for (int stop = 0; stop < 3; stop++) {
        final diff = const ['Easy', 'Medium', 'Hard'][stop];
        final subKey = const ['easy', 'medium', 'hard'][stop];
        testWidgets('solving a $diff board wins without overflow on '
            '${device.name}', (tester) async {
          await initGameTest(extra: {levelCurrentKey(_gameId, subKey): 1});
          await pumpScreen(tester, device, _build(), settle: false);
          await selectAndPlay(tester, stop, 'Play Color Connect');
          expect(find.text('LEVEL'), findsOneWidget);

          final puzzle = gen.generateColorConnectLevel(1, stop);
          await _solveByDrag(tester, puzzle);
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(LevelCompleteOverlay), findsOneWidget,
              reason: 'solving the board should trigger the win overlay');
          expectNoOverflow(device, 'Color Connect $diff win');
          cleanUp(tester);
        });
      }
    }
  });

  group('Color Connect interaction', () {
    const device = TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android);

    testWidgets('dragging one flow marks it complete in the progress row',
        (tester) async {
      await initGameTest(extra: {levelCurrentKey(_gameId, 'easy'): 1});
      await pumpScreen(tester, device, _build(), settle: false);
      await selectAndPlay(tester, 0, 'Play Color Connect');

      final puzzle = gen.generateColorConnectLevel(1, 0);
      // Initially no flows connected.
      expect(find.text('0/${puzzle.numFlows}'), findsOneWidget);

      // Connect exactly one flow.
      await _dragFlow(tester, puzzle, 0);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('1/${puzzle.numFlows}'), findsOneWidget,
          reason: 'connecting one flow should advance the completed count');
      expectNoOverflow(device, 'Color Connect interaction');
      cleanUp(tester);
    });

    testWidgets('backtracking over a path shortens it again', (tester) async {
      await initGameTest(extra: {levelCurrentKey(_gameId, 'easy'): 1});
      await pumpScreen(tester, device, _build(), settle: false);
      await selectAndPlay(tester, 0, 'Play Color Connect');

      final puzzle = gen.generateColorConnectLevel(1, 0);
      // Complete a flow, then drag it again only partway — it should no longer
      // be counted complete (the path was shortened by re-routing).
      await _dragFlow(tester, puzzle, 0);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('1/${puzzle.numFlows}'), findsOneWidget);

      final path = _orderedPath(puzzle, 0);
      final cs = _cellSize(tester, puzzle);
      final c0 = _cellCenter(tester, puzzle, path.first);
      final c1 = _cellCenter(tester, puzzle, path[1]);
      final unit = (c1 - c0) / (c1 - c0).distance;
      final g = await tester.startGesture(c0 - unit * (cs * 0.42));
      // Re-grab the endpoint only (resets the path to a single cell).
      await g.moveTo(Offset.lerp(c0 - unit * (cs * 0.42), c0, 0.5)!);
      await g.moveTo(c0);
      await g.up();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('0/${puzzle.numFlows}'), findsOneWidget,
          reason: 're-grabbing the endpoint should reset that flow');
      expectNoOverflow(device, 'Color Connect backtrack');
      cleanUp(tester);
    });
  });

  group('Color Connect dynamic states', () {
    const tightDevices = [
      TestDevice(name: 'Small Android', width: 320, height: 568, pixelRatio: 2.0, platform: TargetPlatform.android),
      TestDevice(name: 'iPhone SE', width: 320, height: 568, pixelRatio: 2.0, platform: TargetPlatform.iOS),
    ];

    for (final device in tightDevices) {
      group(device.name, () {
        setUp(() async => initGameTest());

        testWidgets('hint nudge renders without overflow', (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          await selectAndPlay(tester, 0, 'Play Color Connect');
          expect(find.text('HINT'), findsOneWidget);
          await tester.tap(find.text('HINT'), warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 300));
          expectNoOverflow(device, 'Color Connect hint');
          cleanUp(tester);
        });

        testWidgets('idle nudge appears without overflow', (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          await selectAndPlay(tester, 0, 'Play Color Connect');
          await tester.pump(const Duration(seconds: 11));
          expect(find.text('Stuck? Try a hint!'), findsOneWidget);
          expectNoOverflow(device, 'Color Connect idle nudge');
          cleanUp(tester);
        });
      });
    }
  });

  group('Color Connect pause overlay', () {
    const device = TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android);

    testWidgets('pause shows resume/restart/quit', (tester) async {
      await initGameTest();
      await pumpScreen(tester, device, _build(), settle: false);
      final wrapperState = tester.state<GameWrapperState>(find.byType(GameWrapper));
      wrapperState.startGame();
      await tester.pump(const Duration(milliseconds: 300));
      wrapperState.pauseGame();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Quit'), findsOneWidget);
      expectNoOverflow(device, 'Color Connect pause');
      await tester.pump(const Duration(seconds: 5));
      cleanUp(tester);
    });
  });
}
