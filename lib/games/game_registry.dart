import 'package:flutter/material.dart';
import '../core/models/game_info.dart';
import 'color_tap/color_tap_logo.dart';
import 'color_tap/color_tap_screen.dart';
import 'flappy_tap/flappy_tap_logo.dart';
import 'flappy_tap/flappy_tap_screen.dart';
import 'memory_match/memory_match_logo.dart';
import 'memory_match/memory_match_screen.dart';
import 'number_merge/number_merge_logo.dart';
import 'number_merge/number_merge_screen.dart';
import 'snake_classic/snake_classic_logo.dart';
import 'snake_classic/snake_classic_screen.dart';
import 'sudoku/sudoku_logo.dart';
import 'sudoku/sudoku_screen.dart';
import 'dots_and_boxes/dots_and_boxes_logo.dart';
import 'dots_and_boxes/dots_and_boxes_screen.dart';
import 'tic_tac_toe/tic_tac_toe_logo.dart';
import 'tic_tac_toe/tic_tac_toe_screen.dart';
import 'dino_run/dino_run_logo.dart';
import 'dino_run/dino_run_screen.dart';
import 'drop_merge/drop_merge_logo.dart';
import 'drop_merge/drop_merge_screen.dart';
import 'whack_a_mole/whack_a_mole_logo.dart';
import 'whack_a_mole/whack_a_mole_screen.dart';
import 'dodge_ball/dodge_ball_logo.dart';
import 'dodge_ball/dodge_ball_screen.dart';
import 'tap_tap_dash/tap_tap_dash_logo.dart';
import 'tap_tap_dash/tap_tap_dash_screen.dart';
import 'connect_four/connect_four_logo.dart';
import 'connect_four/connect_four_screen.dart';
import 'reversi/reversi_logo.dart';
import 'reversi/reversi_screen.dart';
import 'checkers/checkers_logo.dart';
import 'checkers/checkers_screen.dart';
import 'go/go_logo.dart';
import 'go/go_screen.dart';
import 'mancala/mancala_logo.dart';
import 'mancala/mancala_screen.dart';
import 'gomoku/gomoku_logo.dart';
import 'gomoku/gomoku_screen.dart';
import 'hangman/hangman_logo.dart';
import 'hangman/hangman_screen.dart';

typedef GameWidgetBuilder = Widget Function();

class GameRegistry {
  GameRegistry._();

  static final Map<String, GameWidgetBuilder> _builders = {
    'color_tap': () => const ColorTapScreen(),
    'dino_run': () => const DinoRunScreen(),
    'dots_and_boxes': () => const DotsAndBoxesScreen(),
    'flappy_tap': () => const FlappyTapScreen(),
    'memory_match': () => const MemoryMatchScreen(),
    'number_merge': () => const NumberMergeScreen(),
    'snake_classic': () => const SnakeClassicScreen(),
    'sudoku': () => const SudokuScreen(),
    'tic_tac_toe': () => const TicTacToeScreen(),
    'drop_merge': () => const DropMergeScreen(),
    'whack_a_mole': () => const WhackAMoleScreen(),
    'dodge_ball': () => const DodgeBallScreen(),
    'tap_tap_dash': () => const TapTapDashScreen(),
    'connect_four': () => const ConnectFourScreen(),
    'reversi': () => const ReversiScreen(),
    'checkers': () => const CheckersScreen(),
    'go': () => const GoScreen(),
    'mancala': () => const MancalaScreen(),
    'gomoku': () => const GomokuScreen(),
    'hangman': () => const HangmanScreen(),
  };

  static Widget buildGame(String gameId) {
    final builder = _builders[gameId];
    if (builder == null) {
      return const Center(child: Text('Game not found'));
    }
    return builder();
  }

  static bool hasGame(String gameId) => _builders.containsKey(gameId);

