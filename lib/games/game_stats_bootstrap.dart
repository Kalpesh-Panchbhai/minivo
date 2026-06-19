import 'color_tap/color_tap_stats.dart';
import 'dots_and_boxes/dots_and_boxes_stats.dart';
import 'flappy_tap/flappy_tap_stats.dart';
import 'memory_match/memory_match_stats.dart';
import 'number_merge/number_merge_stats.dart';
import 'snake_classic/snake_classic_stats.dart';
import 'sudoku/sudoku_stats.dart';
import 'tic_tac_toe/tic_tac_toe_stats.dart';
import 'dino_run/dino_run_stats.dart';
import 'drop_merge/drop_merge_stats.dart';
import 'whack_a_mole/whack_a_mole_stats.dart';
import 'dodge_ball/dodge_ball_stats.dart';
import 'tap_tap_dash/tap_tap_dash_stats.dart';
import 'connect_four/connect_four_stats.dart';
import 'reversi/reversi_stats.dart';
import 'checkers/checkers_stats.dart';
import 'go/go_stats.dart';
import 'mancala/mancala_stats.dart';
import 'gomoku/gomoku_stats.dart';
import 'hangman/hangman_stats.dart';
import 'minesweeper/minesweeper_stats.dart';
import 'solitaire/solitaire_stats.dart';
import 'sliding_puzzle/sliding_puzzle_stats.dart';
import 'number_sequence/number_sequence_stats.dart';
import 'water_sort/water_sort_stats.dart';
import 'arrow_puzzle/arrow_puzzle_stats.dart';
import 'zip/zip_stats.dart';
import 'queens_puzzle/queens_puzzle_stats.dart';

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
  registerDropMergeStats();
  registerDinoRunStats();
  registerWhackAMoleStats();
  registerDodgeBallStats();
  registerTapTapDashStats();
  registerConnectFourStats();
  registerReversiStats();
  registerCheckersStats();
  registerGoStats();
  registerMancalaStats();
  registerGomokuStats();
  registerHangmanStats();
  registerMinesweeperStats();
  registerSolitaireStats();
  registerSlidingPuzzleStats();
  registerNumberSequenceStats();
  registerWaterSortStats();
  registerArrowPuzzleStats();
  registerZipStats();
  registerQueensPuzzleStats();
}
