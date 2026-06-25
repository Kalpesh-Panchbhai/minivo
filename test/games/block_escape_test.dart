import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/games/game_registry.dart';
import '../../lib/games/game_wrapper.dart';
import '../../lib/games/block_escape/block_escape_level_gen.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

const _gameId = 'block_escape';

const _device = TestDevice(
  name: 'Pixel 6',
  width: 412,
  height: 915,
  pixelRatio: 2.625,
  platform: TargetPlatform.android,
);

Widget _build() =>
    GameWrapper(gameId: _gameId, child: GameRegistry.buildGame(_gameId));

void main() {
  group('Block Escape — registry', () {
    test('is registered with correct metadata', () {
      expect(GameRegistry.hasGame(_gameId), isTrue);
      final info = GameRegistry.getById(_gameId)!;
      expect(info.name, 'Block Escape');
      expect(info.howToPlay.isNotEmpty, isTrue);
      expect(info.category, isNotNull);
    });
  });

  group('Block Escape — level gen', () {
    test('generated level has target block', () {
      for (int diff = 0; diff < 3; diff++) {
        for (final level in const [1, 2, 50, 100]) {
          final p = generateBlockEscapeLevel(level, diff);
          final targets = p.blocks.where((b) => b.isTarget);
          expect(targets.length, 1, reason: 'diff $diff level $level: exactly one target');
        }
      }
    });

    test('target block is horizontal', () {
      for (int diff = 0; diff < 3; diff++) {
        final p = generateBlockEscapeLevel(1, diff);
        final target = p.blocks.firstWhere((b) => b.isTarget);
        expect(target.dir, BlockDir.horizontal);
      }
    });

    test('target block is on the exit row', () {
      for (int diff = 0; diff < 3; diff++) {
        final p = generateBlockEscapeLevel(1, diff);
        final target = p.blocks.firstWhere((b) => b.isTarget);
        expect(target.row, p.exitRow);
      }
    });

    test('solution is non-empty and solvable', () {
      for (int diff = 0; diff < 3; diff++) {
        for (final level in const [1, 10, 100]) {
          final p = generateBlockEscapeLevel(level, diff);
          expect(p.solution, isNotEmpty, reason: 'diff $diff level $level should be solvable');
        }
      }
    });

    test('blocks do not overlap initially', () {
      for (int diff = 0; diff < 3; diff++) {
        final p = generateBlockEscapeLevel(1, diff);
        final occupied = <(int, int)>{};
        for (final b in p.blocks) {
          for (final cell in b.cells) {
            expect(occupied.add(cell), isTrue, reason: 'overlap at $cell in diff $diff');
          }
        }
      }
    });

    test('boards are 6x6', () {
      for (int diff = 0; diff < 3; diff++) {
        final p = generateBlockEscapeLevel(1, diff);
        expect(p.rows, 6);
        expect(p.cols, 6);
      }
    });
  });

  group('Block Escape — UI', () {
    setUp(() async => initTestDependencies());

    testWidgets('ready state shows title + play button without overflow',
        (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Block Escape'), findsWidgets);
      expect(find.text('Play Block Escape'), findsOneWidget);
      expectNoOverflow(_device, 'Block Escape ready');
      cleanUp(tester);
    });

    testWidgets('tapping play builds the board', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Block Escape'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('block_escape_board')), findsOneWidget);
      expectNoOverflow(_device, 'Block Escape board');
      cleanUp(tester);
    });

    testWidgets('restart button is present on board', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play Block Escape'));
      await tester.pump(const Duration(milliseconds: 300));
      final restart = find.byIcon(Icons.refresh_rounded);
      expect(restart, findsOneWidget);
      expectNoOverflow(_device, 'Block Escape with restart');
      cleanUp(tester);
    });
  });
}
