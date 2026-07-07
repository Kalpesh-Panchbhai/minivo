import 'package:flutter/material.dart';
import '../core/models/game_info.dart';
import 'arrow_puzzle/arrow_puzzle_logo.dart';
import 'block_escape/block_escape_logo.dart';
import 'checkers/checkers_logo.dart';
import 'chess/chess_logo.dart';
import 'color_connect/color_connect_logo.dart';
import 'color_tap/color_tap_logo.dart';
import 'connect_four/connect_four_logo.dart';
import 'dino_run/dino_run_logo.dart';
import 'dodge_ball/dodge_ball_logo.dart';
import 'dots_and_boxes/dots_and_boxes_logo.dart';
import 'drop_merge/drop_merge_logo.dart';
import 'flappy_tap/flappy_tap_logo.dart';
import 'go/go_logo.dart';
import 'gomoku/gomoku_logo.dart';
import 'hangman/hangman_logo.dart';
import 'ludo/ludo_logo.dart';
import 'mancala/mancala_logo.dart';
import 'maze_paint/maze_paint_logo.dart';
import 'memory_match/memory_match_logo.dart';
import 'minesweeper/minesweeper_logo.dart';
import 'number_merge/number_merge_logo.dart';
import 'number_sequence/number_sequence_logo.dart';
import 'patches/patches_logo.dart';
import 'queens_puzzle/queens_puzzle_logo.dart';
import 'reversi/reversi_logo.dart';
import 'sliding_puzzle/sliding_puzzle_logo.dart';
import 'snake_classic/snake_classic_logo.dart';
import 'solitaire/solitaire_logo.dart';
import 'sudoku/sudoku_logo.dart';
import 'tango/tango_logo.dart';
import 'tap_tap_dash/tap_tap_dash_logo.dart';
import 'tic_tac_toe/tic_tac_toe_logo.dart';
import 'water_sort/water_sort_logo.dart';
import 'whack_a_mole/whack_a_mole_logo.dart';
import 'zip/zip_logo.dart';
import 'color_tap/color_tap_screen.dart';
import 'flappy_tap/flappy_tap_screen.dart';
import 'memory_match/memory_match_screen.dart';
import 'number_merge/number_merge_screen.dart';
import 'snake_classic/snake_classic_screen.dart';
import 'sudoku/sudoku_screen.dart';
import 'dots_and_boxes/dots_and_boxes_screen.dart';
import 'tic_tac_toe/tic_tac_toe_screen.dart';
import 'dino_run/dino_run_screen.dart';
import 'drop_merge/drop_merge_screen.dart';
import 'whack_a_mole/whack_a_mole_screen.dart';
import 'dodge_ball/dodge_ball_screen.dart';
import 'tap_tap_dash/tap_tap_dash_screen.dart';
import 'connect_four/connect_four_screen.dart';
import 'reversi/reversi_screen.dart';
import 'checkers/checkers_screen.dart';
import 'go/go_screen.dart';
import 'mancala/mancala_screen.dart';
import 'gomoku/gomoku_screen.dart';
import 'hangman/hangman_screen.dart';
import 'minesweeper/minesweeper_screen.dart';
import 'solitaire/solitaire_screen.dart';
import 'sliding_puzzle/sliding_puzzle_screen.dart';
import 'number_sequence/number_sequence_screen.dart';
import 'water_sort/water_sort_screen.dart';
import 'arrow_puzzle/arrow_puzzle_screen.dart';
import 'zip/zip_screen.dart';
import 'queens_puzzle/queens_puzzle_screen.dart';
import 'tango/tango_screen.dart';
import 'patches/patches_screen.dart';
import 'color_connect/color_connect_screen.dart';
import 'chess/chess_screen.dart';
import 'ludo/ludo_screen.dart';
import 'maze_paint/maze_paint_screen.dart';
import 'block_escape/block_escape_screen.dart';


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
    'minesweeper': () => const MinesweeperScreen(),
    'solitaire': () => const SolitaireScreen(),
    'sliding_puzzle': () => const SlidingPuzzleScreen(),
    'number_sequence': () => const NumberSequenceScreen(),
    'water_sort': () => const WaterSortScreen(),
    'arrow_puzzle': () => const ArrowPuzzleScreen(),
    'zip': () => const ZipScreen(),
    'queens_puzzle': () => const QueensPuzzleScreen(),
    'tango': () => const TangoScreen(),
    'patches': () => const PatchesScreen(),
    'color_connect': () => const ColorConnectScreen(),
    'chess': () => const ChessScreen(),
    'ludo': () => const LudoScreen(),
    'maze_paint': () => const MazePaintScreen(),
    'block_escape': () => const BlockEscapeScreen(),

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
    GameInfo(
      id: 'solitaire',
      name: 'Solitaire',
      description: 'Classic Klondike solitaire — stack cards from Ace to King!',
      howToPlay:
          'Choose your difficulty (Easy = Draw 1, Medium = Draw 3, Hard = Draw 3 + Timer).\n'
          'Build tableau columns in descending order, alternating red and black.\n'
          'Move Aces to foundation piles and build up by suit to King.\n'
          'Tap the stock pile to draw new cards to the waste pile.\n'
          'Complete all four foundation piles (Ace to King) to win!\n'
          'Score is based on moves, time, and cards placed on foundations.',
      category: GameCategory.card,
      icon: Icons.style_rounded,
      color: Color(0xFF22C55E),
      bgColor: Color(0xFFE8F5E9),
      playCount: 52000,
      isFeatured: true,
      customLogo: buildSolitaireLogo,
    ),
    GameInfo(
      id: 'maze_paint',
      name: 'Maze Paint',
      description: 'Swipe a paint roller through the maze and cover every reachable tile!',
      howToPlay:
          'Choose your difficulty and level.\n'
          'Swipe up, down, left, or right — the roller keeps moving until a wall, obstacle, or edge stops it.\n'
          'Every tile the roller passes over becomes painted, and repainting is allowed.\n'
          'Tap Restart to begin the level again, or Hint to reveal the next smart direction.\n'
          'Paint every reachable non-wall tile to complete the level!',
      category: GameCategory.puzzle,
      icon: Icons.format_paint_rounded,
      color: Color(0xFFFF1493),
      bgColor: Color(0xFFFFF0F5),
      playCount: 50000,
      isFeatured: true,
      customLogo: buildMazePaintLogo,
    ),
    GameInfo(
      id: 'block_escape',
      name: 'Block Escape',
      description: 'Slide blocks to free the red piece — a Rush Hour puzzle!',
      howToPlay:
          'Slide blocks horizontally or vertically to clear a path.\n'
          'The red block can only move left and right.\n'
          'Guide the red block to the exit gate on the right edge.\n'
          'Each block slides along its axis until another block or wall stops it.\n'
          'Solve each level in as few moves as possible.\n'
          '10,000 unique, always-solvable levels per difficulty!',
      category: GameCategory.puzzle,
      icon: Icons.lock_open_rounded,
      color: Color(0xFFE74C3C),
      bgColor: Color(0xFFFFF0EE),
      playCount: 48000,
      isFeatured: true,
      customLogo: buildBlockEscapeLogo,
    ),
    GameInfo(
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
      playCount: 49000,
      isFeatured: true,
      customLogo: buildSudokuLogo,
    ),
    GameInfo(
      id: 'water_sort',
      name: 'Water Sort',
      description: 'Pour and sort colored water into matching tubes!',
      howToPlay:
          'Choose your difficulty (Easy = 4–7 colors, Medium = 8–11, Hard = 12–14).\n'
          'Tap a tube to select it, then tap another to pour the top color.\n'
          'You can only pour onto a matching top color or into an empty tube.\n'
          'Pouring moves all stacked segments of the same color at once.\n'
          'Sort every color into its own tube — using the 2 free empty tubes.\n'
          'Stuck? Watch an ad to unlock one extra tube.\n'
          '10,000 unique, always-solvable levels per difficulty!',
      category: GameCategory.puzzle,
      icon: Icons.science_rounded,
      color: Color(0xFF0EA5E9),
      bgColor: Color(0xFFE0F2FE),
      playCount: 46000,
      isFeatured: true,
      customLogo: buildWaterSortLogo,
    ),
    GameInfo(
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
      playCount: 43000,
      isFeatured: true,
      customLogo: buildNumberMergeLogo,
    ),
    GameInfo(
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
      playCount: 40000,
      isFeatured: true,
      customLogo: buildSnakeLogo,
    ),
    GameInfo(
      id: 'zip',
      name: 'Zip',
      description: 'Draw a single path through every cell — visit checkpoints in order!',
      howToPlay:
          'Choose your difficulty — grids grow larger and walls appear as you progress.\n'
          'Draw a continuous path that visits every cell exactly once.\n'
          'Numbered checkpoints must be visited in ascending order (1 → 2 → 3...).\n'
          'Walls block your path — plan your route around them!\n'
          'Swipe to draw your path — only up, down, left, right moves allowed.\n'
          'Backtrack by dragging over the previous cell.\n'
          'Fill every cell to complete the level!',
      category: GameCategory.puzzle,
      icon: Icons.route_rounded,
      color: Color(0xFF818CF8),
      bgColor: Color(0xFFE0E7FF),
      playCount: 37000,
      customLogo: buildZipLogo,
    ),
    GameInfo(
      id: 'queens_puzzle',
      name: 'Queens',
      description: 'Place queens on the board — no two may touch!',
      howToPlay:
          'Choose your difficulty (Easy = 5×5, Medium = 6×6–7×7, Hard = 7×7–8×8).\n'
          'Tap a cell to place a queen. Tap a queen to remove it.\n'
          'Long press a cell to mark it with an ✕ (elimination marker).\n'
          'Place exactly one queen in each colored region.\n'
          'Each row and column must have exactly one queen.\n'
          'Queens cannot touch — not even 1 cell diagonally!\n'
          'But 2+ cells apart on the same diagonal is allowed.\n'
          'Solve the puzzle when all queens are placed without conflicts!',
      category: GameCategory.puzzle,
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF9B59B6),
      bgColor: Color(0xFFF3E8FF),
      playCount: 36000,
      customLogo: buildQueensPuzzleLogo,
    ),
    GameInfo(
      id: 'tango',
      name: 'Tango',
      description: 'Fill the grid with suns and moons — balance rows, columns and clues!',
      howToPlay:
          'Choose your difficulty (Easy = 4×4, Medium = 6×6, Hard = 6×6 fewer clues).\n'
          'Tap a cell to place a Sun. Tap again for Moon. Tap once more to clear.\n'
          'Every row and column must have an equal number of Suns and Moons.\n'
          'No three identical symbols may appear consecutively (horizontal or vertical).\n'
          '"=" clues mean the two cells must match. "×" clues mean they must differ.\n'
          'Pre-filled cells cannot be changed.\n'
          'Solve the puzzle when all cells are filled and every rule is satisfied!',
      category: GameCategory.puzzle,
      icon: Icons.wb_sunny_rounded,
      color: Color(0xFFF59E0B),
      bgColor: Color(0xFFFFF8E1),
      playCount: 35500,
      customLogo: buildTangoLogo,
    ),
    GameInfo(
      id: 'ludo',
      name: 'Ludo',
      description: 'Roll the die, race your tokens around the board, and get all four home first!',
      howToPlay:
          'Roll a 6 to release a token from home onto the board.\n'
          'Roll the die and move a token clockwise by that many spaces.\n'
          'Rolling a 6 gives you an extra turn.\n'
          'Land on an opponent to send them back home — you get an extra turn!\n'
          'Tokens on star squares are safe from capture.\n'
          'Get all 4 tokens to the center finish area to win!',
      category: GameCategory.board,
      icon: Icons.casino_rounded,
      color: Color(0xFF6C5CE7),
      bgColor: Color(0xFFF8F6FF),
      playCount: 35000,
      customLogo: buildLudoLogo,
    ),
    GameInfo(
      id: 'patches',
      name: 'Patches',
      description: 'Divide the grid into rectangles — each clue tells you the patch size!',
      howToPlay:
          'Choose your difficulty (Easy = 5×5, Medium = 7×7, Hard = 9×9).\n'
          'Drag across cells to create a rectangular patch.\n'
          'Each number tells you the area of the patch it belongs to.\n'
          'Every patch must be a rectangle containing exactly one number.\n'
          'Tap an existing patch to remove it.\n'
          'Cover every cell with no gaps and no overlaps to win!',
      category: GameCategory.puzzle,
      icon: Icons.grid_view_rounded,
      color: Color(0xFF6366F1),
      bgColor: Color(0xFFEEF2FF),
      playCount: 35000,
      customLogo: buildPatchesLogo,
    ),
    GameInfo(
      id: 'color_connect',
      name: 'Color Connect',
      description: 'Link matching dots with paths — fill every cell without crossing!',
      howToPlay:
          'Choose your difficulty (Easy = 5×5, Medium = 7×7, Hard = 9×9).\n'
          'Drag from a colored dot to connect it to its matching pair.\n'
          'Paths cannot cross or overlap with each other.\n'
          'Every cell on the board must be filled by a path.\n'
          'Complete all connections to solve the puzzle!\n'
          'Backtrack by dragging back over your path.',
      category: GameCategory.puzzle,
      icon: Icons.linear_scale_rounded,
      color: Color(0xFF6C63FF),
      bgColor: Color(0xFFE8E5FF),
      playCount: 34000,
      customLogo: buildColorConnectLogo,
    ),
    GameInfo(
      id: 'arrow_puzzle',
      name: 'Arrow Puzzle',
      description: 'Untangle overlapping arrows and free them one by one!',
      howToPlay:
          'Choose your difficulty — arrows increase with each level.\n'
          'Arrows are tangled on a board — each points in a direction.\n'
          'Tap an arrow to free it. It flies away if its exit path is clear.\n'
          'If another arrow blocks the way, you can\'t free it yet!\n'
          'Figure out the right order to untangle and free all arrows.\n'
          'Complete levels with fewer taps for a better score!',
      category: GameCategory.puzzle,
      icon: Icons.arrow_forward_rounded,
      color: Color(0xFF7C3AED),
      bgColor: Color(0xFFEDE9FE),
      playCount: 34000,
      customLogo: buildArrowPuzzleLogo,
    ),
    GameInfo(
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
      playCount: 31000,
      isFeatured: true,
      customLogo: buildFlappyTapLogo,
    ),
    GameInfo(
      id: 'chess',
      name: 'Chess',
      description: 'The ultimate strategy game — checkmate the King to win!',
      howToPlay:
          'Choose your difficulty (Easy, Medium, Hard) or play with a friend on the same device.\n'
          'Tap a piece to select it — green dots show legal moves.\n'
          'Tap a highlighted square to move. Each piece has unique movement rules.\n'
          'Put the opponent\'s King in check — they must escape or lose!\n'
          'Special moves: castling (King + Rook), en passant (pawn capture), and pawn promotion.\n'
          'Checkmate the King to win! Games can also end in draw (stalemate, repetition, 50-move rule).',
      category: GameCategory.board,
      icon: Icons.castle_rounded,
      color: Color(0xFFD4AF37),
      bgColor: Color(0xFFFAF8F5),
      playCount: 30000,
      customLogo: buildChessLogo,
    ),
    GameInfo(
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
      playCount: 29000,
      customLogo: buildDinoRunLogo,
    ),
    GameInfo(
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
      playCount: 27000,
      customLogo: buildTicTacToeLogo,
    ),
    GameInfo(
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
      playCount: 25000,
      customLogo: buildCheckersLogo,
    ),
    GameInfo(
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
      playCount: 23000,
      customLogo: buildMemoryMatchLogo,
    ),
    GameInfo(
      id: 'minesweeper',
      name: 'Minesweeper',
      description: 'Clear the minefield without detonating any mines!',
      howToPlay:
          'Choose your difficulty (Easy = 9×9, Medium = 16×16, Hard = 16×30).\n'
          'Tap a cell to reveal it. Numbers show how many adjacent mines there are.\n'
          'Use Flag Mode or long-press to mark suspected mines with flags.\n'
          'Reveal all safe cells to win — but hit a mine and it is game over!\n'
          'Score is based on mines found and time taken.\n'
          'Start with corners and edges for the safest first moves.',
      category: GameCategory.puzzle,
      icon: Icons.grid_view_rounded,
      color: Color(0xFF4A7CFF),
      bgColor: Color(0xFFF0F4FF),
      playCount: 21000,
      customLogo: buildMinesweeperLogo,
    ),
    GameInfo(
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
      playCount: 19000,
      customLogo: buildConnectFourLogo,
    ),
    GameInfo(
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
      playCount: 17000,
      customLogo: buildDropMergeLogo,
    ),
    GameInfo(
      id: 'sliding_puzzle',
      name: 'Sliding Puzzle',
      description: 'Slide tiles into order — numbers, animals, flags & more!',
      howToPlay:
          'Choose a grid size (3×3, 4×4, or 5×5) and a theme.\n'
          'Tap a tile next to the empty space to slide it.\n'
          'Arrange all tiles in numerical order (or match the pattern).\n'
          'Fewer moves and faster time = higher score!\n'
          'Choose from 6 themes: Numbers, Animals, Nature, Space, Food, and Flags.\n'
          'Start by solving the top row first, then work downward.',
      category: GameCategory.puzzle,
      icon: Icons.grid_view_rounded,
      color: Color(0xFF8B5CF6),
      bgColor: Color(0xFFF3EEFF),
      playCount: 15000,
      customLogo: buildSlidingPuzzleLogo,
    ),
    GameInfo(
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
      playCount: 13000,
      customLogo: buildHangmanLogo,
    ),
    GameInfo(
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
      playCount: 11000,
      customLogo: buildTapTapDashLogo,
    ),
    GameInfo(
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
      playCount: 9500,
      customLogo: buildWhackAMoleLogo,
    ),
    GameInfo(
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
      playCount: 8000,
      customLogo: buildColorTapLogo,
    ),
    GameInfo(
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
      playCount: 6500,
      customLogo: buildDotsAndBoxesLogo,
    ),
    GameInfo(
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
      playCount: 5500,
      customLogo: buildDodgeBallLogo,
    ),
    GameInfo(
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
      playCount: 4500,
      customLogo: buildMancalaLogo,
    ),
    GameInfo(
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
      playCount: 3500,
      customLogo: buildReversiLogo,
    ),
    GameInfo(
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
      playCount: 2500,
      customLogo: buildGomokuLogo,
    ),    GameInfo(
      id: 'number_sequence',
      name: 'Number Sequence',
      description: 'Find scattered numbers in order — race the clock!',
      howToPlay:
          'Choose your difficulty (Easy = 25 numbers, Medium = 50, Hard = 100).\n'
          'Numbers are scattered randomly across the screen.\n'
          'Tap them in ascending order: 1, 2, 3… as fast as you can!\n'
          'Each correct tap makes the number disappear.\n'
          'Wrong taps do nothing — no penalty, just keep searching.\n'
          'Watch an ad for a hint that highlights the next number!',
      category: GameCategory.puzzle,
      icon: Icons.tag_rounded,
      color: Color(0xFF6366F1),
      bgColor: Color(0xFFEEF2FF),
      playCount: 1800,
      customLogo: buildNumberSequenceLogo,
    ),

    GameInfo(
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
      playCount: 1000,
      customLogo: buildGoLogo,
    ),
  ];

  static bool _logosRegistered = false;

  static void _ensureLogosRegistered() {
    if (_logosRegistered) return;
    _logosRegistered = true;
    GameInfo.registerLogo('solitaire', buildSolitaireLogo);
    GameInfo.registerLogo('maze_paint', buildMazePaintLogo);
    GameInfo.registerLogo('block_escape', buildBlockEscapeLogo);
    GameInfo.registerLogo('sudoku', buildSudokuLogo);
    GameInfo.registerLogo('water_sort', buildWaterSortLogo);
    GameInfo.registerLogo('number_merge', buildNumberMergeLogo);
    GameInfo.registerLogo('snake_classic', buildSnakeLogo);
    GameInfo.registerLogo('zip', buildZipLogo);
    GameInfo.registerLogo('queens_puzzle', buildQueensPuzzleLogo);
    GameInfo.registerLogo('tango', buildTangoLogo);
    GameInfo.registerLogo('ludo', buildLudoLogo);
    GameInfo.registerLogo('patches', buildPatchesLogo);
    GameInfo.registerLogo('color_connect', buildColorConnectLogo);
    GameInfo.registerLogo('arrow_puzzle', buildArrowPuzzleLogo);
    GameInfo.registerLogo('flappy_tap', buildFlappyTapLogo);
    GameInfo.registerLogo('chess', buildChessLogo);
    GameInfo.registerLogo('dino_run', buildDinoRunLogo);
    GameInfo.registerLogo('tic_tac_toe', buildTicTacToeLogo);
    GameInfo.registerLogo('memory_match', buildMemoryMatchLogo);
    GameInfo.registerLogo('color_tap', buildColorTapLogo);
    GameInfo.registerLogo('checkers', buildCheckersLogo);
    GameInfo.registerLogo('connect_four', buildConnectFourLogo);
    GameInfo.registerLogo('minesweeper', buildMinesweeperLogo);
    GameInfo.registerLogo('drop_merge', buildDropMergeLogo);
    GameInfo.registerLogo('dots_and_boxes', buildDotsAndBoxesLogo);
    GameInfo.registerLogo('sliding_puzzle', buildSlidingPuzzleLogo);
    GameInfo.registerLogo('hangman', buildHangmanLogo);
    GameInfo.registerLogo('whack_a_mole', buildWhackAMoleLogo);
    GameInfo.registerLogo('tap_tap_dash', buildTapTapDashLogo);
    GameInfo.registerLogo('dodge_ball', buildDodgeBallLogo);
    GameInfo.registerLogo('number_sequence', buildNumberSequenceLogo);
    GameInfo.registerLogo('reversi', buildReversiLogo);
    GameInfo.registerLogo('gomoku', buildGomokuLogo);
    GameInfo.registerLogo('mancala', buildMancalaLogo);
    GameInfo.registerLogo('go', buildGoLogo);
  }

  static List<GameInfo> get visibleGames {
    _ensureLogosRegistered();
    return allGames.where((g) => !g.hidden).toList();
  }

  static List<GameInfo> getByCategory(GameCategory category) {
    _ensureLogosRegistered();
    return allGames.where((g) => !g.hidden && g.category == category).toList();
  }

  static List<GameInfo> get featured {
    _ensureLogosRegistered();
    return allGames.where((g) => !g.hidden && g.isFeatured).toList();
  }

  static List<GameInfo> get trending {
    _ensureLogosRegistered();
    final sorted = List<GameInfo>.from(allGames.where((g) => !g.hidden));
    sorted.sort((a, b) => b.playCount.compareTo(a.playCount));
    return sorted;
  }

  static GameInfo? getById(String id) {
    _ensureLogosRegistered();
    try {
      return allGames.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<GameInfo> search(String query) {
    _ensureLogosRegistered();
    final q = query.toLowerCase();
    return allGames.where((g) {
      return !g.hidden &&
          (g.name.toLowerCase().contains(q) ||
          g.category.label.toLowerCase().contains(q) ||
          g.description.toLowerCase().contains(q));
    }).toList();
  }
}
