import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/multiplayer/player_strip.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../game_picker_scaffold.dart';
import '../game_registry.dart';
import '../game_wrapper.dart';
import '../shared/animated_background.dart';
import '../shared/animated_difficulty_icon.dart';
import '../shared/game_control_buttons.dart';
import '../shared/game_hud_bar.dart';
import '../shared/game_difficulty_picker.dart';
import 'tic_tac_toe_stats.dart';
import 'tic_tac_toe_tutorial.dart';
import '../shared/generic_game_result_screen.dart' as game_result;

/// Test-only override for the very first starter pick of a session.
/// `'X'` or `'O'` to force; `null` to use the regular random pick.
@visibleForTesting
String? debugFirstStarter;

// ── Player accent colors (softened, candy-pastel feel) ─────────────────────
const Color _kXColor = Color(0xFFE85D75);   // soft coral red
const Color _kOColor = Color(0xFF5BC0DE);   // soft sky cyan
const Color _kDrawColor = Color(0xFFB6A5DD); // soft lilac

// ── Mode buttons ──────────────────────────────────────────────────────────
const Color _kAiColor = Color(0xFF6C4EF3);     // vibrant indigo
// ── Design tokens ─────────────────────────────────────────────────────────
const Color _kBgTop    = Color(0xFFFFF9F5);   // warm cream
const Color _kBgBot    = Color(0xFFF8F5FF);   // pale lavender

// ── Board ambient tints ────────────────────────────────────────────────────
// Neutral-warm baseline, leaning warm on X turn and cool on O turn.
const Color _kTintNeutralTop = Color(0xFFFDEFE3);
const Color _kTintNeutralBot = Color(0xFFFADFD0);
const Color _kTintWarmTop = Color(0xFFFFE0D8);     // X turn (warm coral)
const Color _kTintWarmBot = Color(0xFFFFC9C0);
const Color _kTintCoolTop = Color(0xFFDDEEF5);     // O turn (cool cyan)
const Color _kTintCoolBot = Color(0xFFC2DEEC);

enum _Mode { ai, twoPlayer }

enum _Difficulty { easy, medium, hard }

class TicTacToeScreen extends StatefulWidget {
  const TicTacToeScreen({super.key});

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen>
    with TickerProviderStateMixin {
  // Mode + difficulty
  _Mode? _mode;
  _Difficulty _difficulty = _Difficulty.medium;

  // ────────────────────────────────────────────────────────
  // Per-round state
  // ────────────────────────────────────────────────────────
  List<String> _board = List.filled(9, '');
  String _currentPlayer = 'X';
  String? _winner; // 'X' / 'O' / null (draw or in-progress)
  List<int> _winLine = [];
  bool _aiThinking = false;
  bool _roundOver = false;
  bool _showWinBanner = false;
  String? _bannerLabel;
  Color _bannerColor = _kDrawColor;

  // ────────────────────────────────────────────────────────
  // Persistent session score (resets only on mode change)
  // ────────────────────────────────────────────────────────
  int _xWins = 0;
  int _oWins = 0;
  int _draws = 0;

  // Win streak (resets on loss/draw/mode change). Owner = 'X' or 'O'.
  int _streak = 0;
  String? _streakOwner;
  bool _showStreakBadge = false;

  // Who starts the next round. Random for the very first round of a session,
  // then strictly alternates. Symbols stay fixed (X = human / P1, O = AI / P2).
  String _starter = 'X';
  // True only for the very first round after entering a mode (so we randomise).
  bool _firstRoundOfSession = true;

  // Win celebration burst.
  bool _celebrating = false;

  // Favorite
  bool _isFavorite = false;
  static const _gameId = kTicTacToeGameId;

  // Animations
  late final AnimationController _winLineCtrl;

  final _audio = AudioService();
  final _rng = math.Random();
  // Pending AI move / win-banner timers — cancelled on dispose so test
  // teardown does not see "Timer still pending" warnings.
  Timer? _aiMoveTimer;
  Timer? _endGameTimer;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(_gameId);
    _winLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _aiMoveTimer?.cancel();
    _endGameTimer?.cancel();
    _winLineCtrl.dispose();
    super.dispose();
  }

  GameWrapperState get _wrapper => GameWrapper.of(context);

  // ════════════════════════════════════════════════════════════════
  // SESSION / FLOW
  // ════════════════════════════════════════════════════════════════

  void _selectMode(_Mode mode) {
    setState(() {
      _mode = mode;
      _xWins = 0;
      _oWins = 0;
      _draws = 0;
      _streak = 0;
      _streakOwner = null;
      _showStreakBadge = false;
      // First round of a fresh session — randomise who starts.
      _firstRoundOfSession = true;
    });
    _resetBoardForNewRound();
    _wrapper.startGame();
  }

