import 'framework/game_definition.dart';
import 'color_tap/color_tap_definition.dart';
import 'flappy_tap/flappy_tap_definition.dart';
import 'memory_match/memory_match_definition.dart';
import 'number_merge/number_merge_definition.dart';
import 'snake_classic/snake_classic_definition.dart';
import 'sudoku/sudoku_definition.dart';
import 'tic_tac_toe/tic_tac_toe_definition.dart';

export 'framework/game_definition.dart';

/// The canonical, ordered list of all games in the app.
///
/// To add a new game:
///   1. Write the game screen widget.
///   2. Write a logo builder function.
///   3. Create `my_game/my_game_definition.dart` with a [GameDefinition].
///   4. Import it here and add it to this list.
///
/// Nothing else needs to change.
final List<GameDefinition> allGameDefinitions = [
  flappyTapGame,
  numberMergeGame,
  colorTapGame,
  memoryMatchGame,
  snakeClassicGame,
  sudokuGame,
  ticTacToeGame,
];
