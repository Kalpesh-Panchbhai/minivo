import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../game_picker_scaffold.dart';
import '../game_registry.dart';
import '../game_wrapper.dart';
import 'tic_tac_toe_stats.dart';

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
const Color _kFriendColor = Color(0xFFFF5A5F); // warm coral

// ── Design tokens ─────────────────────────────────────────────────────────
const Color _kBgTop    = Color(0xFFFFF9F5);   // warm cream
const Color _kBgBot    = Color(0xFFF8F5FF);   // pale lavender
const Color _kCardBg   = Colors.white;

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
      return _WinnerScreen(
        winner: _winner,
        mode: _mode!,
        difficulty: _difficulty,
        xWins: _xWins,
        oWins: _oWins,
        draws: _draws,
        streak: _streak,
        streakOwner: _streakOwner,
        wasNewBest: _wasNewBest,
        onPlayAgain: _playAgainSameMode,
        onChangeMode: _changeMode,
        onHome: _backOrHome,
      );
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
      bgPainter: _TttBackgroundPainter(),
      iconRingColors: const [Color(0xFF6C4EF3), Color(0xFFFF5A5F), Color(0xFF6C4EF3)],
      iconChild: Builder(builder: (ctx) {
        final info = GameRegistry.getById(kTicTacToeGameId);
        if (info?.iconAsset != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(42),
            child: Image.asset(
              info!.iconAsset!,
              width: 84,
              height: 84,
              fit: BoxFit.cover,
            ),
          );
        }
        return const Icon(Icons.close_rounded, size: 40, color: Color(0xFF6C4EF3));
      }),
      title: 'Tic Tac Toe',
      subtitle: 'Three in a row wins.',
      onBack: onBack,
      isFavorite: isFavorite,
      onFavoriteToggle: onFavoriteToggle,
      onHelp: onHelp,
      onHowToPlay: onHelp,
      tallThreshold: 860,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AiSection(
            difficulty: difficulty,
            onDifficultyChanged: onDifficultyChanged,
            onPlayAi: onPlayAi,
          ),
          const SizedBox(height: 12),
          _GameButton(
            label: 'Play with a Friend',
            sublabel: 'Pass & play on one device',
            icon: Icons.people_alt_rounded,
            gradientColors: const [_kFriendColor, Color(0xFFFF8E53)],
            onTap: onPlayFriend,
          ),
        ],
      ),
    );
  }
}

