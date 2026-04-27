import '../models/game_info.dart';
import '../widgets/mosaic_game_tile.dart';
import 'score_service.dart';
import '../../games/game_registry.dart';

class RankedGame {
  final GameInfo game;
  final double score;
  final TileSize tileSize;

  const RankedGame({
    required this.game,
    required this.score,
    required this.tileSize,
  });
}

class GameScoreRanker {
  GameScoreRanker._();

  static List<RankedGame> rankAllGames() {
    final service = ScoreService();
    final allGames = GameRegistry.allGames;
    final recentIds = service.getRecentlyPlayed();
    final favorites = service.getFavorites();

    final maxPlayCount = allGames
        .map((g) => g.playCount)
        .fold<int>(1, (a, b) => a > b ? a : b);

    final ranked = allGames.map((game) {
      double score = 0;

      final trendNorm = game.playCount / maxPlayCount;
      score += trendNorm * 40;

      score += (game.rating / 5.0) * 10;

      final recentIndex = recentIds.indexOf(game.id);
      if (recentIndex >= 0) {
        score += 25 * (1 - recentIndex / 10);
      }

      if (favorites.contains(game.id)) {
        score += 15;
      }

      final userPlays = service.getGamePlayCount(game.id);
      if (userPlays > 0) {
        final playBonus = (userPlays.clamp(0, 20) / 20) * 10;
        score += playBonus;
      }

      score = score.clamp(0, 100);

      TileSize tileSize;
      if (score >= 65) {
        tileSize = TileSize.large;
      } else if (score >= 40) {
        tileSize = TileSize.wide;
      } else {
        tileSize = TileSize.small;
      }

      return RankedGame(game: game, score: score, tileSize: tileSize);
    }).toList();

    ranked.sort((a, b) => b.score.compareTo(a.score));

    int largeCount = ranked.where((r) => r.tileSize == TileSize.large).length;
    if (largeCount > 2) {
      for (int i = 0, found = 0; i < ranked.length; i++) {
        if (ranked[i].tileSize == TileSize.large) {
          found++;
          if (found > 2) {
            ranked[i] = RankedGame(
              game: ranked[i].game,
              score: ranked[i].score,
              tileSize: TileSize.wide,
            );
          }
        }
      }
    }

    return ranked;
  }
}