  void _changeMode() {
    setState(() {
      _mode = null;
      _xWins = 0;
      _oWins = 0;
      _draws = 0;
      _streak = 0;
      _streakOwner = null;
      _showStreakBadge = false;
      _firstRoundOfSession = true;
      _resetBoardForNewRound(notify: false);
    });
    _wrapper.restartGame();
  }

  void _playAgainSameMode() {
    _resetBoardForNewRound();
    _wrapper.restartGame();
    _wrapper.startGame();
  }

  /// Rebuilds the board for a new round and decides who starts.
  /// Rule: on the very first round of a session pick randomly; after that,
  /// strictly alternate the starter from the previous round.
  void _resetBoardForNewRound({bool notify = true}) {
    void apply() {
      // Decide starter for this new round.
      if (_firstRoundOfSession) {
        _starter = debugFirstStarter ?? (_rng.nextBool() ? 'X' : 'O');
        _firstRoundOfSession = false;
      } else {
        _starter = (_starter == 'X') ? 'O' : 'X';
      }
      _board = List.filled(9, '');
      _currentPlayer = _starter;
      _winner = null;
      _winLine = [];
      _aiThinking = false;
      _roundOver = false;
      _showWinBanner = false;
      _bannerLabel = null;
      _celebrating = false;
      _showStreakBadge = false;
      _winLineCtrl.value = 0;
    }
    if (notify) {
      setState(apply);
    } else {
      apply();
    }
    // If AI is starting, kick off its move.
    if (_mode == _Mode.ai && _currentPlayer == 'O') {
      _scheduleAiMove();
    }
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
      ScoreService().toggleFavorite(_gameId);
    });
    _audio.playTap();
  }

  void _backOrHome() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _showHowToPlay(BuildContext context) {
    final game = GameRegistry.getById(_gameId);
    if (game == null) return;
    showHowToPlaySheet(
      context,
      title: game.name,
      howToPlay: game.howToPlay,
      accent: _kAiColor,
      steps: ticTacToeSteps(),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // GAMEPLAY
  // ════════════════════════════════════════════════════════════════

  void _onCellTap(int index) {
    if (_roundOver || _board[index].isNotEmpty) return;
    // In AI mode the human controls only X. Block taps during AI's turn.
    if (_mode == _Mode.ai && (_aiThinking || _currentPlayer != 'X')) return;

    setState(() {
      _board[index] = _currentPlayer;
    });
    _audio.playTap();

    final winLine = _findWinningLine(_currentPlayer);
    if (winLine != null) {
      _onWin(winLine, _currentPlayer);
      return;
    }
    if (_isBoardFull()) {
      _onDraw();
      return;
    }

    setState(() {
      _currentPlayer = _currentPlayer == 'X' ? 'O' : 'X';
    });

    if (_mode == _Mode.ai && _currentPlayer == 'O') {
      _scheduleAiMove();
    }
  }

  void _scheduleAiMove() {
    setState(() => _aiThinking = true);
    // Pause long enough for the user to feel the turn-aware tint cross-fade
    // (which animates over ~420 ms) before the AI actually plays.
    final thinkMs = switch (_difficulty) {
      _Difficulty.easy => 700,
      _Difficulty.medium => 900,
      _Difficulty.hard => 1100,
    };
    _aiMoveTimer?.cancel();
    _aiMoveTimer = Timer(Duration(milliseconds: thinkMs), () {
      if (!mounted || _roundOver) return;
      final move = _pickAiMove();
      setState(() {
        _board[move] = 'O';
        _aiThinking = false;
      });
      _audio.playTap();
      final winLine = _findWinningLine('O');
      if (winLine != null) {
        _onWin(winLine, 'O');
        return;
      }
      if (_isBoardFull()) {
        _onDraw();
        return;
      }
      setState(() => _currentPlayer = 'X');
    });
  }

  int _pickAiMove() {
    switch (_difficulty) {
      case _Difficulty.easy:
        // 70% random, 30% smart — beatable by anyone.
        if (_rng.nextDouble() < 0.7) return _randomMove();
        return _smartMove(useMinimax: false);
      case _Difficulty.medium:
        return _smartMove(useMinimax: false);
      case _Difficulty.hard:
        // Hard: mostly optimal play, but with a 25% chance of choosing
        // a "smart but not perfect" heuristic move. This keeps Hard
        // genuinely challenging while still letting a clever player win.
        if (_rng.nextDouble() < 0.25) {
          return _smartMove(useMinimax: false);
        }
        return _smartMove(useMinimax: true);
    }
  }

  int _randomMove() {
    final empties = <int>[];
    for (int i = 0; i < 9; i++) {
      if (_board[i].isEmpty) empties.add(i);
    }
    return empties[_rng.nextInt(empties.length)];
  }

  int _smartMove({required bool useMinimax}) {
    // 1) Win if possible.
    final win = _findMoveThatCompletes('O');
    if (win != null) return win;
    // 2) Block opponent's winning move.
    final block = _findMoveThatCompletes('X');
    if (block != null) return block;

    if (useMinimax) {
      return _minimaxBestMove();
    }

    // 3) Take center.
    if (_board[4].isEmpty) return 4;
    // 4) Take a corner.
    const corners = [0, 2, 6, 8];
    final freeCorners = corners.where((i) => _board[i].isEmpty).toList();
    if (freeCorners.isNotEmpty) {
      return freeCorners[_rng.nextInt(freeCorners.length)];
    }
    // 5) Side.
    return _randomMove();
  }

  int? _findMoveThatCompletes(String player) {
    for (final line in _winningLines) {
      final values = line.map((i) => _board[i]).toList();
      final emptyCount = values.where((v) => v.isEmpty).length;
      final playerCount = values.where((v) => v == player).length;
      if (emptyCount == 1 && playerCount == 2) {
        return line[values.indexOf('')];
      }
    }
    return null;
  }

  // Minimax with alpha-beta. O is maximizer, X is minimizer.
  int _minimaxBestMove() {
    int bestScore = -1000;
    int bestMove = _randomMove();
    for (int i = 0; i < 9; i++) {
      if (_board[i].isEmpty) {
        _board[i] = 'O';
        final score = _minimax(false, -1000, 1000, 0);
        _board[i] = '';
        if (score > bestScore) {
          bestScore = score;
          bestMove = i;
        }
      }
    }
    return bestMove;
  }

  int _minimax(bool isMaximizing, int alpha, int beta, int depth) {
    if (_findWinningLine('O') != null) return 10 - depth;
    if (_findWinningLine('X') != null) return depth - 10;
    if (_isBoardFull()) return 0;

    if (isMaximizing) {
      int best = -1000;
      for (int i = 0; i < 9; i++) {
        if (_board[i].isEmpty) {
          _board[i] = 'O';
          final s = _minimax(false, alpha, beta, depth + 1);
          _board[i] = '';
          if (s > best) best = s;
          if (best > alpha) alpha = best;
          if (beta <= alpha) break;
        }
      }
      return best;
    } else {
      int best = 1000;
      for (int i = 0; i < 9; i++) {
        if (_board[i].isEmpty) {
          _board[i] = 'X';
          final s = _minimax(true, alpha, beta, depth + 1);
          _board[i] = '';
          if (s < best) best = s;
          if (best < beta) beta = best;
          if (beta <= alpha) break;
        }
      }
      return best;
    }
  }

  static const _winningLines = <List<int>>[
    [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
    [0, 3, 6], [1, 4, 7], [2, 5, 8], // cols
    [0, 4, 8], [2, 4, 6], // diagonals
  ];

  List<int>? _findWinningLine(String player) {
    for (final line in _winningLines) {
      if (line.every((i) => _board[i] == player)) return line;
    }
    return null;
  }

  bool _isBoardFull() => !_board.contains('');

  // Maps the active AI difficulty to the persistent best-streak sub-key.
  // Returns null in pass-and-play mode — we don't persist anything there
  // (per product rule: "best is always against AI for all levels").
  String? _aiSubKey() {
    if (_mode != _Mode.ai) return null;
    switch (_difficulty) {
      case _Difficulty.easy:
        return kTicTacToeSubKeyEasy;
      case _Difficulty.medium:
        return kTicTacToeSubKeyMedium;
      case _Difficulty.hard:
        return kTicTacToeSubKeyHard;
    }
  }

  /// True when the player just achieved a new best-streak on the current
  /// difficulty. Used by the win banner / game-over screen to celebrate.
  bool _wasNewBest = false;

  void _onWin(List<int> line, String player) {
    final isAi = _mode == _Mode.ai;
    setState(() {
      _winLine = line;
      _winner = player;
      _roundOver = true;
      _showWinBanner = true;
      _celebrating = true;
      if (player == 'X') {
        _xWins++;
        _bannerLabel = isAi ? 'You Win!' : 'Player 1 Wins!';
        _bannerColor = _kXColor;
      } else {
        _oWins++;
        _bannerLabel = isAi ? 'AI Wins!' : 'Player 2 Wins!';
        _bannerColor = _kOColor;
      }
      // Streak: continues if same owner, otherwise restarts at 1.
      if (_streakOwner == player) {
        _streak++;
      } else {
        _streakOwner = player;
        _streak = 1;
      }
      _showStreakBadge = _streak >= 2;
    });

    // Persist the player's streak as the new "best" for the active
    // difficulty whenever it surpasses the previous best. We never persist
    // anything for AI wins, draws, or two-player rounds.
    if (isAi && player == 'X') {
      final subKey = _aiSubKey();
      if (subKey != null) {
        ScoreService()
            .saveScore(_gameId, _streak, subKey: subKey)
            .then((isNew) {
          if (mounted && isNew) setState(() => _wasNewBest = true);
        });
      }
    } else {
      _wasNewBest = false;
    }

    _winLineCtrl.forward(from: 0);
    _audio.playSuccess();
    _endGameTimer?.cancel();
    _endGameTimer = Timer(const Duration(milliseconds: 1700), () {
      if (mounted) _wrapper.endGame();
    });
  }

  void _onDraw() {
    setState(() {
      _winner = null;
      _wasNewBest = false;
      // Draw breaks any active streak.
      _streak = 0;
      _streakOwner = null;
      _showStreakBadge = false;
      _roundOver = true;
      _showWinBanner = true;
      _draws++;
      _bannerLabel = "It's a Draw!";
      _bannerColor = _kDrawColor;
    });
    _endGameTimer?.cancel();
    _endGameTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) _wrapper.endGame();
    });
  }

  // ════════════════════════════════════════════════════════════════
  // BUILD ROOT
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final state = _wrapper.state;

    if (state == GameState.ready || _mode == null) {
      return _ModePickerScreen(
        difficulty: _difficulty,
        onDifficultyChanged: (d) => setState(() => _difficulty = d),
        isFavorite: _isFavorite,
        onFavoriteToggle: _toggleFavorite,
        onBack: _backOrHome,
        onPlayAi: () => _selectMode(_Mode.ai),
        onPlayFriend: () => _selectMode(_Mode.twoPlayer),
        onHelp: () => _showHowToPlay(context),
      );
    }

    if (state == GameState.gameOver) {
      return _buildWinnerScreen();
    }

    // Playing or paused — render the in-game board.
    return _BoardScreen(
      board: _board,
      currentPlayer: _currentPlayer,
      mode: _mode!,
      difficulty: _difficulty,
      xWins: _xWins,
      oWins: _oWins,
      aiThinking: _aiThinking,
      winLine: _winLine,
      winLineCtrl: _winLineCtrl,
      bannerLabel: _showWinBanner ? _bannerLabel : null,
      bannerColor: _bannerColor,
      celebrating: _celebrating,
      streak: _streak,
      showStreakBadge: _showStreakBadge,
      onCellTap: _onCellTap,
      onBack: _backOrHome,
      onRestart: _playAgainSameMode,
    );
  }

  Widget _buildWinnerScreen() {
    final isAi = _mode == _Mode.ai;
    String headline;
    String big;
    Color bigColor;
    if (_winner == 'X') {
      headline = isAi ? 'You Win!' : 'Player 1 Wins!';
      big = 'X';
      bigColor = _kXColor;
    } else if (_winner == 'O') {
      headline = isAi ? 'AI Wins!' : 'Player 2 Wins!';
      big = 'O';
      bigColor = _kOColor;
    } else {
      headline = "It's a Draw!";
      big = '=';
      bigColor = _kDrawColor;
    }

    final showStreak = _streak >= 2 && _streakOwner == _winner;
    final extraBadges = <Widget>[
      if (showStreak) _StreakBadge(streak: _streak),
      if (_wasNewBest) const _NewBestBadge(),
    ];

    return game_result.GenericGameResultScreen(
      headline: headline,
      badgeContent: big,
      badgeColor: bigColor,
      showNewBestBadge: false,
      extraBadges: extraBadges,
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(label: isAi ? 'YOU' : 'P1', value: _xWins, color: _kXColor),
          game_result.StatItem(label: 'DRAWS', value: _draws, color: const Color(0xFF8B7BA7)),
          game_result.StatItem(label: isAi ? 'AI' : 'P2', value: _oWins, color: _kOColor),
        ],
      ),
      actions: [
        game_result.GameResultAction(
          label: 'Play Again',
          icon: Icons.refresh_rounded,
          onTap: _playAgainSameMode,
          filled: true,
          color: _kAiColor,
        ),
        game_result.GameResultAction(
          label: 'Change Mode',
          icon: Icons.swap_horiz_rounded,
          onTap: _changeMode,
        ),
        game_result.GameResultAction(
          label: 'Home',
          icon: Icons.home_rounded,
          onTap: _backOrHome,
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MODE PICKER SCREEN — themed hero panel + card with controls
// ════════════════════════════════════════════════════════════════

class _ModePickerScreen extends StatelessWidget {
  final _Difficulty difficulty;
  final ValueChanged<_Difficulty> onDifficultyChanged;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onBack;
  final VoidCallback onPlayAi;
  final VoidCallback onPlayFriend;
  final VoidCallback onHelp;

  const _ModePickerScreen({
    required this.difficulty,
    required this.onDifficultyChanged,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.onBack,
    required this.onPlayAi,
    required this.onPlayFriend,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    return GamePickerScaffold(
      bgColorTop: _kBgTop,
      bgColorBottom: _kBgBot,
      animatedBg: AnimatedBackground(
        factory: (t) => _TttBackgroundPainter(t),
        period: const Duration(seconds: 9),
      ),
      iconRingColors: const [Color(0xFF6C4EF3), Color(0xFFFF5A5F), Color(0xFF6C4EF3)],
      iconChild: Builder(builder: (ctx) {
        final info = GameRegistry.getById(kTicTacToeGameId);
        final logo = info?.buildBrandedLogo(size: 84);
        if (logo != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(42),
            child: logo,
          );
        }
        return const Icon(Icons.close_rounded, size: 40, color: Color(0xFF6C4EF3));
      }),
      title: 'Tic Tac Toe',
      subtitle: 'Three in a row wins.',
      onBack: onBack,
      isFavorite: isFavorite,
      onFavoriteToggle: onFavoriteToggle,
      onHowToPlay: onHelp,
      tallThreshold: 860,
      body: GameAiPickerBody(
        difficulties: _Difficulty.values.map((d) {
          final meta = _difficultyMeta(d);
          final subKey = switch (d) {
            _Difficulty.easy => kTicTacToeSubKeyEasy,
            _Difficulty.medium => kTicTacToeSubKeyMedium,
            _Difficulty.hard => kTicTacToeSubKeyHard,
          };
          return GameDifficultyData(
            label: meta.label,
            color: meta.color,
            kind: _kindFor(d),
            hint: switch (d) {
              _Difficulty.easy => 'Mostly random — easy to beat.',
              _Difficulty.medium => 'Plays smart but not perfect.',
              _Difficulty.hard => 'Plays sharp — clever players can still win.',
            },
            bestScore: bestStreak(subKey),
            bestLabel: (s) => 'Best $s in a row',
          );
        }).toList(),
        activeIndex: _Difficulty.values.indexOf(difficulty),
        onChanged: (i) => onDifficultyChanged(_Difficulty.values[i]),
        onPlayAi: onPlayAi,
        onPlayFriend: onPlayFriend,
      ),
    );
  }
}


/// Animated TTT background — X's, O's and mini-grids gently bob and rotate
/// with phase-offset sine waves so the canvas feels alive without distracting.
class _TttBackgroundPainter extends AnimatedBgPainter {
  const _TttBackgroundPainter(super.t);

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final phase = t * 2 * math.pi;
    final xPaint = Paint()
      ..color = const Color(0xFFE85D75).withValues(alpha: 0.10)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final oPaint = Paint()
      ..color = const Color(0xFF5BC0DE).withValues(alpha: 0.10)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final gridPaint = Paint()
      ..color = const Color(0xFF6C4EF3).withValues(alpha: 0.06)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    void drawX(double cx, double cy, double r, double itemPhase) {
      final rot = math.sin(phase + itemPhase) * 0.12; // slight tilt
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);
      canvas.drawLine(Offset(-r, -r), Offset(r, r), xPaint);
      canvas.drawLine(Offset(r, -r), Offset(-r, r), xPaint);
      canvas.restore();
    }

    void drawO(double cx, double cy, double r, double itemPhase) {
      final pulseR = r + math.sin(phase + itemPhase) * 1.5;
      canvas.drawCircle(Offset(cx, cy), pulseR, oPaint);
    }

    void drawMiniGrid(double cx, double cy, double s, double itemPhase) {
      final tt = s / 3;
      final rot = math.sin(phase + itemPhase) * 0.06;
      canvas.save();
      canvas.translate(cx + s / 2, cy + s / 2);
      canvas.rotate(rot);
      canvas.translate(-s / 2, -s / 2);
      canvas.drawLine(Offset(tt, 0), Offset(tt, s), gridPaint);
      canvas.drawLine(Offset(tt * 2, 0), Offset(tt * 2, s), gridPaint);
      canvas.drawLine(Offset(0, tt), Offset(s, tt), gridPaint);
      canvas.drawLine(Offset(0, tt * 2), Offset(s, tt * 2), gridPaint);
      canvas.restore();
    }

    final w = size.width;
    final h = size.height;

    // Each item gets a different phase + a vertical bob so the cluster feels
    // organic instead of moving in lock-step. Bob amplitude is tile-radius
    // proportional so smaller marks barely shift.
    final items = [
      // X marks: (xRel, yRel, radius, phase)
      ('x', 0.08, 0.12, 18.0, 0.0),
      ('x', 0.88, 0.08, 14.0, 0.7),
      ('x', 0.15, 0.55, 12.0, 1.4),
      ('x', 0.92, 0.42, 20.0, 2.1),
      ('x', 0.05, 0.80, 16.0, 2.8),
      ('x', 0.75, 0.90, 13.0, 3.5),
      ('x', 0.50, 0.04, 10.0, 4.2),
      ('x', 0.30, 0.95, 15.0, 4.9),
      // O marks
      ('o', 0.82, 0.22, 16.0, 0.3),
      ('o', 0.10, 0.35, 14.0, 1.0),
      ('o', 0.93, 0.68, 18.0, 1.7),
      ('o', 0.18, 0.72, 12.0, 2.4),
      ('o', 0.60, 0.97, 16.0, 3.1),
      ('o', 0.40, 0.02, 12.0, 3.8),
      ('o', 0.88, 0.50, 10.0, 4.5),
    ];
    for (final (kind, xRel, yRel, r, p) in items) {
      final bobY = math.sin(phase + p * 0.5) * (r * 0.18);
      final x = w * xRel;
      final y = h * yRel + bobY;
      if (kind == 'x') {
        drawX(x, y, r, p);
      } else {
        drawO(x, y, r, p);
      }
    }

    // Mini grids
    drawMiniGrid(w * 0.70, h * 0.02 + math.sin(phase + 0.5) * 4, 48, 0.5);
    drawMiniGrid(w * 0.02, h * 0.90 + math.sin(phase + 2.5) * 3, 40, 2.5);
    drawMiniGrid(w * 0.78, h * 0.75 + math.sin(phase + 4.5) * 4, 36, 4.5);
  }
}

