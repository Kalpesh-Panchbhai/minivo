import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/core/models/best_stat.dart';
import '../../lib/core/services/best_stats_registry.dart';
import '../../lib/core/services/score_service.dart';
import '../../lib/games/tic_tac_toe/tic_tac_toe_stats.dart';

void main() {
  group('BestStatsRegistry', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ScoreService().init();
      // Each test starts with a clean registry to avoid cross-test pollution.
      BestStatsRegistry.unregister(kTicTacToeGameId);
      BestStatsRegistry.unregister('flappy_tap');
    });

    test('default builder returns empty when high score is 0', () {
      expect(BestStatsRegistry.statsFor('flappy_tap'), isEmpty);
    });

    test('default builder returns one BEST row when high score > 0',
        () async {
      await ScoreService().saveScore('flappy_tap', 42);
      final stats = BestStatsRegistry.statsFor('flappy_tap');
      expect(stats, hasLength(1));
      expect(stats.first.label, 'BEST');
      expect(stats.first.value, '42');
    });

    test('custom builder overrides the default', () {
      BestStatsRegistry.register('flappy_tap', () {
        return [
          const BestStat(label: 'STREAK', value: '5'),
        ];
      });
      final stats = BestStatsRegistry.statsFor('flappy_tap');
      expect(stats, hasLength(1));
      expect(stats.first.label, 'STREAK');
    });

    test('unregister falls back to default builder', () async {
      BestStatsRegistry.register(
        'flappy_tap',
        () => const [BestStat(label: 'X', value: '1')],
      );
      BestStatsRegistry.unregister('flappy_tap');

      // Default returns empty when no high score exists.
      expect(BestStatsRegistry.statsFor('flappy_tap'), isEmpty);
    });

    group('Tic Tac Toe builder', () {
      setUp(() {
        registerTicTacToeStats();
      });

      test('returns empty until at least one win is persisted', () {
        expect(BestStatsRegistry.statsFor(kTicTacToeGameId), isEmpty);
      });

      test('returns one row per difficulty once any best is set',
          () async {
        await ScoreService().saveScore(
          kTicTacToeGameId,
          1,
          subKey: kTicTacToeSubKeyEasy,
        );

        final stats = BestStatsRegistry.statsFor(kTicTacToeGameId);
        expect(stats, hasLength(3));
        expect(stats[0].label, contains('EASY'));
        expect(stats[1].label, contains('MEDIUM'));
        expect(stats[2].label, contains('HARD'));
      });

      test('row value reflects the best streak; em-dash for unset', () async {
        await ScoreService().saveScore(
          kTicTacToeGameId,
          4,
          subKey: kTicTacToeSubKeyMedium,
        );

        final stats = BestStatsRegistry.statsFor(kTicTacToeGameId);
        // Easy is unset → em-dash placeholder.
        expect(stats[0].value, '—');
        expect(stats[0].sublabel, 'no wins yet');
        // Medium has a 4-streak.
        expect(stats[1].value, '4');
        expect(stats[1].sublabel, 'win streak');
      });

      test('rows have a non-null colour', () async {
        await ScoreService().saveScore(
          kTicTacToeGameId,
          1,
          subKey: kTicTacToeSubKeyEasy,
        );
        for (final s in BestStatsRegistry.statsFor(kTicTacToeGameId)) {
          expect(s.color, isA<Color>());
        }
      });
    });
  });
}
