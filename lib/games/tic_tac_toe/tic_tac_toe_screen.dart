import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/multiplayer/player_strip.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/score_service.dart';
import '../framework/game_definition.dart';
import '../framework/game_scaffold.dart';
import '../framework/game_session.dart';
import '../shared/animated_background.dart';
import '../shared/animated_difficulty_icon.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import 'tic_tac_toe_definition.dart';
import 'tic_tac_toe_stats.dart';

// Re-export so other files can keep importing this file for the game id /
// sub-key constants.
export 'tic_tac_toe_stats.dart'
    show
        kTicTacToeGameId,
        kTicTacToeSubKeyEasy,
        kTicTacToeSubKeyMedium,
        kTicTacToeSubKeyHard;

/// Test-only override for the very first starter pick of a session.
/// `'X'` or `'O'` to force; `null` to use the regular random pick.
@visibleForTesting
String? debugFirstStarter;

// ── Player accent colors ──────────────────────────────────────────────────
const Color _kXColor = Color(0xFFE85D75);
const Color _kOColor = Color(0xFF5BC0DE);
const Color _kDrawColor = Color(0xFFB6A5DD);

const Color _kAiColor = Color(0xFF6C4EF3);

// ── Board ambient tints ───────────────────────────────────────────────────
const Color _kTintNeutralTop = Color(0xFFFDEFE3);
const Color _kTintNeutralBot = Color(0xFFFADFD0);
const Color _kTintWarmTop = Color(0xFFFFE0D8);
const Color _kTintWarmBot = Color(0xFFFFC9C0);
const Color _kTintCoolTop = Color(0xFFDDEEF5);
const Color _kTintCoolBot = Color(0xFFC2DEEC);

// ════════════════════════════════════════════════════════════════
// Cross-session series state — preserves win counts and streak across
// "Play Again" without baking them into the per-session GameSession
// (which is recreated each time). Resets when the (mode, difficulty)
// signature changes between sessions.
// ════════════════════════════════════════════════════════════════
class _TttSeries {
  String? signature;
  int xWins = 0;
  int oWins = 0;
  int draws = 0;
  int streak = 0;
  String? streakOwner;
  bool firstRoundOfSession = true;

  void resetFor(String sig) {
    signature = sig;
    xWins = 0;
    oWins = 0;
    draws = 0;
    streak = 0;
    streakOwner = null;
    firstRoundOfSession = true;
  }
}

final _TttSeries _series = _TttSeries();

// ════════════════════════════════════════════════════════════════
// Root — thin wrapper around GameScaffold
// ════════════════════════════════════════════════════════════════

class TicTacToeScreen extends StatelessWidget {
  const TicTacToeScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      GameScaffold(definition: ticTacToeGame);
}

// ════════════════════════════════════════════════════════════════
// Board — playing-state widget driven by GameSession
// ════════════════════════════════════════════════════════════════

class TicTacToeBoard extends StatefulWidget {
  final GameSession session;
  const TicTacToeBoard({required this.session, super.key});

  @override
  State<TicTacToeBoard> createState() => _TicTacToeBoardState();
}