  static final List<GameInfo> allGames = [
    const GameInfo(
      id: 'dots_and_boxes',
      name: 'Dots & Boxes',
      description: 'Draw lines, complete boxes, outsmart your opponent!',
      howToPlay:
          'Choose your difficulty (Easy = 4×4, Medium = 5×5, Hard = 6×6 boxes).\n'
          'Players take turns drawing a single line between two adjacent dots.\n'
          'Complete the 4th side of a box to claim it — it fills with your color.\n'
          'Claiming a box earns you another turn — chain multiple boxes for big scores!\n'
          'When all boxes are filled, the player with the most boxes wins.\n'
          'Plan ahead — avoid setting up chains your opponent can exploit!',
      category: GameCategory.board,
      icon: Icons.grid_4x4_rounded,
      color: Color(0xFF339AF0),
      bgColor: Color(0xFFD0EBFF),
      playCount: 3200,
      customLogo: buildDotsAndBoxesLogo,
    ),
    const GameInfo(
      id: 'flappy_tap',
      name: 'Flappy Tap',
      description: 'Tap to fly through the gaps. How far can you go? Simple yet addictive!',
      howToPlay:
          'Choose your difficulty (Easy, Medium, Hard) — pipe speed and gap size scale with the level.\n'
          'Tap anywhere on the screen to make the bird flap upward.\n'
          'Gravity pulls the bird down continuously — tap rhythmically to stay in the air.\n'
          'Fly through the gaps between the green pipes to score points (5/10/20 pts per pipe on Easy/Medium/Hard).\n'
          'The game ends if the bird hits a pipe or the ground.\n'
          'Stay calm and find your rhythm — panic-tapping makes you overshoot!',
      category: GameCategory.action,
      icon: Icons.air_rounded,
      color: Color(0xFF4ECDC4),
      bgColor: Color(0xFFE8FAF8),
      playCount: 12500,
      isFeatured: true,
      customLogo: buildFlappyTapLogo,
    ),
    const GameInfo(
      id: 'number_merge',
      name: '2048 Merge',
      description: 'Slide tiles and merge numbers. Can you reach 2048?',
      howToPlay:
          'Swipe left, right, up, or down to slide all tiles on the board.\n'
          'When two tiles with the same number collide, they merge into one tile worth double the value.\n'
          'Every swipe spawns a new tile (usually a 2, occasionally a 4).\n'
          'Reach the target tile for your chosen difficulty — 1024 on Easy, 2048 on Medium, 4096 on Hard.\n'
          'The game ends when the board is full and no moves remain.\n'
          'Plan your moves — avoid cornering your highest tile!',
      category: GameCategory.puzzle,
      icon: Icons.calculate_rounded,
      color: Color(0xFFFF6B6B),
      bgColor: Color(0xFFFFF0F0),

      playCount: 18200,
      isFeatured: true,
      customLogo: build2048Logo,
    ),
    const GameInfo(
      id: 'color_tap',
      name: 'Color Tap',
      description: 'Match the color circle to the target. Tap fast, skip smart — 3 lives!',
      howToPlay:
          'Choose your difficulty (Easy, Medium, Hard) — more colors and faster rounds at higher levels.\n'
          'A large colored circle appears in the center. The "TARGET" color is shown at the top.\n'
          'TAP the circle if its color matches the target to score points.\n'
          'Tap the SKIP button if the colors do NOT match to safely advance.\n'
          'Wrong action (tap a non-match, or skip a match, or let the timer run out) costs one life.\n'
          'You have 3 lives — game ends when all lives are lost.',
      category: GameCategory.arcade,
      icon: Icons.circle_rounded,
      color: Color(0xFFFF6B35),
      bgColor: Color(0xFFFFDEC0),
      playCount: 7600,
      customLogo: buildColorTapLogo,
    ),
    const GameInfo(
      id: 'memory_match',
      name: 'Memory Match',
      description: 'Flip cards and find matching emoji pairs. Train your memory!',
      howToPlay:
          'Choose your difficulty (Easy = 4×3, Medium = 4×4, Hard = 6×4).\n'
          'All cards start face-down. Tap any card to flip it over and reveal the emoji.\n'
          'Tap a second card — if the emojis match, both cards stay face-up and you score points.\n'
          'If they don\'t match, both cards flip back face-down after a short delay.\n'
          'First-attempt matches score +20 pts; later matches score +10 pts.\n'
          'Match all pairs to win a +50 completion bonus!\n'
          'Remember the positions — the fewer wrong flips, the higher your score.',
      category: GameCategory.puzzle,
      icon: Icons.flip_rounded,
      color: Color(0xFF339AF0),
      bgColor: Color(0xFFD0E8FF),
      playCount: 5400,
      customLogo: buildMemoryMatchLogo,
    ),
    const GameInfo(
      id: 'snake_classic',
      name: 'Snake Classic',
      description: 'Guide the snake to eat apples and grow longer. How long can you survive?',
      howToPlay:
          'Choose your difficulty (Easy, Medium, Hard) — speed and points scale with the level.\n'
          'Swipe up, down, left, or right to steer the snake. The snake moves on its own; you only choose direction.\n'
          'You can\'t reverse 180° — pivot through a perpendicular turn first.\n'
          'Eat the red apple to grow longer and score 5/10/20 points (Easy/Medium/Hard).\n'
          'The game ends if the snake hits a wall or runs into its own body.\n'
          'Plan your turns — fast modes punish hesitation!',
      category: GameCategory.action,
      icon: Icons.pest_control_rounded,
      color: Color(0xFF20C997),
      bgColor: Color(0xFFE6FCF5),
      playCount: 11000,
      isFeatured: true,
      customLogo: buildSnakeLogo,
    ),
    const GameInfo(
      id: 'sudoku',
      name: 'Sudoku',
      description: 'Fill the 9×9 grid — every row, column and box must contain 1–9.',
      howToPlay:
        'Choose Easy (46 givens), Medium (36 givens), or Hard (28 givens).\n'
        'Tap a cell to select it, then tap a number on the keypad to fill it in.\n'
        'Every row, column, and 3×3 box must contain each digit from 1 to 9 exactly once.\n'
        'Tapping a number that conflicts with the rules counts as an error.\n'
        'Your score is based on completion time — faster is better!\n'
        'Tap the eraser to clear a cell.',
      category: GameCategory.puzzle,
      icon: Icons.grid_on_rounded,
      color: Color(0xFF6366F1),
      bgColor: Color(0xFFEEF2FF),
      playCount: 0,
      isFeatured: false,
      customLogo: buildSudokuLogo,
    ),
    const GameInfo(
      id: 'tic_tac_toe',
      name: 'Tic Tac Toe',
      description: 'Classic X and O. Play against the computer!',
      howToPlay:
          'Choose your difficulty (Easy, Medium, Hard) or play with a friend on the same device.\n'
          'Players take turns — X always goes first in any given round.\n'
          'Tap an empty cell on the 3x3 grid to place your mark there.\n'
          'Get three of your marks in a row, column, or diagonal to win the round.\n'
          'Win two rounds in a row to start a Streak — keep it going for bragging rights!\n'
          'After each round the starter alternates, so you both get a fair go.',
      category: GameCategory.board,
      icon: Icons.close_rounded,
      color: Color(0xFFBE4BDB),
      bgColor: Color(0xFFF8F0FC),
      playCount: 8900,
      customLogo: buildTicTacToeLogo,
    ),
    const GameInfo(
      id: 'drop_merge',
      name: 'Drop Merge',
      description: 'Drop tiles, merge numbers, chain reactions — how high can you score?',
      howToPlay:
          'Choose your difficulty (Easy, Medium, Hard) — harder levels introduce bigger tiles sooner.\n'
          'A tile is shown at the top — tap any column on the board to drop it there.\n'
          'Tiles stack from the bottom. When two identical tiles touch (vertically or horizontally), they merge into double the value!\n'
          'Merges trigger gravity, which can cause chain reactions — each extra chain adds a ×0.5 score bonus.\n'
          'The game ends when every column is full and the next tile cannot merge with any top cell.\n'
          'Think ahead — dropping into a column that sets off a chain is the key to big scores!',
      category: GameCategory.puzzle,
      icon: Icons.view_column_rounded,
      color: Color(0xFFFF922B),
      bgColor: Color(0xFFFFF3D9),
      playCount: 0,
      customLogo: buildDropMergeLogo,
    ),
    const GameInfo(
      id: 'dino_run',
      name: 'Dino Run',
      description: 'Run through the desert — jump over cacti and survive!',
      howToPlay:
          'Choose your difficulty (Easy, Medium, Hard) — speed ramp and gap timing differ by level.\n'
          'The dino runs automatically. Tap the screen to jump over cacti.\n'
          'Speed increases the longer you survive — stay alert!\n'
          'Every 100 points the landscape switches between day and night.\n'
          'The game ends if you hit any obstacle. How far can you go?',
      category: GameCategory.action,
      icon: Icons.directions_run_rounded,
      color: Color(0xFF535353),
      bgColor: Color(0xFFF7F7F7),
      playCount: 0,
      isFeatured: false,
      customLogo: buildDinoRunLogo,
    ),
    const GameInfo(
      id: 'whack_a_mole',
      name: 'Whack-a-Mole',
      description: 'Moles pop up — whack them fast! Avoid the bombs!',
      howToPlay:
          'Choose your difficulty (Easy = 45s, Medium = 35s, Hard = 25s).\n'
          'Moles pop up randomly from the 3×3 grid of holes.\n'
          'Tap a mole to whack it and earn points (10/15/20 per mole on Easy/Medium/Hard).\n'
          'Golden moles are rare and fast — they\'re worth 25 bonus points!\n'
          'Bombs cost you 15 points and 3 seconds — don\'t tap them!\n'
          'Build combos by whacking consecutive moles for bonus streaks.\n'
          'Moles speed up as time passes — stay focused!',
      category: GameCategory.arcade,
      icon: Icons.pest_control_rounded,
      color: Color(0xFF66BB6A),
      bgColor: Color(0xFFE8F5E9),
      playCount: 0,
      customLogo: buildWhackAMoleLogo,
    ),
    const GameInfo(
      id: 'dodge_ball',
      name: 'Dodge Ball',
      description: 'Dodge falling obstacles — drag left and right to survive!',
      howToPlay:
          'Choose your difficulty (Easy, Medium, Hard) — speed and obstacle count scale with the level.\n'
          'Drag left and right to move your ball at the bottom of the screen.\n'
          'Obstacles fall from the top — avoid them all to stay alive.\n'
          'Speed increases over time — the longer you survive, the harder it gets.\n'
          'Score points for every obstacle that passes you (5/10/20 pts on Easy/Medium/Hard).\n'
          'One hit and it\'s game over — how long can you last?',
      category: GameCategory.action,
      icon: Icons.sports_baseball_rounded,
      color: Color(0xFF00D4FF),
      bgColor: Color(0xFF0F0F23),
      playCount: 0,
      customLogo: buildDodgeBallLogo,
    ),
    const GameInfo(
      id: 'tap_tap_dash',
      name: 'Tap Tap Dash',
      description: 'Auto-running ball on a zigzag path — tap to turn at corners or fall off!',
      howToPlay:
          'Choose your difficulty (Easy, Medium, Hard) — speed and segment length vary by level.\n'
          'Your ball runs forward automatically on a zigzag path.\n'
          'Tap the screen when you reach a corner to turn — timing is key!\n'
          'If you tap too late (or not at all), you run off the edge and fall.\n'
          'Each successful turn scores a point. Speed increases over time.\n'
          'One mistake and it\'s game over — how many turns can you make?',
      category: GameCategory.action,
      icon: Icons.directions_run_rounded,
      color: Color(0xFF00D4FF),
      bgColor: Color(0xFF1A1A2E),
      playCount: 0,
      isFeatured: false,
      customLogo: buildTapTapDashLogo,
    ),
    const GameInfo(
      id: 'connect_four',
      name: 'Connect Four',
      description: 'Drop discs, connect 4 in a row — play vs AI or a friend!',
      howToPlay:
          'Choose your difficulty (Easy, Medium, Hard) or play with a friend on the same device.\n'
          'Players take turns dropping a colored disc into one of the 7 columns.\n'
          'Discs fall to the lowest available row in that column.\n'
          'Connect 4 of your discs in a row — horizontally, vertically, or diagonally — to win!\n'
          'Win consecutive rounds to build a Streak.\n'
          'Plan ahead — block your opponent while setting up your own lines!',
      category: GameCategory.board,
      icon: Icons.grid_4x4_rounded,
      color: Color(0xFF3366CC),
      bgColor: Color(0xFFE8EEFF),
      playCount: 0,
      customLogo: buildConnectFourLogo,
    ),
    const GameInfo(
      id: 'reversi',
      name: 'Reversi',
      description: 'Flip discs, dominate the board — classic Othello strategy!',
      howToPlay:
          'Choose your difficulty (Easy, Medium, Hard) or play with a friend on the same device.\n'
          'Players take turns placing a disc on the 8×8 board.\n'
          'Place your disc so it sandwiches one or more opponent discs between your pieces — sandwiched discs flip to your color.\n'
          'You MUST flip at least one disc to make a valid move. If you can\'t, your turn is skipped.\n'
          'The game ends when neither player can move (usually when the board is full).\n'
          'The player with the most discs wins! Control the corners for maximum advantage.',
      category: GameCategory.board,
      icon: Icons.circle_rounded,
      color: Color(0xFF2E7D32),
      bgColor: Color(0xFFE8F5E9),
      playCount: 0,
      customLogo: buildReversiLogo,
    ),
    const GameInfo(
      id: 'checkers',
      name: 'Checkers',
      description: 'Jump, capture, and crown your kings on the classic board!',
      howToPlay:
          'Choose your difficulty (Easy, Medium, Hard) or play with a friend on the same device.\n'
          'Players take turns moving pieces diagonally forward on dark squares.\n'
          'Jump over an opponent\'s piece to capture it — mandatory jumps must be taken!\n'
          'Chain multiple jumps in a single turn for big captures.\n'
          'Reach the far side to promote your piece to a King — Kings move diagonally in any direction!\n'
          'Capture all opponent pieces or block them completely to win.',
      category: GameCategory.board,
      icon: Icons.grid_on_rounded,
      color: Color(0xFF8B5E3C),
      bgColor: Color(0xFFFFF8F0),
      playCount: 0,
      customLogo: buildCheckersLogo,
    ),
    const GameInfo(
      id: 'go',
      name: 'Go',
      description: 'Ancient strategy — surround territory and capture stones on a 9x9 board!',
      howToPlay:
          'Choose your difficulty (Easy, Medium, Hard) or play with a friend on the same device.\n'
          'Players take turns placing stones on grid intersections. Black goes first.\n'
          'Surround opponent stones completely to capture and remove them from the board.\n'
          'Pass when you have no good moves. Two consecutive passes end the game.\n'
          'Territory is counted — empty intersections surrounded by your stones are your territory.\n'
          'The player with the most territory plus captures wins! White gets 6 komi (bonus points).',
      category: GameCategory.board,
      icon: Icons.circle_outlined,
      color: Color(0xFFC4944E),
      bgColor: Color(0xFFFFF8E7),
      playCount: 0,
      customLogo: buildGoLogo,
    ),
    const GameInfo(
      id: 'mancala',
      name: 'Mancala',
      description: 'Sow seeds, capture stones, and outplay your opponent!',
      howToPlay:
          'Choose your difficulty (Easy, Medium, Hard) or play with a friend on the same device.\n'
          'Each player has 6 pits with 4 seeds each, plus a store on their right.\n'
          'Tap a pit on your side to pick up all seeds and sow them counterclockwise, one per pit.\n'
          'If your last seed lands in your store, you get another turn!\n'
          'If your last seed lands in an empty pit on your side, capture it and the opposite pit\'s seeds.\n'
          'The game ends when one side is empty. Most seeds in your store wins!',
      category: GameCategory.board,
      icon: Icons.circle_rounded,
      color: Color(0xFF7B5B3A),
      bgColor: Color(0xFFFFF5E6),
      playCount: 0,
      customLogo: buildMancalaLogo,
    ),
    const GameInfo(
      id: 'gomoku',
      name: 'Gomoku',
      description: 'Five in a row wins! Place stones strategically on a 13x13 board.',
      howToPlay:
          'Choose your difficulty (Easy, Medium, Hard) or play with a friend on the same device.\n'
          'Players take turns placing stones on grid intersections. Black goes first.\n'
          'Connect 5 of your stones in a row — horizontally, vertically, or diagonally — to win!\n'
          'Block your opponent while building your own lines.\n'
          'The board is 13x13 — smaller than standard Go but perfect for fast games.\n'
          'Think ahead — open-ended lines of 4 are nearly unstoppable!',
      category: GameCategory.board,
      icon: Icons.blur_on_rounded,
      color: Color(0xFF4A90D9),
      bgColor: Color(0xFFF0F5FF),
      playCount: 0,
      customLogo: buildGomokuLogo,
    ),
    const GameInfo(
      id: 'hangman',
      name: 'Hangman',
      description: 'Guess the hidden word letter by letter before the hangman is complete!',
      howToPlay:
          'Choose your difficulty (Easy = short words, Medium = longer words, Hard = complex words).\n'
          'A hidden word is shown as blanks. Tap letters on the keyboard to guess.\n'
          'Correct letters fill in the blanks. Wrong guesses draw parts of the hangman.\n'
          'You have 6 wrong guesses before the hangman is complete and the game is over.\n'
          'Solve the word to win and build your streak!\n'
          'Common letters (E, A, R, S, T) are good starting guesses.',
      category: GameCategory.puzzle,
      icon: Icons.text_fields_rounded,
      color: Color(0xFF6C63FF),
      bgColor: Color(0xFFF5F3FF),
      playCount: 0,
      customLogo: buildHangmanLogo,
    ),
  ];

  static List<GameInfo> getByCategory(GameCategory category) {
    return allGames.where((g) => g.category == category).toList();
  }

  static List<GameInfo> get featured {
    return allGames.where((g) => g.isFeatured).toList();
  }

  static List<GameInfo> get trending {
    final sorted = List<GameInfo>.from(allGames);
    sorted.sort((a, b) => b.playCount.compareTo(a.playCount));
    return sorted;
  }

  static GameInfo? getById(String id) {
    try {
      return allGames.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<GameInfo> search(String query) {
    final q = query.toLowerCase();
    return allGames.where((g) {
      return g.name.toLowerCase().contains(q) ||
          g.category.label.toLowerCase().contains(q) ||
          g.description.toLowerCase().contains(q);
    }).toList();
  }
}