// ── Difficulty palette ─────────────────────────────────────────────────────
const Color _kEasyColor   = Color(0xFF22C55E); // fresh green
const Color _kMediumColor = Color(0xFFF59E0B); // amber
const Color _kHardColor   = Color(0xFFEF4444); // vivid red

_DifficultyMeta _difficultyMeta(_Difficulty d) => switch (d) {
      _Difficulty.easy => const _DifficultyMeta(
          label: 'EASY',
          color: _kEasyColor,
        ),
      _Difficulty.medium => const _DifficultyMeta(
          label: 'MEDIUM',
          color: _kMediumColor,
        ),
      _Difficulty.hard => const _DifficultyMeta(
          label: 'HARD',
          color: _kHardColor,
        ),
    };

DifficultyKind _kindFor(_Difficulty d) => switch (d) {
      _Difficulty.easy => DifficultyKind.easy,
      _Difficulty.medium => DifficultyKind.medium,
      _Difficulty.hard => DifficultyKind.hard,
    };

class _DifficultyMeta {
  final String label;
  final Color color;
  const _DifficultyMeta({
    required this.label,
    required this.color,
  });
}

// ════════════════════════════════════════════════════════════════
// BOARD SCREEN (playing state) — custom scoreboard HUD + grid
// ════════════════════════════════════════════════════════════════

