import 'color_tap/color_tap_stats.dart';
import 'dots_and_boxes/dots_and_boxes_stats.dart';
import 'flappy_tap/flappy_tap_stats.dart';
import 'memory_match/memory_match_stats.dart';
import 'number_merge/number_merge_stats.dart';
import 'snake_classic/snake_classic_stats.dart';
import 'sudoku/sudoku_stats.dart';
import 'tic_tac_toe/tic_tac_toe_stats.dart';
import 'tile_drop/tile_drop_stats.dart';

/// Single entry point for registering all per-game custom stats builders.
/// Add new games here as they ship.
///
/// Games that don't register a custom builder fall back to the default
/// high-score builder in [BestStatsRegistry].
void registerAllGameStats() {
  registerColorTapStats();
  registerDotsAndBoxesStats();
  registerMemoryMatchStats();
  registerSudokuStats();
  registerTicTacToeStats();
  registerNumberMergeStats();
  registerSnakeClassicStats();
  registerFlappyTapStats();
  registerTileDropStats();
}
