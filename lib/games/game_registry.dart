import 'package:flutter/material.dart';
import '../core/models/game_info.dart';
import 'all_games.dart';

typedef GameWidgetBuilder = Widget Function();

class GameRegistry {
  GameRegistry._();

  static final Map<String, GameDefinition> _defMap = {
    for (final d in allGameDefinitions) d.info.id: d,
  };

  static Widget buildGame(String gameId) {
    final def = _defMap[gameId];
    if (def == null) return const Center(child: Text('Game not found'));
    return def.screenBuilder();
  }

  static bool hasGame(String gameId) => _defMap.containsKey(gameId);

  /// All current games use custom overlays — returns true for any registered id.
  static bool usesCustomOverlays(String gameId) => _defMap.containsKey(gameId);

  static List<GameInfo> get allGames =>
      allGameDefinitions.map((d) => d.info).toList();

  static GameInfo? getById(String id) => _defMap[id]?.info;

  static GameDefinition? getDefinition(String id) => _defMap[id];

  static List<GameInfo> getByCategory(GameCategory category) =>
      allGames.where((g) => g.category == category).toList();

  static List<GameInfo> get featured =>
      allGames.where((g) => g.isFeatured).toList();

  static List<GameInfo> get trending {
    final sorted = List<GameInfo>.from(allGames);
    sorted.sort((a, b) => b.playCount.compareTo(a.playCount));
    return sorted;
  }

  static List<GameInfo> search(String query) {
    final q = query.toLowerCase();
    return allGames
        .where((g) =>
            g.name.toLowerCase().contains(q) ||
            g.category.label.toLowerCase().contains(q) ||
            g.description.toLowerCase().contains(q))
        .toList();
  }
}
