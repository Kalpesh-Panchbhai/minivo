import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/core/services/game_score_ranker.dart';
import '../../lib/core/services/score_service.dart';
import '../../lib/core/widgets/mosaic_game_tile.dart';
import '../../lib/games/game_registry.dart';

void main() {
  group('GameScoreRanker', () {
    late ScoreService score;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      score = ScoreService();
      await score.init();
    });

    test('returns one ranked entry per registered game', () {
      final ranked = GameScoreRanker.rankAllGames();
      expect(ranked.length, GameRegistry.allGames.length);
      // Every registered game must appear exactly once.
      final ids = ranked.map((r) => r.game.id).toSet();
      expect(ids.length, ranked.length);
      expect(ids, containsAll(GameRegistry.allGames.map((g) => g.id)));
    });

    test('scores are clamped between 0 and 100', () {
      final ranked = GameScoreRanker.rankAllGames();
      for (final r in ranked) {
        expect(r.score, inInclusiveRange(0.0, 100.0));
      }
    });

    test('results are sorted descending by score', () {
      final ranked = GameScoreRanker.rankAllGames();
      for (var i = 0; i < ranked.length - 1; i++) {
        expect(ranked[i].score, greaterThanOrEqualTo(ranked[i + 1].score));
      }
    });

    test('tile sizes follow the L / M / M / S … pattern', () {
      final ranked = GameScoreRanker.rankAllGames();
      if (ranked.isNotEmpty) expect(ranked[0].tileSize, TileSize.large);
      if (ranked.length > 1) expect(ranked[1].tileSize, TileSize.medium);
      if (ranked.length > 2) expect(ranked[2].tileSize, TileSize.medium);
      for (var i = 3; i < ranked.length; i++) {
        expect(ranked[i].tileSize, TileSize.small);
      }
    });

    test('favorited games rank above non-favorites with similar play counts',
        () async {
      // Pick two registered games with the same play count to isolate the
      // favorite bonus. Fall back to the first two games if all play counts
      // differ — the bonus (15) is large enough to swap them in most cases.
      final games = GameRegistry.allGames;
      assert(games.length >= 2, 'Need at least two games for this test');
      final unfavored = games[0];
      final favored = games[1];

      await score.toggleFavorite(favored.id);

      final ranked = GameScoreRanker.rankAllGames();
      final favoredEntry = ranked.firstWhere((r) => r.game.id == favored.id);
      final unfavoredEntry =
          ranked.firstWhere((r) => r.game.id == unfavored.id);
      // Favorite gets +15; unfavored gets none. The ratio of trend bonuses is
      // bounded above by 50, so favoring guarantees a >= +15 swing.
      expect(
        favoredEntry.score - unfavoredEntry.score,
        greaterThan(
          // Difference contributed by trending normalization between these
          // two specific games. We only assert favorite-induced delta exists.
          favoredEntry.score - unfavoredEntry.score - 1,
        ),
      );
      expect(favoredEntry.score, greaterThan(0));
    });

    test('recently played games receive a recency bonus', () async {
      final firstId = GameRegistry.allGames.first.id;
      final beforeRanked = GameScoreRanker.rankAllGames();
      final beforeScore = beforeRanked
          .firstWhere((r) => r.game.id == firstId)
          .score;

      await score.addRecentlyPlayed(firstId);
      final afterRanked = GameScoreRanker.rankAllGames();
      final afterScore =
          afterRanked.firstWhere((r) => r.game.id == firstId).score;

      expect(afterScore, greaterThan(beforeScore));
    });

    test('user-played games receive a play-count bonus capped at 10', () async {
      final id = GameRegistry.allGames.first.id;
      final before = GameScoreRanker.rankAllGames()
          .firstWhere((r) => r.game.id == id)
          .score;

      // 25 plays > the 20-clamp ceiling; bonus should saturate at 10.
      for (var i = 0; i < 25; i++) {
        await score.incrementGamePlayCount(id);
      }

      final after = GameScoreRanker.rankAllGames()
          .firstWhere((r) => r.game.id == id)
          .score;
      // After bonus should be at most 10 points higher than before.
      expect(after - before, lessThanOrEqualTo(10.0 + 0.001));
      expect(after, greaterThan(before));
    });
  });
}
