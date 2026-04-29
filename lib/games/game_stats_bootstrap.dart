import 'number_merge/number_merge_stats.dart';
import 'tic_tac_toe/tic_tac_toe_stats.dart';

/// Single entry point for registering all per-game custom stats builders.
/// Add new games here as they ship.
///
/// Games that don't register a custom builder fall back to the default
/// high-score builder in [BestStatsRegistry].
void registerAllGameStats() {
  registerTicTacToeStats();
  registerNumberMergeStats();
}
