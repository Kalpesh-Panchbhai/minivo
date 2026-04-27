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

    final scored = allGames.map((game) {
      double score = 0;

      final trendNorm = game.playCount / maxPlayCount;
      score += trendNorm * 50;

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

      return (game: game, score: score.clamp(0.0, 100.0));
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));

    final sizes = _assignSizes(scored.length);

    return List.generate(scored.length, (i) {
      return RankedGame(
        game: scored[i].game,
        score: scored[i].score,
        tileSize: sizes[i],
      );
    });
  }

  static List<TileSize> _assignSizes(int count) {
    if (count == 0) return [];

    final result = <TileSize>[];

    for (int i = 0; i < count; i++) {
      if (i == 0) {
        result.add(TileSize.large);
      } else if (i <= 2) {
        result.add(TileSize.medium);
      } else if (i <= 4) {
        result.add(TileSize.tall);
      } else {
        const fill = [
          TileSize.wide,
          TileSize.small,
          TileSize.small,
        ];
        result.add(fill[(i - 5) % fill.length]);
      }
    }
    return result;
  }
}
