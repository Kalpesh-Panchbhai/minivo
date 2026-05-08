import '../core/services/best_stats_registry.dart';
import 'all_games.dart';

/// Registers every game's stats builder with [BestStatsRegistry].
///
/// Called once at app startup. Stats are derived automatically from each
/// game's [GameDefinition]. No per-game `registerXxxStats()` calls needed.
void registerAllGameStats() {
  for (final def in allGameDefinitions) {
    BestStatsRegistry.register(def.info.id, def.buildBestStats);
  }
}