class _AiSection extends StatelessWidget {
  final _Difficulty difficulty;
  final ValueChanged<_Difficulty> onDifficultyChanged;
  final VoidCallback onPlayAi;
  const _AiSection({
    required this.difficulty,
    required this.onDifficultyChanged,
    required this.onPlayAi,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Difficulty card — white, elevated, with a colored top accent bar
        Container(
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: _kAiColor.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: Column(
                  children: [
                    // Eyebrow
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _kAiColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.smart_toy_rounded, size: 16, color: _kAiColor),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI DIFFICULTY',
                          style: TextStyle(
                            color: _kAiColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _DifficultyLabel(difficulty: difficulty),
                    const SizedBox(height: 14),
                    _DifficultyTrack(
                      difficulty: difficulty,
                      onChanged: onDifficultyChanged,
                    ),
                    const SizedBox(height: 8),
                    _DifficultyHint(difficulty: difficulty),
                    const SizedBox(height: 10),
                    _BestStreakPill(difficulty: difficulty),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Play vs AI button — flat top, attached to the card
        _GameButton(
          label: 'Play vs. AI',
          sublabel: 'Single player',
          icon: Icons.smart_toy_rounded,
          gradientColors: [_kAiColor, Color(0xFF8B72F8)],
          onTap: onPlayAi,
          topRadius: 0,
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 320.ms)
            .slideY(begin: 0.08, end: 0, duration: 320.ms),
      ],
    );
  }
}

// Personal-best pill displayed under each difficulty inside the AI card.
// Reads from ScoreService on every build, so it reflects the active
// difficulty in real time as the slider moves and updates immediately when
// the player returns from a round that beat the previous best.
class _BestStreakPill extends StatelessWidget {
  final _Difficulty difficulty;
  const _BestStreakPill({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final meta = _difficultyMeta(difficulty);
    final subKey = switch (difficulty) {
      _Difficulty.easy => kTicTacToeSubKeyEasy,
      _Difficulty.medium => kTicTacToeSubKeyMedium,
      _Difficulty.hard => kTicTacToeSubKeyHard,
    };
    final best = bestStreak(subKey);

    // Cross-fade between an aspirational empty state and the trophy state
    // so it doesn't pop in / out as the user explores difficulties.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: Container(
        key: ValueKey('best_${meta.label}_$best'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: best > 0
              ? meta.color.withValues(alpha: 0.14)
              : const Color(0xFF8B7BA7).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: best > 0
                ? meta.color.withValues(alpha: 0.40)
                : const Color(0xFF8B7BA7).withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              best > 0
                  ? Icons.local_fire_department_rounded
                  : Icons.flag_outlined,
              size: 14,
              color: best > 0 ? meta.color : const Color(0xFF8B7BA7),
            ),
            const SizedBox(width: 6),
            // Flexible+ellipsis so the pill never overflows on narrow phones —
            // the message is short enough to fit comfortably on every device
            // we test, but this is the safe belt-and-braces guard.
            Flexible(
              child: Text(
                best > 0
                    ? 'Best $best in a row'
                    : 'Set your first best!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: best > 0 ? meta.color : const Color(0xFF6B5E7E),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyHint extends StatelessWidget {
  final _Difficulty difficulty;
  const _DifficultyHint({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final text = switch (difficulty) {
      _Difficulty.easy => 'Mostly random — easy to beat.',
      _Difficulty.medium => 'Plays smart but not perfect.',
      _Difficulty.hard => 'Plays sharp — clever players can still win.',
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Padding(
        key: ValueKey(text),
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF6B5E7E),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TttBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
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

    void drawX(double cx, double cy, double r) {
      canvas.drawLine(Offset(cx - r, cy - r), Offset(cx + r, cy + r), xPaint);
      canvas.drawLine(Offset(cx + r, cy - r), Offset(cx - r, cy + r), xPaint);
    }

    void drawO(double cx, double cy, double r) {
      canvas.drawCircle(Offset(cx, cy), r, oPaint);
    }

    void drawMiniGrid(double cx, double cy, double size) {
      final t = size / 3;
      canvas.drawLine(Offset(cx + t, cy), Offset(cx + t, cy + size), gridPaint);
      canvas.drawLine(Offset(cx + t * 2, cy), Offset(cx + t * 2, cy + size), gridPaint);
      canvas.drawLine(Offset(cx, cy + t), Offset(cx + size, cy + t), gridPaint);
      canvas.drawLine(Offset(cx, cy + t * 2), Offset(cx + size, cy + t * 2), gridPaint);
    }

    final w = size.width;
    final h = size.height;

    // Scatter X's
    drawX(w * 0.08, h * 0.12, 18);
    drawX(w * 0.88, h * 0.08, 14);
    drawX(w * 0.15, h * 0.55, 12);
    drawX(w * 0.92, h * 0.42, 20);
    drawX(w * 0.05, h * 0.80, 16);
    drawX(w * 0.75, h * 0.90, 13);
    drawX(w * 0.50, h * 0.04, 10);
    drawX(w * 0.30, h * 0.95, 15);

    // Scatter O's
    drawO(w * 0.82, h * 0.22, 16);
    drawO(w * 0.10, h * 0.35, 14);
    drawO(w * 0.93, h * 0.68, 18);
    drawO(w * 0.18, h * 0.72, 12);
    drawO(w * 0.60, h * 0.97, 16);
    drawO(w * 0.40, h * 0.02, 12);
    drawO(w * 0.88, h * 0.50, 10);

    // Mini grids
    drawMiniGrid(w * 0.70, h * 0.02, 48);
    drawMiniGrid(w * 0.02, h * 0.90, 40);
    drawMiniGrid(w * 0.78, h * 0.75, 36);
  }

  @override
  bool shouldRepaint(covariant _TttBackgroundPainter old) => false;
}

// ── Difficulty palette ─────────────────────────────────────────────────────
const Color _kEasyColor   = Color(0xFF22C55E); // fresh green
const Color _kMediumColor = Color(0xFFF59E0B); // amber
const Color _kHardColor   = Color(0xFFEF4444); // vivid red

_DifficultyMeta _difficultyMeta(_Difficulty d) => switch (d) {
      _Difficulty.easy => const _DifficultyMeta(
          label: 'EASY',
          emoji: '🌱',
          color: _kEasyColor,
        ),
      _Difficulty.medium => const _DifficultyMeta(
          label: 'MEDIUM',
          emoji: '🔥',
          color: _kMediumColor,
        ),
      _Difficulty.hard => const _DifficultyMeta(
          label: 'HARD',
          emoji: '💀',
          color: _kHardColor,
        ),
    };

class _DifficultyMeta {
  final String label;
  final String emoji;
  final Color color;
  const _DifficultyMeta({
    required this.label,
    required this.emoji,
    required this.color,
  });
}

class _DifficultyLabel extends StatelessWidget {
  final _Difficulty difficulty;
  const _DifficultyLabel({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final meta = _difficultyMeta(difficulty);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: anim, child: child),
      ),
      child: Container(
        key: ValueKey(meta.label),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: meta.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: meta.color.withValues(alpha: 0.30), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(meta.emoji, style: const TextStyle(fontSize: 26, height: 1.0)),
            const SizedBox(width: 10),
            Text(
              meta.label,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: meta.color,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyTrack extends StatelessWidget {
  final _Difficulty difficulty;
  final ValueChanged<_Difficulty> onChanged;

  const _DifficultyTrack({required this.difficulty, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const values = _Difficulty.values;
    final activeIndex = values.indexOf(difficulty);
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        const trackHeight = 44.0;
        const knob = 36.0;
        final stops = [
          knob / 2,
          width / 2,
          width - knob / 2,
        ];
        final left = stops[activeIndex] - knob / 2;

        // Pick the closest stop for a given x and notify if it changed.
        void snapTo(double dx) {
          final i = stops
              .asMap()
              .entries
              .reduce(
                (a, b) => (dx - a.value).abs() < (dx - b.value).abs() ? a : b,
              )
              .key;
          if (values[i] != difficulty) onChanged(values[i]);
        }

        final activeColor = _difficultyMeta(difficulty).color;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => snapTo(d.localPosition.dx),
          // Live drag: continuously snap to the nearest stop as the finger
          // moves so the knob feels like it's following the touch.
          onHorizontalDragStart: (d) => snapTo(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => snapTo(d.localPosition.dx),
          child: SizedBox(
            height: trackHeight,
            width: width,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Track (neutral mauve baseline).
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2DAEE),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                // Animated coloured progress fill — green at easy, fades
                // through orange to red as the knob slides right. Always
                // emits ≥ 2 colours since LinearGradient.lerp (used by
                // AnimatedContainer) asserts on a single-colour list.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(left: 4),
                  height: 14,
                  width: (stops[activeIndex] - 4).clamp(0.0, width - 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: switch (difficulty) {
                        _Difficulty.easy => const [_kEasyColor, _kEasyColor],
                        _Difficulty.medium =>
                          const [_kEasyColor, _kMediumColor],
                        _Difficulty.hard => const [
                            _kEasyColor,
                            _kMediumColor,
                            _kHardColor,
                          ],
                      },
                    ),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                // Stop markers — small dots at each step.
                for (int i = 0; i < stops.length; i++)
                  Positioned(
                    left: stops[i] - 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i <= activeIndex
                            ? Colors.white
                            : const Color(0xFF8475C2).withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                // Animated knob — colour matches the active difficulty.
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: left,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    width: knob,
                    height: knob,
                    decoration: BoxDecoration(
                      color: activeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.40),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Gradient CTA button used for both "Play vs. AI" and "Play with a Friend".
class _GameButton extends StatefulWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final double topRadius;

  const _GameButton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
    this.topRadius = 22,
  });

  @override
  State<_GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<_GameButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: Radius.circular(widget.topRadius),
      topRight: Radius.circular(widget.topRadius),
      bottomLeft: const Radius.circular(22),
      bottomRight: const Radius.circular(22),
    );
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors.first.withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: 0.3,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.sublabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
                    // Top bar: score pill centred + pause button right.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          const SizedBox(width: 48),
                          Expanded(
                            child: Center(
                              child: _ScoreBoardPill(
                                mode: mode,
                                difficulty: difficulty,
                                xWins: xWins,
                                oWins: oWins,
                              ),
                            ),
                          ),
                          const GamePauseButton(),
                        ],
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
                    _TurnIndicator(
                      mode: mode,
                      currentPlayer: currentPlayer,
                      aiThinking: aiThinking,
                    ),
                    const SizedBox(height: 12),
                    // Board with celebration burst overlay.
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(28),
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
                                      child: _Confetti(
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
                    // Banner reserved area to avoid layout shift.
                    SizedBox(
                      height: 64,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: anim,
                            child:
                                FadeTransition(opacity: anim, child: child),
                          ),
                          child: bannerLabel == null
                              ? const SizedBox.shrink()
                              : _WinBanner(
                                  label: bannerLabel!,
                                  color: bannerColor,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                Text(meta!.emoji, style: const TextStyle(fontSize: 12)),
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

// Modern turn indicator: two side-by-side player chips. The active player's
// chip glows + scales up; the inactive chip dims and shrinks. No prose label
// is needed — the visual state alone communicates whose turn it is.
class _TurnIndicator extends StatelessWidget {
  final _Mode mode;
  final String currentPlayer;
  final bool aiThinking;

  const _TurnIndicator({
    required this.mode,
    required this.currentPlayer,
    required this.aiThinking,
  });

  @override
  Widget build(BuildContext context) {
    final isAi = mode == _Mode.ai;
    final leftLabel = isAi ? 'YOU' : 'P1';
    final rightLabel = isAi ? 'AI' : 'P2';

    // In AI mode, "active" reflects whose turn — when AI is thinking the AI
    // chip is the active one (glows). Otherwise it's the player whose mark
    // matches `currentPlayer`.
    final leftActive = aiThinking ? false : currentPlayer == 'X';
    final rightActive = !leftActive;

    // Each player gets a chip + a Material-style underline pill that grows
    // when active and retracts when inactive — same UX pattern used by
    // Words With Friends / chess apps. The chip's own scale + halo carry the
    // primary signal; the underline confirms direction without a central
    // arrow competing for attention.
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PlayerSlot(
          label: leftLabel,
          mark: 'X',
          color: _kXColor,
          active: leftActive,
          showThinking: false,
        ),
        const SizedBox(width: 22),
        _PlayerSlot(
          label: rightLabel,
          mark: 'O',
          color: _kOColor,
          active: rightActive,
          showThinking: isAi && aiThinking,
        ),
      ],
    );
  }
}

// Chip + underline indicator. Underline grows from 0 → 28 px under the
// active player, retracts under the inactive one.
class _PlayerSlot extends StatelessWidget {
  final String label;
  final String mark;
  final Color color;
  final bool active;
  final bool showThinking;
  const _PlayerSlot({
    required this.label,
    required this.mark,
    required this.color,
    required this.active,
    required this.showThinking,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PlayerChip(
          label: label,
          mark: mark,
          color: color,
          active: active,
          showThinking: showThinking,
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          width: active ? 28 : 0,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        ),
      ],
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final String label;
  final String mark;
  final Color color;
  final bool active;
  final bool showThinking;
  const _PlayerChip({
    required this.label,
    required this.mark,
    required this.color,
    required this.active,
    required this.showThinking,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      scale: active ? 1.0 : 0.86,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 240),
        opacity: active ? 1.0 : 0.55,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? color : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: active
                    ? color.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: active ? 14 : 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mark glyph (X or O) — rendered as an icon (not text) so the
              // chip's marker doesn't collide with board-cell text in tests
              // and screen readers.
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  mark == 'X'
                      ? Icons.close_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 14,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              // Thinking dots — only on the AI side while the AI is choosing.
              if (showThinking) ...[
                const SizedBox(width: 6),
                _ThinkingDots(color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Three-dot pulsing indicator used when the AI is choosing a move.
class _ThinkingDots extends StatefulWidget {
  final Color color;
  const _ThinkingDots({required this.color});
  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
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
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_ctrl.value - i * 0.18).clamp(0.0, 1.0);
            final t = (math.sin(phase * math.pi) + 1) / 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: widget.color
                      .withValues(alpha: 0.35 + 0.55 * t),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
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

// ════════════════════════════════════════════════════════════════
// WINNER SCREEN
// ════════════════════════════════════════════════════════════════

class _WinnerScreen extends StatelessWidget {
  final String? winner;
  final _Mode mode;
  final _Difficulty difficulty;
  final int xWins;
  final int oWins;
  final int draws;
  final int streak;
  final String? streakOwner;
  final bool wasNewBest;
  final VoidCallback onPlayAgain;
  final VoidCallback onChangeMode;
  final VoidCallback onHome;

  const _WinnerScreen({
    required this.winner,
    required this.mode,
    required this.difficulty,
    required this.xWins,
    required this.oWins,
    required this.draws,
    required this.streak,
    required this.streakOwner,
    required this.wasNewBest,
    required this.onPlayAgain,
    required this.onChangeMode,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final isAi = mode == _Mode.ai;
    String headline;
    String big;
    Color bigColor;
    if (winner == 'X') {
      headline = isAi ? 'You Win!' : 'Player 1 Wins!';
      big = 'X';
      bigColor = _kXColor;
    } else if (winner == 'O') {
      headline = isAi ? 'AI Wins!' : 'Player 2 Wins!';
      big = 'O';
      bigColor = _kOColor;
    } else {
      headline = "It's a Draw!";
      big = '=';
      bigColor = _kDrawColor;
    }

    // Whether to show a streak callout (only on win, streak >= 2, and the
    // current winner owns the streak).
    final showStreak = streak >= 2 && streakOwner == winner;

    return Container(
      // Soft, tonal celebration gradient — same family as the picker but a
      // little richer to feel rewarding without going dark.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFF6F0FF),
            Color(0xFFEDE3FB),
            Color(0xFFFFE2E8),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Big mark medallion (soft glow that picks up the winner color).
            Container(
              width: 148,
              height: 148,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: bigColor.withValues(alpha: 0.40),
                    blurRadius: 36,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  big,
                  style: TextStyle(
                    color: bigColor,
                    fontSize: 92,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0.4, 0.4),
                  end: const Offset(1.0, 1.0),
                  duration: 480.ms,
                  curve: Curves.easeOutBack,
                )
                .fadeIn(duration: 320.ms),
            const SizedBox(height: 22),
            Text(
              headline,
              style: const TextStyle(
                color: Color(0xFF3A2D55),
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ).animate().fadeIn(delay: 220.ms, duration: 320.ms),
            if (showStreak) ...[
              const SizedBox(height: 10),
              _StreakBadge(streak: streak)
                  .animate()
                  .fadeIn(delay: 280.ms, duration: 320.ms)
                  .scale(
                    begin: const Offset(0.85, 0.85),
                    end: const Offset(1.0, 1.0),
                    duration: 320.ms,
                    curve: Curves.easeOutBack,
                  ),
            ],
            if (wasNewBest) ...[
              const SizedBox(height: 10),
              const _NewBestBadge()
                  .animate()
                  .fadeIn(delay: 360.ms, duration: 320.ms)
                  .scale(
                    begin: const Offset(0.7, 0.7),
                    end: const Offset(1.0, 1.0),
                    duration: 380.ms,
                    curve: Curves.easeOutBack,
                  ),
            ],
            const SizedBox(height: 22),
            _SessionScoreRow(
              mode: mode,
              xWins: xWins,
              oWins: oWins,
              draws: draws,
            ).animate().fadeIn(delay: 320.ms, duration: 320.ms),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ActionButton(
                    label: 'Play Again',
                    icon: Icons.refresh_rounded,
                    onTap: onPlayAgain,
                    filled: true,
                    color: _kAiColor,
                  ),
                  const SizedBox(height: 10),
                  _ActionButton(
                    label: 'Change Mode',
                    icon: Icons.swap_horiz_rounded,
                    onTap: onChangeMode,
                    filled: false,
                  ),
                  const SizedBox(height: 10),
                  _ActionButton(
                    label: 'Home',
                    icon: Icons.home_rounded,
                    onTap: onHome,
                    filled: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SessionScoreRow extends StatelessWidget {
  final _Mode mode;
  final int xWins;
  final int oWins;
  final int draws;

  const _SessionScoreRow({
    required this.mode,
    required this.xWins,
    required this.oWins,
    required this.draws,
  });

  @override
  Widget build(BuildContext context) {
    final isAi = mode == _Mode.ai;
    final left = isAi ? 'YOU' : 'P1';
    final right = isAi ? 'AI' : 'P2';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8475C2).withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stat(left, xWins, _kXColor),
          _divider(),
          _stat('DRAWS', draws, const Color(0xFF8B7BA7)),
          _divider(),
          _stat(right, oWins, _kOColor),
        ],
      ),
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 18),
        width: 1,
        height: 36,
        color: const Color(0xFF8475C2).withValues(alpha: 0.20),
      );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final Color? color;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.filled,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final filledColor = color ?? _kAiColor;
    return Material(
      color: filled ? filledColor : Colors.white.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: filled
            ? BorderSide.none
            : BorderSide(
                color: const Color(0xFF8475C2).withValues(alpha: 0.20),
              ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: filled ? Colors.white : const Color(0xFF5E4F7A),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.white : const Color(0xFF3A2D55),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