class _BoardScreen extends StatelessWidget {
  final List<String> board;
  final String currentPlayer;
  final _Mode mode;
  final _Difficulty difficulty;
  final int xWins;
  final int oWins;
  final bool aiThinking;
  final List<int> winLine;
  final AnimationController winLineCtrl;
  final String? bannerLabel;
  final Color bannerColor;
  final bool celebrating;
  final int streak;
  final bool showStreakBadge;
  final ValueChanged<int> onCellTap;
  final VoidCallback onBack;
  final VoidCallback onRestart;

  const _BoardScreen({
    required this.board,
    required this.currentPlayer,
    required this.mode,
    required this.difficulty,
    required this.xWins,
    required this.oWins,
    required this.aiThinking,
    required this.winLine,
    required this.winLineCtrl,
    required this.bannerLabel,
    required this.bannerColor,
    required this.celebrating,
    required this.streak,
    required this.showStreakBadge,
    required this.onCellTap,
    required this.onBack,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    // Turn-aware ambient tint:
    //   X turn → warm coral
    //   O turn → cool cyan
    //   Game over (no clear current turn) → neutral.
    final isXTurn = currentPlayer == 'X';
    final topColor = (bannerLabel != null)
        ? _kTintNeutralTop
        : (isXTurn ? _kTintWarmTop : _kTintCoolTop);
    final botColor = (bannerLabel != null)
        ? _kTintNeutralBot
        : (isXTurn ? _kTintWarmBot : _kTintCoolBot);

    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      tween: ColorTween(end: topColor),
      builder: (context, animTop, _) {
        return TweenAnimationBuilder<Color?>(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOut,
          tween: ColorTween(end: botColor),
          builder: (context, animBot, _) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    animTop ?? topColor,
                    animBot ?? botColor,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Reserve enough top space for the floating tab above
                    // the score pill so it doesn't clip under SafeArea.
                    const SizedBox(height: 12),
                    // Top bar: back button left + score pill centred + restart button right
                    GameHudBar(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      leading: GameBackButton(onTap: onBack),
                      centerContent: _ScoreBoardPill(
                        mode: mode,
                        difficulty: difficulty,
                        xWins: xWins,
                        oWins: oWins,
                      ),
                      trailing: GameRestartButton(
                        gameName: 'Tic Tac Toe',
                        accentColor: _kAiColor,
                        onRestart: onRestart,
                      ),
                    ),
                    // Streak badge appears inline with a small AnimatedSize
                    // so it doesn't reserve space on cramped screens
                    // (e.g. 320 px tall landscape devices).
                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      child: showStreakBadge
                          ? Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: _StreakBadge(streak: streak),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 8),
                    // ── Opponent strip (top) ─────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: PlayerStrip(
                        label: mode == _Mode.ai ? 'AI' : 'P2',
                        mark: 'O',
                        color: _kOColor,
                        isActive: currentPlayer == 'O' && bannerLabel == null,
                        isThinking: aiThinking,
                        avatarIcon: mode == _Mode.ai ? Icons.smart_toy_rounded : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ── Game board ────────────────────────────────────────────
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Stack(
                              children: [
                                _Board(
                                  board: board,
                                  winLine: winLine,
                                  winLineCtrl: winLineCtrl,
                                  onCellTap: onCellTap,
                                ),
                                if (celebrating)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: _Confetti(color: bannerColor),
                                    ),
                                  ),
                                if (bannerLabel != null)
                                  Positioned.fill(
                                    child: Center(
                                      child: _WinBanner(
                                        label: bannerLabel!,
                                        color: bannerColor,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ── Local player strip (bottom) ───────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: PlayerStrip(
                        label: mode == _Mode.ai ? 'You' : 'P1',
                        mark: 'X',
                        color: _kXColor,
                        isActive: currentPlayer == 'X' && bannerLabel == null,
                        isThinking: false,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Streak badge (shown on board when streak >= 2) ─────────────────────────
class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB36B), Color(0xFFFF7A89)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7A89).withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded,
              color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            'Streak $streak',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── New-best celebration chip (shown on the WinnerScreen when a player
// streak surpasses the previous best for the active difficulty) ───────────
class _NewBestBadge extends StatelessWidget {
  const _NewBestBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFC233), Color(0xFFFF8A00)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9500).withValues(alpha: 0.40),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_rounded, color: Colors.white, size: 18),
          SizedBox(width: 6),
          Text(
            'New best!',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Confetti / radial burst on win ─────────────────────────────────────────
class _Confetti extends StatefulWidget {
  final Color color;
  const _Confetti({required this.color});

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_ConfettiParticle> _particles;
  static final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _particles = List.generate(36, (i) {
      final angle = (i / 36) * math.pi * 2 + _rng.nextDouble() * 0.5;
      final speed = 0.55 + _rng.nextDouble() * 0.35;
      final size = 3.0 + _rng.nextDouble() * 4.0;
      final hueShift = _rng.nextDouble();
      return _ConfettiParticle(
        angle: angle,
        speed: speed,
        size: size,
        hueShift: hueShift,
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => CustomPaint(
        painter: _ConfettiPainter(
          progress: _ctrl.value,
          particles: _particles,
          baseColor: widget.color,
        ),
      ),
    );
  }
}

class _ConfettiParticle {
  final double angle;
  final double speed;
  final double size;
  final double hueShift;
  _ConfettiParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.hueShift,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiParticle> particles;
  final Color baseColor;

  _ConfettiPainter({
    required this.progress,
    required this.particles,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide * 0.55;
    // Eased outward motion + fade-out tail.
    final eased = Curves.easeOutCubic.transform(progress.clamp(0, 1));
    final alpha = (1 - progress).clamp(0.0, 1.0);
    for (final p in particles) {
      final r = maxR * eased * p.speed;
      final pos = center + Offset(math.cos(p.angle), math.sin(p.angle)) * r;
      final hsl = HSLColor.fromColor(baseColor);
      final colored = hsl
          .withLightness(
            (hsl.lightness + (p.hueShift - 0.5) * 0.35).clamp(0.35, 0.85),
          )
          .toColor()
          .withValues(alpha: alpha);
      final paint = Paint()..color = colored;
      canvas.drawCircle(pos, p.size * (0.5 + alpha * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ScoreBoardPill extends StatelessWidget {
  final _Mode mode;
  final _Difficulty difficulty;
  final int xWins;
  final int oWins;

  const _ScoreBoardPill({
    required this.mode,
    required this.difficulty,
    required this.xWins,
    required this.oWins,
  });

  @override
  Widget build(BuildContext context) {
    final isAi = mode == _Mode.ai;
    final leftLabel = isAi ? 'YOU' : 'P1';
    final rightLabel = isAi ? 'AI' : 'P2';
    final isAiMode = isAi;
    final meta = isAi ? _difficultyMeta(difficulty) : null;
    final tabLabel = isAi ? meta!.label : 'PASS & PLAY';
    final tabColor = isAi ? meta!.color : const Color(0xFF8475C2);

    // Use a Column so the tab sits cleanly above the pill — previously a
    // Stack overlapped the tab's lower half behind the pill, trimming letters
    // like the descender on "MEDIUM".
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Difficulty / mode tab. Tinted with the difficulty colour so the
        // user can see the active level even on the playing board.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: tabColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            boxShadow: [
              BoxShadow(
                color: tabColor.withValues(alpha: 0.30),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAiMode) ...[
                AnimatedDifficultyIcon(
                  kind: _kindFor(difficulty),
                  size: 14,
                  prominent: false,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                tabLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
        // Score pill — joins the tab via a flat top edge.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8475C2).withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _scoreColumn(leftLabel, xWins, _kXColor),
              const SizedBox(width: 14),
              const Text(
                'VS',
                style: TextStyle(
                  color: Color(0xFF8B7BA7),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 14),
              _scoreColumn(rightLabel, oWins, _kOColor),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scoreColumn(String label, int value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Text(
            '$value',
            key: ValueKey<int>(value),
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _Board extends StatelessWidget {
  final List<String> board;
  final List<int> winLine;
  final AnimationController winLineCtrl;
  final ValueChanged<int> onCellTap;

  const _Board({
    required this.board,
    required this.winLine,
    required this.winLineCtrl,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = math.min(c.maxWidth, c.maxHeight);
        final cell = size / 3;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              // Bold black grid lines (Poki-style).
              CustomPaint(
                size: Size.square(size),
                painter: _GridPainter(),
              ),
              // Cells (tap targets) — ordered 0..8 for finder.byType(GestureDetector).at(i).
              for (int i = 0; i < 9; i++)
                Positioned(
                  left: (i % 3) * cell,
                  top: (i ~/ 3) * cell,
                  width: cell,
                  height: cell,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onCellTap(i),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: anim,
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: board[i].isEmpty
                            ? const SizedBox.shrink(key: ValueKey('empty'))
                            : _Mark(
                                key: ValueKey('${i}_${board[i]}'),
                                player: board[i],
                                size: cell * 0.55,
                              ),
                      ),
                    ),
                  ),
                ),
              // Win line overlay.
              if (winLine.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: winLineCtrl,
                      builder: (_, _) => CustomPaint(
                        painter: _WinLinePainter(
                          line: winLine,
                          cellSize: cell,
                          progress: winLineCtrl.value,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Soft mauve grid lines instead of harsh near-black.
    final paint = Paint()
      ..color = const Color(0xFF8475C2).withValues(alpha: 0.55)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final cell = size.width / 3;
    final inset = cell * 0.10;
    // Two vertical lines.
    canvas.drawLine(
      Offset(cell, inset),
      Offset(cell, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(cell * 2, inset),
      Offset(cell * 2, size.height - inset),
      paint,
    );
    // Two horizontal lines.
    canvas.drawLine(
      Offset(inset, cell),
      Offset(size.width - inset, cell),
      paint,
    );
    canvas.drawLine(
      Offset(inset, cell * 2),
      Offset(size.width - inset, cell * 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

class _Mark extends StatelessWidget {
  final String player;
  final double size;
  const _Mark({super.key, required this.player, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = player == 'X' ? _kXColor : _kOColor;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MarkPainter(player: player, color: color),
        child: Center(
          // Invisible Text used by tests to find marks ('X'/'O').
          child: Text(
            player,
            style: const TextStyle(
              color: Colors.transparent,
              fontSize: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  final String player;
  final Color color;
  _MarkPainter({required this.player, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.16
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (player == 'X') {
      final pad = size.width * 0.16;
      canvas.drawLine(
        Offset(pad, pad),
        Offset(size.width - pad, size.height - pad),
        paint,
      );
      canvas.drawLine(
        Offset(size.width - pad, pad),
        Offset(pad, size.height - pad),
        paint,
      );
    } else {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width * 0.36,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) =>
      oldDelegate.player != player || oldDelegate.color != color;
}

class _WinLinePainter extends CustomPainter {
  final List<int> line;
  final double cellSize;
  final double progress;

  _WinLinePainter({
    required this.line,
    required this.cellSize,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (line.length < 3 || progress <= 0) return;
    Offset cellCenter(int i) =>
        Offset((i % 3) * cellSize + cellSize / 2, (i ~/ 3) * cellSize + cellSize / 2);
    final start = cellCenter(line.first);
    final end = cellCenter(line.last);
    final current = Offset.lerp(start, end, progress.clamp(0.0, 1.0))!;

    final glow = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = cellSize * 0.18
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawLine(start, current, glow);

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = cellSize * 0.10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, current, paint);
  }

  @override
  bool shouldRepaint(covariant _WinLinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.line != line;
}

class _WinBanner extends StatelessWidget {
  final String label;
  final Color color;
  const _WinBanner({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

