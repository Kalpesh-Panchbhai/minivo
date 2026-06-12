import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/core/services/level_progress_service.dart';
import '../../lib/core/services/score_service.dart';
import '../../lib/games/game_registry.dart';
import '../../lib/games/game_wrapper.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

const _device = TestDevice(
  name: 'Pixel 6',
  width: 412,
  height: 915,
  pixelRatio: 2.625,
  platform: TargetPlatform.android,
);

Widget _build() => GameWrapper(
      gameId: 'nuts_and_bolts',
      child: GameRegistry.buildGame('nuts_and_bolts'),
    );

const _difficulties = ['easy', 'medium', 'hard'];
const _diffLabels = ['EASY', 'MEDIUM', 'HARD'];

class _BoltLevelParams {
  final int numColors;
  final int nutsPerBolt;
  final int emptyBolts;
  int get numBolts => numColors + emptyBolts;
  const _BoltLevelParams({required this.numColors, required this.nutsPerBolt, required this.emptyBolts});
}

_BoltLevelParams _rollBoltParams(int diffIndex, math.Random rng) {
  switch (diffIndex) {
    case 0:
      final colors = 3 + rng.nextInt(2);
      final npb = 2 + rng.nextInt(3);
      final empty = 2 + rng.nextInt(2);
      return _BoltLevelParams(numColors: colors, nutsPerBolt: npb, emptyBolts: empty);
    case 1:
      final colors = 4 + rng.nextInt(3);
      final npb = 3 + rng.nextInt(3);
      final empty = 2;
      return _BoltLevelParams(numColors: colors, nutsPerBolt: npb, emptyBolts: empty);
    default:
      final colors = 6 + rng.nextInt(3);
      final npb = 4 + rng.nextInt(3);
      final empty = 2;
      return _BoltLevelParams(numColors: colors, nutsPerBolt: npb, emptyBolts: empty);
  }
}

bool _boltsFitScreen(int boltCount, int nutsPerBolt, double screenW) {
  const boltSlotW = 66.0;
  const extraBtnW = 40.0;
  const padding = 24.0;
  final availW = screenW - padding;
  final effectiveW = availW - extraBtnW;
  final maxPerRow = (effectiveW / boltSlotW).floor().clamp(1, boltCount);
  final rowWidth = maxPerRow * boltSlotW + extraBtnW;
  return rowWidth <= availW;
}

void main() {
  group('Nuts & Bolts', () {
    setUp(() async => initTestDependencies());

    testWidgets('registry metadata is correct', (_) async {
      final game = GameRegistry.getById('nuts_and_bolts')!;
      expect(game.id, 'nuts_and_bolts');
      expect(game.name.isNotEmpty, isTrue);
      expect(game.howToPlay.isNotEmpty, isTrue);
      expect(game.category, isNotNull);
    });

    testWidgets('ready state shows picker with title', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Nuts & Bolts'), findsWidgets);
      expect(find.text('Play Nuts & Bolts'), findsOneWidget);
      expectNoOverflow(_device, 'Nuts & Bolts ready');
      cleanUp(tester);
    });

    testWidgets('difficulty picker shows default MEDIUM label', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('MEDIUM'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('play button renders without overflow', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Play Nuts & Bolts'), findsOneWidget);
      expectNoOverflow(_device, 'Nuts & Bolts play button');
      cleanUp(tester);
    });

    testWidgets('pause overlay shows correct elements', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      final wrapperState = tester.state<GameWrapperState>(find.byType(GameWrapper));
      wrapperState.startGame();
      await tester.pump(const Duration(milliseconds: 300));
      wrapperState.pauseGame();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Quit'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
      expect(find.byIcon(Icons.refresh_rounded), findsWidgets);
      expect(find.byIcon(Icons.home_rounded), findsWidgets);
      await tester.pump(const Duration(seconds: 5));
      cleanUp(tester);
    });
  });

  for (int di = 0; di < _difficulties.length; di++) {
    final diffKey = _difficulties[di];
    final diffLabel = _diffLabels[di];
    for (int level = 1; level <= 20; level++) {
      for (final device in allTestDevices) {
        testWidgets(
          'Nuts & Bolts $diffLabel L$level ${device.name} no overflow',
          (tester) async {
            SharedPreferences.setMockInitialValues({
              'level_nuts_and_bolts_${diffKey}_current': level,
              'tutorial_seen_nuts_and_bolts': true,
            });
            await ScoreService().init();
            await LevelProgressService().init();
            await pumpScreen(tester, device, _build(), settle: false);
            final picker = find.text(diffLabel);
            if (tester.any(picker)) {
              await tester.tap(picker, warnIfMissed: false);
              await tester.pump(const Duration(milliseconds: 100));
            }
            await tester.tap(find.text('Play Nuts & Bolts'), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 300));
            expectNoOverflow(device, 'Nuts & Bolts $diffLabel L$level');
            await tester.pump(const Duration(seconds: 1));
            cleanUp(tester);
          },
        );
      }
    }
  }

  group('Nuts & Bolts 1 lakh level layout validation', () {
    for (int di = 0; di < _difficulties.length; di++) {
      final diffLabel = _diffLabels[di];
      test('$diffLabel: levels 1-100000 fit all screen sizes', () {
        final failures = <String>[];
        for (int level = 1; level <= 100000; level++) {
          final rng = math.Random(level * 1000 + di * 100);
          final params = _rollBoltParams(di, rng);
          for (final device in allTestDevices) {
            if (!_boltsFitScreen(params.numBolts, params.nutsPerBolt, device.width)) {
              failures.add('$diffLabel L$level ${device.name}: ${params.numBolts} bolts overflow ${device.width}px');
            }
          }
        }
        expect(failures, isEmpty, reason: '${failures.length} levels overflow:\n${failures.take(20).join('\n')}');
      });
    }
  });
}
