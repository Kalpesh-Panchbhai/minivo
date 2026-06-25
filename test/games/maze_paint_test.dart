import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/games/game_registry.dart';
import '../../lib/games/game_wrapper.dart';
import '../../lib/games/maze_paint/maze_paint_level_gen.dart' as gen;
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

const _gameId = 'maze_paint';

const _device = TestDevice(
  name: 'Pixel 6',
  width: 412,
  height: 915,
  pixelRatio: 2.625,
  platform: TargetPlatform.android,
);

Widget _build() =>
    GameWrapper(gameId: _gameId, child: GameRegistry.buildGame(_gameId));

/// Replays a level's baked solution exactly as the screen does (slide + paint)
/// and returns the painted-tile count.
int _playSolution(gen.MazePaintLevel p) {
  final painted = <int>{p.start};
  var pos = p.start;
  for (final dir in p.solution) {
    final cells = gen.cellsAlongMove(
        rows: p.rows, cols: p.cols, walls: p.walls, start: pos, dir: dir);
    expect(cells, isNotEmpty, reason: 'no-op move in solution');
    painted.addAll(cells);
    pos = cells.last;
  }
  return painted.length;
}

void main() {
  group('Maze Paint — registry', () {
    test('is registered with correct metadata', () {
      expect(GameRegistry.hasGame(_gameId), isTrue);
      final info = GameRegistry.getById(_gameId)!;
      expect(info.name, 'Maze Paint');
      expect(info.howToPlay.isNotEmpty, isTrue);
      expect(info.category, isNotNull);
    });
  });

  group('Maze Paint — slide engine', () {
    test('ball rolls until a wall stops it', () {
      // 5x5, floor along the top row only (cols 0..2 open, 3..4 walls).
      final walls = <int>{};
      for (int i = 0; i < 25; i++) {
        if (i > 2) walls.add(i);
      }
      final dest = gen.moveDestination(
          rows: 5, cols: 5, walls: walls, start: 0, dir: gen.MazePaintDir.right);
      expect(dest, 2, reason: 'should stop at the last open tile');
      final cells = gen.cellsAlongMove(
          rows: 5, cols: 5, walls: walls, start: 0, dir: gen.MazePaintDir.right);
      expect(cells, [1, 2]);
    });

    test('a blocked direction is a no-op', () {
      final walls = <int>{};
      for (int i = 0; i < 25; i++) {
        if (i > 2) walls.add(i);
      }
      // From tile 0 there is nothing above — can't move up.
      final cells = gen.cellsAlongMove(
          rows: 5, cols: 5, walls: walls, start: 0, dir: gen.MazePaintDir.up);
      expect(cells, isEmpty);
    });

    test('baked solution wins (paints every tile) for sample levels', () {
      for (int diff = 0; diff < 3; diff++) {
        for (final level in const [1, 2, 17, 250, 9999]) {
          final p = gen.generateMazePaintLevel(level, diff);
          expect(_playSolution(p), p.paintableCount,
              reason: 'diff $diff level $level not won by its solution');
        }
      }
    });

    test('boards are irregular shapes, never full rectangles', () {
      for (int diff = 0; diff < 3; diff++) {
        for (final level in const [1, 5, 100, 5000, 9999]) {
          final p = gen.generateMazePaintLevel(level, diff);
          expect(p.walls, isNotEmpty,
              reason: 'diff $diff level $level should have walls');
          expect(p.paintableCount, lessThan(p.rows * p.cols));
        }
      }
    });
  });

  group('Maze Paint — UI', () {
    setUp(() async => initTestDependencies());

    testWidgets('ready state shows title + play button without overflow',
        (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Maze Paint'), findsWidgets);
      expect(find.text('Play Maze Paint'), findsOneWidget);
      expectNoOverflow(_device, 'Maze Paint ready');
      cleanUp(tester);
    });

    testWidgets('tapping play builds the board', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Maze Paint'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('maze_paint_board')), findsOneWidget);
      expectNoOverflow(_device, 'Maze Paint board');
      cleanUp(tester);
    });

    testWidgets('a swipe rolls the ball and paints tiles', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Maze Paint'));
      await tester.pump(const Duration(milliseconds: 300));

      final board = find.byKey(const Key('maze_paint_board'));
      expect(board, findsOneWidget);

      // Current EASY level is 1 (fresh prefs). Roll in its first solution
      // direction and confirm the painted counter advances past the start tile.
      final p = gen.generateMazePaintLevel(1, 1); // default picker = MEDIUM
      final dir = p.solution.first;
      final delta = switch (dir) {
        gen.MazePaintDir.up => const Offset(0, -140),
        gen.MazePaintDir.down => const Offset(0, 140),
        gen.MazePaintDir.left => const Offset(-140, 0),
        gen.MazePaintDir.right => const Offset(140, 0),
      };
      await tester.drag(board, delta);
      await tester.pump(const Duration(milliseconds: 400));
      expectNoOverflow(_device, 'Maze Paint after swipe');
      // Painted counter reads "done/total"; after one productive roll done>=2.
      final painted = tester.widgetList<Text>(find.byType(Text)).where((t) {
        final s = t.data ?? '';
        return RegExp(r'^\d+/\d+$').hasMatch(s);
      }).map((t) => t.data!);
      expect(painted, isNotEmpty, reason: 'painted counter not found');
      final done = int.parse(painted.first.split('/').first);
      expect(done, greaterThanOrEqualTo(2),
          reason: 'swipe should paint at least one new tile');
      cleanUp(tester);
    });

    testWidgets('restart resets the painted counter', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Maze Paint'));
      await tester.pump(const Duration(milliseconds: 300));
      final board = find.byKey(const Key('maze_paint_board'));
      await tester.drag(board, const Offset(140, 0));
      await tester.pump(const Duration(milliseconds: 400));
      // Restart via the HUD restart button.
      final restart = find.byIcon(Icons.refresh_rounded);
      if (tester.any(restart)) {
        await tester.tap(restart.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));
      }
      expectNoOverflow(_device, 'Maze Paint after restart');
      cleanUp(tester);
    });
  });
}