class _TicTacToeBoardState extends State<TicTacToeBoard>
    with TickerProviderStateMixin {
  // Per-round state
  List<String> _board = List.filled(9, '');
  String _currentPlayer = 'X';
  String? _winner;
  List<int> _winLine = [];
  bool _aiThinking = false;
  bool _roundOver = false;
  String? _bannerLabel;
  Color _bannerColor = _kDrawColor;
  bool _celebrating = false;
  bool _showStreakBadge = false;
  bool _wasNewBest = false;
  bool _showResult = false;

  // Round starter
  String _starter = 'X';

  late final AnimationController _winLineCtrl;
  final _audio = AudioService();
  final _rng = math.Random();
  Timer? _aiMoveTimer;
  Timer? _endRoundTimer;
  StreamSubscription<void>? _restartSub;

  bool get _isAi => widget.session.players.mode == PlayerMode.vsAI;
  DifficultyDef get _diff => widget.session.difficulty;

  @override
  void initState() {
    super.initState();
    _winLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    // Maintain or reset the cross-session streak/wins counter based on
    // the active mode + difficulty signature.
    final sig = '${_isAi ? 'ai' : 'friend'}|${_diff.key}';
    if (_series.signature != sig) {
      _series.resetFor(sig);
    }
    _publishSessionScore();

    // React to "Play Again" signals from the framework.
    _restartSub = widget.session.restartSignal.listen((_) {
      if (mounted) _resetBoardForNewRound();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resetBoardForNewRound();
    });
  }

  @override
  void dispose() {
    _aiMoveTimer?.cancel();
    _endRoundTimer?.cancel();
    _restartSub?.cancel();
    _winLineCtrl.dispose();
    super.dispose();
  }

  // ── Score syncing ────────────────────────────────────────────────────────

  /// Publish the active streak (vs-AI) or 0 (vs-Friend) to the session so
  /// the framework's HUD + result screen + best-score persistence see it.
  void _publishSessionScore() {
    if (_isAi) {
      // Streak is "current player's run of consecutive wins". For the
      // BEST score we only care about the human (X) — but currentScore
      // here mirrors any active streak so the HUD can show it. The
      // framework persists `currentScore` to the active sub-key on
      // completeGame(); we only call completeGame() when the human's
      // streak is the active one (see _onWin), so AI runs never overwrite
      // the human's best.
      widget.session.updateScore(_series.streak);
    } else {
      widget.session.updateScore(0);
    }
    widget.session.setCustomData('p1Wins', _series.xWins);
    widget.session.setCustomData('p2Wins', _series.oWins);
    widget.session.setCustomData('draws', _series.draws);
  }

  // ── Round lifecycle ──────────────────────────────────────────────────────

  void _resetBoardForNewRound() {
    setState(() {
      if (_series.firstRoundOfSession) {
        _starter = debugFirstStarter ?? (_rng.nextBool() ? 'X' : 'O');
        _series.firstRoundOfSession = false;
      } else {
        _starter = (_starter == 'X') ? 'O' : 'X';
      }
      _board = List.filled(9, '');
      _currentPlayer = _starter;
      _winner = null;
      _winLine = [];
      _aiThinking = false;
      _roundOver = false;
      _bannerLabel = null;
      _celebrating = false;
      _showStreakBadge = false;
      _showResult = false;
      _wasNewBest = false;
      _winLineCtrl.value = 0;
    });
    if (_isAi && _currentPlayer == 'O') {
      _scheduleAiMove();
    }
  }

  // ── Gameplay ─────────────────────────────────────────────────────────────

  void _onCellTap(int index) {
    if (_roundOver || _board[index].isNotEmpty) return;
    if (_isAi && (_aiThinking || _currentPlayer != 'X')) return;

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

    if (_isAi && _currentPlayer == 'O') {
      _scheduleAiMove();
    }
  }

  void _scheduleAiMove() {
    setState(() => _aiThinking = true);
    final thinkMs = switch (_diff.kind) {
      DifficultyKind.easy => 700,
      DifficultyKind.medium => 900,
      DifficultyKind.hard => 1100,
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
    switch (_diff.kind) {
      case DifficultyKind.easy:
        if (_rng.nextDouble() < 0.7) return _randomMove();
        return _smartMove(useMinimax: false);
      case DifficultyKind.medium:
        return _smartMove(useMinimax: false);
      case DifficultyKind.hard:
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
    final win = _findMoveThatCompletes('O');
    if (win != null) return win;
    final block = _findMoveThatCompletes('X');
    if (block != null) return block;

    if (useMinimax) return _minimaxBestMove();

    if (_board[4].isEmpty) return 4;
    const corners = [0, 2, 6, 8];
    final freeCorners = corners.where((i) => _board[i].isEmpty).toList();
    if (freeCorners.isNotEmpty) {
      return freeCorners[_rng.nextInt(freeCorners.length)];
    }
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
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6],
  ];

  List<int>? _findWinningLine(String player) {
    for (final line in _winningLines) {
      if (line.every((i) => _board[i] == player)) return line;
    }
    return null;
  }

  bool _isBoardFull() => !_board.contains('');

  // ── Round outcome ────────────────────────────────────────────────────────

  void _onWin(List<int> line, String player) {
    setState(() {
      _winLine = line;
      _winner = player;
      _roundOver = true;
      _celebrating = true;
      if (player == 'X') {
        _series.xWins++;
        _bannerLabel = _isAi ? 'You Win!' : 'Player 1 Wins!';
        _bannerColor = _kXColor;
      } else {
        _series.oWins++;
        _bannerLabel = _isAi ? 'AI Wins!' : 'Player 2 Wins!';
        _bannerColor = _kOColor;
      }
      if (_series.streakOwner == player) {
        _series.streak++;
      } else {
        _series.streakOwner = player;
        _series.streak = 1;
      }
      _showStreakBadge = _series.streak >= 2;
    });

    _publishSessionScore();
    _winLineCtrl.forward(from: 0);
    _audio.playSuccess();

    // For vs-AI human wins, detect new best vs the previous stored best
    // before completeGame() persists the new score.
    if (_isAi && player == 'X' && _series.streak > widget.session.bestScore) {
      _wasNewBest = true;
    }

    // Persist the new streak as the best score for this difficulty so it
    // survives across app launches (in addition to whatever the framework
    // does on completeGame()).
    if (_isAi && player == 'X') {
      ScoreService().saveScore(
        kTicTacToeGameId,
        _series.streak,
        subKey: _diff.key,
      );
    }

    _endRoundTimer?.cancel();
    _endRoundTimer = Timer(const Duration(milliseconds: 1700), () {
      if (mounted) _showRoundResult();
    });
  }

  void _onDraw() {
    setState(() {
      _winner = null;
      _series.draws++;
      _series.streak = 0;
      _series.streakOwner = null;
      _showStreakBadge = false;
      _roundOver = true;
      _bannerLabel = "It's a Draw!";
      _bannerColor = _kDrawColor;
    });
    _publishSessionScore();

    _endRoundTimer?.cancel();
    _endRoundTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) _showRoundResult();
    });
  }

  void _showRoundResult() {
    setState(() => _showResult = true);
  }

  void _playAgainSameMode() {
    _resetBoardForNewRound();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_showResult) {
      return _buildRoundResult();
    }
    return _buildBoard();
  }

  Widget _buildBoard() {
    final isXTurn = _currentPlayer == 'X';
    final topColor = (_bannerLabel != null)
        ? _kTintNeutralTop
        : (isXTurn ? _kTintWarmTop : _kTintCoolTop);
    final botColor = (_bannerLabel != null)
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
                  colors: [animTop ?? topColor, animBot ?? botColor],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  // Optional streak badge
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: _showStreakBadge
                        ? Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _StreakBadge(streak: _series.streak),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 8),
                  // Opponent strip (top)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PlayerStrip(
                      label: _isAi ? 'AI' : 'P2',
                      mark: 'O',
                      color: _kOColor,
                      isActive:
                          _currentPlayer == 'O' && _bannerLabel == null,
                      isThinking: _aiThinking,
                      avatarIcon:
                          _isAi ? Icons.smart_toy_rounded : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Board
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: Stack(
                            children: [
                              _Board(
                                board: _board,
                                winLine: _winLine,
                                winLineCtrl: _winLineCtrl,
                                onCellTap: _onCellTap,
                              ),
                              if (_celebrating)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: _Confetti(color: _bannerColor),
                                  ),
                                ),
                              if (_bannerLabel != null)
                                Positioned.fill(
                                  child: Center(
                                    child: _WinBanner(
                                      label: _bannerLabel!,
                                      color: _bannerColor,
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
                  // Local player strip (bottom)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PlayerStrip(
                      label: _isAi ? 'You' : 'P1',
                      mark: 'X',
                      color: _kXColor,
                      isActive:
                          _currentPlayer == 'X' && _bannerLabel == null,
                      isThinking: false,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRoundResult() {
    String headline;
    String big;
    Color bigColor;
    if (_winner == 'X') {
      headline = _isAi ? 'You Win!' : 'Player 1 Wins!';
      big = 'X';
      bigColor = _kXColor;
    } else if (_winner == 'O') {
      headline = _isAi ? 'AI Wins!' : 'Player 2 Wins!';
      big = 'O';
      bigColor = _kOColor;
    } else {
      headline = "It's a Draw!";
      big = '=';
      bigColor = _kDrawColor;
    }

    final showStreak =
        _series.streak >= 2 && _series.streakOwner == _winner;
    final extraBadges = <Widget>[
      if (showStreak) _StreakBadge(streak: _series.streak),
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
          game_result.StatItem(
            label: _isAi ? 'YOU' : 'P1',
            value: _series.xWins,
            color: _kXColor,
          ),
          game_result.StatItem(
            label: 'DRAWS',
            value: _series.draws,
            color: const Color(0xFF8B7BA7),
          ),
          game_result.StatItem(
            label: _isAi ? 'AI' : 'P2',
            value: _series.oWins,
            color: _kOColor,
          ),
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
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Custom HUD score pill — shows X vs O wins with difficulty / mode tab
// ════════════════════════════════════════════════════════════════

class TicTacToeScorePill extends StatelessWidget {
  final GameSession session;
  const TicTacToeScorePill({required this.session, super.key});

  @override
  Widget build(BuildContext context) {
    final isAi = session.players.mode == PlayerMode.vsAI;
    final diff = session.difficulty;
    final leftLabel = isAi ? 'YOU' : 'P1';
    final rightLabel = isAi ? 'AI' : 'P2';
    final tabLabel = isAi ? diff.label : 'PASS & PLAY';
    final tabColor = isAi ? diff.color : const Color(0xFF8475C2);

    final xWins = session.getCustomData<int>('p1Wins') ?? 0;
    final oWins = session.getCustomData<int>('p2Wins') ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: tabColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(10)),
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
              if (isAi) ...[
                AnimatedDifficultyIcon(
                  kind: diff.kind,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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

// ════════════════════════════════════════════════════════════════
// Animated TTT picker background
// ════════════════════════════════════════════════════════════════

class TicTacToeBgPainter extends AnimatedBgPainter {
  const TicTacToeBgPainter(super.t);

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
      final rot = math.sin(phase + itemPhase) * 0.12;
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

    final items = [
      ('x', 0.08, 0.12, 18.0, 0.0),
      ('x', 0.88, 0.08, 14.0, 0.7),
      ('x', 0.15, 0.55, 12.0, 1.4),
      ('x', 0.92, 0.42, 20.0, 2.1),
      ('x', 0.05, 0.80, 16.0, 2.8),
      ('x', 0.75, 0.90, 13.0, 3.5),
      ('x', 0.50, 0.04, 10.0, 4.2),
      ('x', 0.30, 0.95, 15.0, 4.9),
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

    drawMiniGrid(w * 0.70, h * 0.02 + math.sin(phase + 0.5) * 4, 48, 0.5);
    drawMiniGrid(w * 0.02, h * 0.90 + math.sin(phase + 2.5) * 3, 40, 2.5);
    drawMiniGrid(w * 0.78, h * 0.75 + math.sin(phase + 4.5) * 4, 36, 4.5);
  }
}

// ════════════════════════════════════════════════════════════════
// Streak / new-best badges, board, marks, win line, banner, confetti
// ════════════════════════════════════════════════════════════════

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
              CustomPaint(
                size: Size.square(size),
                painter: _GridPainter(),
              ),
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
    final paint = Paint()
      ..color = const Color(0xFF8475C2).withValues(alpha: 0.55)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final cell = size.width / 3;
    final inset = cell * 0.10;
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
        Offset((i % 3) * cellSize + cellSize / 2,
            (i ~/ 3) * cellSize + cellSize / 2);
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

