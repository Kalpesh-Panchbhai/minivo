import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/multiplayer/player_strip.dart';
import '../../core/services/ads_service.dart';
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
import 'gomoku_stats.dart';
import 'gomoku_tutorial.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/rewarded_undo_button.dart';

const Color _kBlackColor = Color(0xFF212121);
const Color _kWhiteColor = Color(0xFF757575);
const Color _kDrawColor = Color(0xFFB6A5DD);
const Color _kAiColor = Color(0xFF4A90D9);
const Color _kBgTop = Color(0xFFF0F5FF);
const Color _kBgBot = Color(0xFFE0EAFC);
const Color _kLineColor = Color(0xFF4A90D9);
const Color _kEasyColor = Color(0xFF22C55E);
const Color _kMediumColor = Color(0xFFF59E0B);
const Color _kHardColor = Color(0xFFEF4444);

const Color _kTintBlackTop = Color(0xFFEBEFF7);
const Color _kTintBlackBot = Color(0xFFDDE4F2);
const Color _kTintWhiteTop = Color(0xFFF3F0F8);
const Color _kTintWhiteBot = Color(0xFFE8E3F2);
const Color _kTintNeutralTop = Color(0xFFF0F5FF);
const Color _kTintNeutralBot = Color(0xFFE0EAFC);

enum _Mode { ai, twoPlayer }
enum _Difficulty { easy, medium, hard }

class GomokuScreen extends StatefulWidget {
  const GomokuScreen({super.key});
  @override
  State<GomokuScreen> createState() => _GomokuScreenState();
}

class _GomokuScreenState extends State<GomokuScreen> {
  static const _gridSize = 13;
  static const _totalCells = _gridSize * _gridSize;
  static const _winLength = 5;

  _Mode? _mode;
  _Difficulty _difficulty = _Difficulty.values[DifficultyKind.defaultIndex];

  List<int> _board = List.filled(_totalCells, 0); // 0=empty, 1=black, 2=white
  int _currentPlayer = 1;
  bool _gameOver = false;
  int? _winner;
  List<int> _winLine = [];
  bool _aiThinking = false;
  int _blackWins = 0;
  int _whiteWins = 0;
  int _draws = 0;
  int _streak = 0;
  String? _streakOwner;
  bool _wasNewBest = false;
  bool _isFavorite = false;
  bool _firstRoundOfSession = true;
  String _starter = 'black';
  bool _showStreakBadge = false;
  bool _celebrating = false;
  String? _bannerLabel;
  Color _bannerColor = _kDrawColor;
  bool _showWinBanner = false;
  int _moveCount = 0;

  int? _lastHumanMoveIdx;
  bool _undoUsedThisRound = false;
  bool _inUndoWindow = false;

  final _rng = math.Random();
  final _audio = AudioService();
  Timer? _aiMoveTimer;
  Timer? _endGameTimer;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kGomokuGameId);
  }

  @override
  void dispose() {
    _aiMoveTimer?.cancel();
    _endGameTimer?.cancel();
    super.dispose();
  }

  GameWrapperState get _wrapper => GameWrapper.of(context);

  void _selectMode(_Mode mode) {
    setState(() {
      _mode = mode;
      _blackWins = 0;
      _whiteWins = 0;
      _draws = 0;
      _streak = 0;
      _streakOwner = null;
      _showStreakBadge = false;
      _firstRoundOfSession = true;
    });
    _resetBoard();
    _wrapper.setDifficultyAndMode(
      difficulty: _diffLabel(_difficulty),
      mode: mode == _Mode.ai ? 'ai' : '2_player',
      subKey: _aiSubKey(),
    );
    _wrapper.startGame();
  }

  void _changeMode() {
    setState(() {
      _mode = null;
      _blackWins = 0;
      _whiteWins = 0;
      _draws = 0;
      _streak = 0;
      _streakOwner = null;
      _showStreakBadge = false;
      _firstRoundOfSession = true;
    });
    _wrapper.restartGame();
  }

  void _playAgain() {
    _resetBoard();
    _wrapper.setDifficultyAndMode(
      difficulty: _diffLabel(_difficulty),
      mode: _mode == _Mode.ai ? 'ai' : '2_player',
      subKey: _aiSubKey(),
    );
    _wrapper.restartGame();
    _wrapper.startGame();
  }

  void _resetBoard() {
    _aiMoveTimer?.cancel();
    _endGameTimer?.cancel();
    setState(() {
      _board = List.filled(_totalCells, 0);
      if (_firstRoundOfSession) {
        _starter = _rng.nextBool() ? 'black' : 'white';
        _firstRoundOfSession = false;
      } else {
        _starter = _starter == 'black' ? 'white' : 'black';
      }
      _currentPlayer = _starter == 'black' ? 1 : 2;
      _gameOver = false;
      _winner = null;
      _winLine = [];
      _aiThinking = false;
      _wasNewBest = false;
      _showStreakBadge = false;
      _celebrating = false;
      _showWinBanner = false;
      _bannerLabel = null;
      _moveCount = 0;
      _lastHumanMoveIdx = null;
      _undoUsedThisRound = false;
      _inUndoWindow = false;
    });
    if (_mode == _Mode.ai && _currentPlayer == 2) _scheduleAiMove();
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
      ScoreService().toggleFavorite(kGomokuGameId);
    });
    _audio.playTap();
  }

  void _backOrHome() {
    _wrapper.handleExit(() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    });
  }

  void _showHelp() {
    final game = GameRegistry.getById(kGomokuGameId);
    if (game == null) return;
    showHowToPlaySheet(context, title: game.name, howToPlay: game.howToPlay,
      accent: _kAiColor, steps: gomokuSteps(), gameId: kGomokuGameId);
  }

  // ── Undo ──

  bool get _canUndo => _inUndoWindow && !_gameOver;

  void _onUndoExpired() {
    if (!mounted || _gameOver || !_inUndoWindow) return;
    setState(() => _inUndoWindow = false);
    _scheduleAiMove();
  }

  void _performUndo() {
    final idx = _lastHumanMoveIdx;
    if (idx == null) return;
    setState(() {
      _board[idx] = 0;
      _moveCount--;
      _currentPlayer = 1;
      _inUndoWindow = false;
      _lastHumanMoveIdx = null;
      _undoUsedThisRound = true;
    });
  }

  // ── Game Logic ──

  void _onCellTap(int pos) {
    if (_gameOver || _aiThinking) return;
    if (_mode == _Mode.ai && (_inUndoWindow || _currentPlayer == 2)) return;
    if (_board[pos] != 0) return;

    _placeStone(pos);
  }

  void _placeStone(int pos) {
    setState(() {
      _board[pos] = _currentPlayer;
      _moveCount++;
    });
    _audio.playTap();

    final line = _findWinLine(pos, _currentPlayer);
    if (line != null) {
      _onWin(_currentPlayer, line);
      return;
    }

    if (_moveCount >= _totalCells) {
      _onDraw();
      return;
    }

    final undoAvailable = _mode == _Mode.ai && _currentPlayer == 1
        && !_undoUsedThisRound && AdsService().isRewardedReady;

    setState(() {
      _currentPlayer = _currentPlayer == 1 ? 2 : 1;
      if (_currentPlayer == 2 && _mode == _Mode.ai) _lastHumanMoveIdx = pos;
    });

    if (_mode == _Mode.ai && _currentPlayer == 2 && !_gameOver) {
      if (undoAvailable) {
        setState(() => _inUndoWindow = true);
      } else {
        _scheduleAiMove();
      }
    }
  }

  List<int>? _findWinLine(int pos, int player) {
    final r = pos ~/ _gridSize;
    final c = pos % _gridSize;
    const dirs = [
      [0, 1], [1, 0], [1, 1], [1, -1],
    ];
    for (final d in dirs) {
      final line = <int>[pos];
      for (int sign = -1; sign <= 1; sign += 2) {
        for (int step = 1; step < _winLength; step++) {
          final nr = r + d[0] * step * sign;
          final nc = c + d[1] * step * sign;
          if (nr < 0 || nr >= _gridSize || nc < 0 || nc >= _gridSize) break;
          final ni = nr * _gridSize + nc;
          if (_board[ni] != player) break;
          line.add(ni);
        }
      }
      if (line.length >= _winLength) return line;
    }
    return null;
  }

  void _onWin(int winner, List<int> line) {
    final isAi = _mode == _Mode.ai;
    final label = winner == 1 ? 'black' : 'white';
    setState(() {
      _gameOver = true;
      _winner = winner;
      _winLine = line;
      _showWinBanner = true;
      _celebrating = true;
      if (winner == 1) {
        _blackWins++;
        _bannerLabel = isAi ? 'You Win!' : 'Player 1 Wins!';
        _bannerColor = _kBlackColor;
      } else {
        _whiteWins++;
        _bannerLabel = isAi ? 'AI Wins!' : 'Player 2 Wins!';
        _bannerColor = _kWhiteColor;
      }
      if (_streakOwner == label) {
        _streak++;
      } else {
        _streakOwner = label;
        _streak = 1;
      }
      _showStreakBadge = _streak >= 2;
    });

    if (isAi && winner == 1) {
      final subKey = switch (_difficulty) {
        _Difficulty.easy => kGomokuSubKeyEasy,
        _Difficulty.medium => kGomokuSubKeyMedium,
        _Difficulty.hard => kGomokuSubKeyHard,
      };
      ScoreService().saveScore(kGomokuGameId, _streak, subKey: subKey).then((isNew) {
        if (mounted && isNew) setState(() => _wasNewBest = true);
      });
      _wrapper.updateScore(_streak);
    } else {
      _wasNewBest = false;
    }

    final gameResult = isAi ? (winner == 1 ? 'win' : 'loss') : 'win';
    _audio.playSuccess();
    _endGameTimer?.cancel();
    _endGameTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) _wrapper.endGame(result: gameResult);
    });
  }

  void _onDraw() {
    setState(() {
      _gameOver = true;
      _winner = null;
      _draws++;
      _streak = 0;
      _streakOwner = null;
      _showStreakBadge = false;
      _showWinBanner = true;
      _bannerLabel = "It's a Draw!";
      _bannerColor = _kDrawColor;
      _wasNewBest = false;
    });
    _endGameTimer?.cancel();
    _endGameTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) _wrapper.endGame(result: 'draw');
    });
  }

  // ── AI ──

  void _scheduleAiMove() {
    setState(() => _aiThinking = true);
    final ms = switch (_difficulty) {
      _Difficulty.easy => 500,
      _Difficulty.medium => 800,
      _Difficulty.hard => 1100,
    };
    _aiMoveTimer?.cancel();
    _aiMoveTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted || _gameOver) return;
      _performAiMove();
    });
  }

  void _performAiMove() {
    final empties = <int>[];
    for (int i = 0; i < _totalCells; i++) {
      if (_board[i] == 0) empties.add(i);
    }
    if (empties.isEmpty) {
      setState(() => _aiThinking = false);
      _onDraw();
      return;
    }

    int chosen;
    switch (_difficulty) {
      case _Difficulty.easy:
        chosen = _pickNearby(empties, 0.6);
      case _Difficulty.medium:
        chosen = _pickSmartGomoku(empties, 0.25);
      case _Difficulty.hard:
        chosen = _pickSmartGomoku(empties, 0.05);
    }

    setState(() {
      _aiThinking = false;
      _lastHumanMoveIdx = null;
    });
    _placeStone(chosen);
  }

  int _pickNearby(List<int> empties, double randomFactor) {
    if (_rng.nextDouble() < randomFactor || _moveCount < 2) {
      // Pick near center or existing stones
      final center = _gridSize ~/ 2;
      final centerIdx = center * _gridSize + center;
      if (_board[centerIdx] == 0) return centerIdx;
      return empties[_rng.nextInt(empties.length)];
    }
    return _pickSmartGomoku(empties, 0.5);
  }

  int _pickSmartGomoku(List<int> empties, double randomFactor) {
    if (_rng.nextDouble() < randomFactor) {
      return empties[_rng.nextInt(empties.length)];
    }

    int bestScore = -9999;
    int bestMove = empties.first;

    for (final pos in empties) {
      int score = _evaluatePosition(pos, 2) + _evaluatePosition(pos, 1) * 2;
      final r = pos ~/ _gridSize;
      final c = pos % _gridSize;
      final distCenter = (r - _gridSize ~/ 2).abs() + (c - _gridSize ~/ 2).abs();
      score += math.max(0, 10 - distCenter);
      score += _rng.nextInt(2);

      if (score > bestScore) {
        bestScore = score;
        bestMove = pos;
      }
    }
    return bestMove;
  }

  int _evaluatePosition(int pos, int player) {
    final r = pos ~/ _gridSize;
    final c = pos % _gridSize;
    int totalScore = 0;
    const dirs = [[0, 1], [1, 0], [1, 1], [1, -1]];

    for (final d in dirs) {
      int count = 1;
      int openEnds = 0;

      for (int sign = -1; sign <= 1; sign += 2) {
        bool open = false;
        for (int step = 1; step <= 4; step++) {
          final nr = r + d[0] * step * sign;
          final nc = c + d[1] * step * sign;
          if (nr < 0 || nr >= _gridSize || nc < 0 || nc >= _gridSize) break;
          final ni = nr * _gridSize + nc;
          if (_board[ni] == player) {
            count++;
          } else {
            if (_board[ni] == 0) open = true;
            break;
          }
        }
        if (open) openEnds++;
      }

      if (count >= 5) totalScore += 10000;
      else if (count == 4 && openEnds == 2) totalScore += 5000;
      else if (count == 4 && openEnds == 1) totalScore += 500;
      else if (count == 3 && openEnds == 2) totalScore += 200;
      else if (count == 3 && openEnds == 1) totalScore += 50;
      else if (count == 2 && openEnds == 2) totalScore += 20;
    }
    return totalScore;
  }

  // ── Helpers ──

  String? _aiSubKey() {
    if (_mode != _Mode.ai) return null;
    return switch (_difficulty) {
      _Difficulty.easy => kGomokuSubKeyEasy,
      _Difficulty.medium => kGomokuSubKeyMedium,
      _Difficulty.hard => kGomokuSubKeyHard,
    };
  }

  String _diffLabel(_Difficulty d) => switch (d) {
    _Difficulty.easy => 'EASY',
    _Difficulty.medium => 'MEDIUM',
    _Difficulty.hard => 'HARD',
  };

  Color _diffColor(_Difficulty d) => switch (d) {
    _Difficulty.easy => _kEasyColor,
    _Difficulty.medium => _kMediumColor,
    _Difficulty.hard => _kHardColor,
  };

  DifficultyKind _kindFor(_Difficulty d) => switch (d) {
    _Difficulty.easy => DifficultyKind.easy,
    _Difficulty.medium => DifficultyKind.medium,
    _Difficulty.hard => DifficultyKind.hard,
  };

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final state = _wrapper.state;
    if (state == GameState.ready || _mode == null) return _buildPicker();
    if (state == GameState.gameOver) return _buildResult();
    return _buildGame();
  }

  Widget _buildPicker() {
    return GamePickerScaffold(
      bgColorTop: _kBgTop,
      bgColorBottom: _kBgBot,
      animatedBg: AnimatedBackground(
        factory: (t) => GenericAnimatedBgPainter(t, accent: _kAiColor, icon: Icons.blur_on_rounded),
        period: const Duration(seconds: 9),
      ),
      iconRingColors: const [Color(0xFF4A90D9), Color(0xFF212121), Color(0xFF4A90D9)],
      iconChild: Builder(builder: (ctx) {
        final info = GameRegistry.getById(kGomokuGameId);
        final logo = info?.buildBrandedLogo(size: 84);
        if (logo != null) {
          return ClipRRect(borderRadius: BorderRadius.circular(42), child: logo);
        }
        return const Icon(Icons.blur_on_rounded, size: 40, color: _kAiColor);
      }),
      title: 'Gomoku',
      subtitle: 'Five in a row wins!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kGomokuGameId,
      body: GameAiPickerBody(
        difficulties: _Difficulty.values.map((d) {
          final subKey = switch (d) {
            _Difficulty.easy => kGomokuSubKeyEasy,
            _Difficulty.medium => kGomokuSubKeyMedium,
            _Difficulty.hard => kGomokuSubKeyHard,
          };
          return GameDifficultyData(
            label: _diffLabel(d),
            color: _diffColor(d),
            kind: _kindFor(d),
            hint: switch (d) {
              _Difficulty.easy => 'Places stones near center randomly.',
              _Difficulty.medium => 'Blocks threats and builds lines.',
              _Difficulty.hard => 'Analyzes patterns — very tough!',
            },
            bestScore: bestGomokuStreak(subKey),
            bestLabel: (s) => 'Best $s in a row',
          );
        }).toList(),
        activeIndex: _Difficulty.values.indexOf(_difficulty),
        onChanged: (i) => setState(() => _difficulty = _Difficulty.values[i]),
        onPlayAi: () => _selectMode(_Mode.ai),
        onPlayFriend: () => _selectMode(_Mode.twoPlayer),
        aiGradient: const [Color(0xFF4A90D9), Color(0xFF6FAAE0)],
        friendGradient: const [Color(0xFF424242), Color(0xFF616161)],
      ),
    );
  }

  Widget _buildGame() {
    final isAi = _mode == _Mode.ai;
    final isBlackTurn = _currentPlayer == 1 || _inUndoWindow;
    final topColor = _showWinBanner ? _kTintNeutralTop : (isBlackTurn ? _kTintBlackTop : _kTintWhiteTop);
    final botColor = _showWinBanner ? _kTintNeutralBot : (isBlackTurn ? _kTintBlackBot : _kTintWhiteBot);

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
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [animTop ?? topColor, animBot ?? botColor],
                ),
              ),
      child: SafeArea(
        child: Column(
          children: [
            GameHudBar(
              leading: GameBackButton(onTap: _backOrHome),
              centerContent: _ScoreBoardPill(
                mode: _mode!,
                difficulty: _difficulty,
                blackWins: _blackWins,
                whiteWins: _whiteWins,
              ),
              trailing: GameRestartButton(
                gameName: 'Gomoku',
                accentColor: _kAiColor,
                onRestart: _playAgain,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: _showStreakBadge
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _StreakBadge(streak: _streak),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PlayerStrip(
                label: isAi ? 'AI' : 'Player 2',
                mark: '○',
                color: _kWhiteColor,
                isActive: _currentPlayer == 2 && !_inUndoWindow && !_gameOver,
                isThinking: _aiThinking,
                avatarIcon: isAi ? Icons.smart_toy_rounded : null,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(builder: (context, constraints) {
                      return Stack(
                        children: [
                          _GomokuBoardWidget(
                            board: _board,
                            boardSize: constraints.maxWidth,
                            gridSize: _gridSize,
                            winLine: _winLine,
                            onCellTap: _onCellTap,
                          ),
                          if (_celebrating)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: _Confetti(color: _bannerColor),
                              ),
                            ),
                          if (_showWinBanner && _bannerLabel != null)
                            Positioned.fill(
                              child: Center(
                                child: _WinBanner(
                                  label: _bannerLabel!,
                                  color: _bannerColor,
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PlayerStrip(
                label: isAi ? 'You' : 'Player 1',
                mark: '●',
                color: _kBlackColor,
                isActive: (_currentPlayer == 1 || _inUndoWindow) && !_gameOver,
              ),
            ),
            SizedBox(
              height: 44,
              child: _canUndo
                  ? Center(
                      child: RewardedUndoButton(
                        key: ValueKey('undo_${_board.join()}'),
                        onUndo: _performUndo,
                        onExpired: _onUndoExpired,
                        accentColor: _kBlackColor,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
            );
          },
        );
      },
    );
  }

  Widget _buildResult() {
    final isAi = _mode == _Mode.ai;
    String headline;
    String big;
    Color bigColor;
    if (_winner == 1) {
      headline = isAi ? 'You Win!' : 'Player 1 Wins!';
      big = '●';
      bigColor = _kBlackColor;
    } else if (_winner == 2) {
      headline = isAi ? 'AI Wins!' : 'Player 2 Wins!';
      big = '○';
      bigColor = _kWhiteColor;
    } else {
      headline = "It's a Draw!";
      big = '=';
      bigColor = _kDrawColor;
    }

    final showStreak = _streak >= 2 && ((_winner == 1 && _streakOwner == 'black') || (_winner == 2 && _streakOwner == 'white'));
    final extraBadges = <Widget>[
      if (showStreak) _StreakBadge(streak: _streak),
      if (_wasNewBest) const _NewBestBadge(),
    ];

    return game_result.GenericGameResultScreen(
      gameId: kGomokuGameId,
      score: _streak,
      headline: headline,
      badgeContent: big,
      badgeColor: bigColor,
      showNewBestBadge: false,
      extraBadges: extraBadges,
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(label: isAi ? 'YOU' : 'P1', value: _blackWins, color: _kBlackColor),
          game_result.StatItem(label: 'DRAWS', value: _draws, color: const Color(0xFF8B7BA7)),
          game_result.StatItem(label: isAi ? 'AI' : 'P2', value: _whiteWins, color: _kWhiteColor),
          if (isAi)
            game_result.StatItem(
              label: 'BEST',
              value: ScoreService().getHighScore(kGomokuGameId, subKey: _aiSubKey()),
              color: const Color(0xFF6C63FF),
            ),
        ],
      ),
      actions: [
        game_result.GameResultAction(
          label: 'Play Again', icon: Icons.refresh_rounded, onTap: _playAgain,
          filled: true, color: _kAiColor, actionId: 'play_again',
        ),
        game_result.GameResultAction(
          label: 'Change Mode', icon: Icons.swap_horiz_rounded, onTap: _changeMode, actionId: 'change_mode',
        ),
        game_result.GameResultAction(
          label: 'Home', icon: Icons.home_rounded, onTap: _backOrHome, actionId: 'home',
        ),
      ],
    );
  }
}

// ── Score Board Pill (with difficulty tab) ──

class _ScoreBoardPill extends StatelessWidget {
  final _Mode mode;
  final _Difficulty difficulty;
  final int blackWins;
  final int whiteWins;

  const _ScoreBoardPill({
    required this.mode,
    required this.difficulty,
    required this.blackWins,
    required this.whiteWins,
  });

  @override
  Widget build(BuildContext context) {
    final isAi = mode == _Mode.ai;
    final leftLabel = isAi ? 'YOU' : 'P1';
    final rightLabel = isAi ? 'AI' : 'P2';
    final tabLabel = isAi
        ? switch (difficulty) {
            _Difficulty.easy => 'EASY',
            _Difficulty.medium => 'MEDIUM',
            _Difficulty.hard => 'HARD',
          }
        : 'PASS & PLAY';
    final tabColor = isAi
        ? switch (difficulty) {
            _Difficulty.easy => _kEasyColor,
            _Difficulty.medium => _kMediumColor,
            _Difficulty.hard => _kHardColor,
          }
        : const Color(0xFF8B7558);
    final diffKind = switch (difficulty) {
      _Difficulty.easy => DifficultyKind.easy,
      _Difficulty.medium => DifficultyKind.medium,
      _Difficulty.hard => DifficultyKind.hard,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: tabColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            boxShadow: [BoxShadow(color: tabColor.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAi) ...[AnimatedDifficultyIcon(kind: diffKind, size: 14, prominent: false), const SizedBox(width: 6)],
              Text(tabLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _kAiColor.withValues(alpha: 0.14), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _scoreColumn(leftLabel, blackWins, _kBlackColor),
                  const SizedBox(width: 14),
                  const Text('VS', style: TextStyle(color: Color(0xFF8B7BA7), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  const SizedBox(width: 14),
                  _scoreColumn(rightLabel, whiteWins, _kWhiteColor),
                ],
              ),
              if (isAi) _bestLabel(difficulty),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bestLabel(_Difficulty d) {
    final subKey = switch (d) {
      _Difficulty.easy => kGomokuSubKeyEasy,
      _Difficulty.medium => kGomokuSubKeyMedium,
      _Difficulty.hard => kGomokuSubKeyHard,
    };
    final best = ScoreService().getHighScore(kGomokuGameId, subKey: subKey);
    if (best <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text('best $best',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _scoreColumn(String label, int value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
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
            style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900, height: 1),
          ),
        ),
      ],
    );
  }
}

// ── Board Widget ──

class _GomokuBoardWidget extends StatelessWidget {
  final List<int> board;
  final double boardSize;
  final int gridSize;
  final List<int> winLine;
  final ValueChanged<int> onCellTap;

  const _GomokuBoardWidget({
    required this.board,
    required this.boardSize,
    required this.gridSize,
    required this.winLine,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFDCEAF8),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: boardSize,
          height: boardSize,
          child: LayoutBuilder(builder: (context, constraints) {
            final padding = boardSize * 0.04;
            final innerSize = boardSize - padding * 2;
            final cellSize = innerSize / (gridSize - 1);
            return Stack(
              children: [
                CustomPaint(
                  size: Size(boardSize, boardSize),
                  painter: _GomokuBoardPainter(
                    board: board,
                    gridSize: gridSize,
                    padding: padding,
                    cellSize: cellSize,
                    winLine: winLine,
                  ),
                ),
                for (int i = 0; i < gridSize * gridSize; i++)
                  Positioned(
                    left: padding + (i % gridSize) * cellSize - cellSize / 2,
                    top: padding + (i ~/ gridSize) * cellSize - cellSize / 2,
                    width: cellSize,
                    height: cellSize,
                    child: GestureDetector(
                      onTap: () => onCellTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _GomokuBoardPainter extends CustomPainter {
  final List<int> board;
  final int gridSize;
  final double padding;
  final double cellSize;
  final List<int> winLine;

  _GomokuBoardPainter({
    required this.board,
    required this.gridSize,
    required this.padding,
    required this.cellSize,
    required this.winLine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = _kLineColor.withValues(alpha: 0.20)
      ..strokeWidth = 0.8;

    for (int i = 0; i < gridSize; i++) {
      final offset = padding + i * cellSize;
      canvas.drawLine(Offset(padding, offset), Offset(padding + (gridSize - 1) * cellSize, offset), linePaint);
      canvas.drawLine(Offset(offset, padding), Offset(offset, padding + (gridSize - 1) * cellSize), linePaint);
    }

    final center = gridSize ~/ 2;
    for (final pos in [
      [3, 3], [3, center], [3, gridSize - 4],
      [center, 3], [center, center], [center, gridSize - 4],
      [gridSize - 4, 3], [gridSize - 4, center], [gridSize - 4, gridSize - 4],
    ]) {
      if (pos[0] < gridSize && pos[1] < gridSize) {
        canvas.drawCircle(
          Offset(padding + pos[1] * cellSize, padding + pos[0] * cellSize),
          cellSize * 0.07,
          Paint()..color = _kLineColor.withValues(alpha: 0.35),
        );
      }
    }

    final stoneR = cellSize * 0.40;
    for (int i = 0; i < board.length; i++) {
      if (board[i] == 0) continue;
      final r = i ~/ gridSize;
      final c = i % gridSize;
      final cx = padding + c * cellSize;
      final cy = padding + r * cellSize;
      final isBlack = board[i] == 1;

      canvas.drawCircle(Offset(cx, cy + 1), stoneR, Paint()..color = Colors.black.withValues(alpha: 0.12));
      canvas.drawCircle(Offset(cx, cy), stoneR, Paint()..color = isBlack ? _kBlackColor : Colors.white);
      if (!isBlack) {
        canvas.drawCircle(Offset(cx, cy), stoneR, Paint()..color = Colors.grey.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 0.8);
      }
      canvas.drawCircle(
        Offset(cx - stoneR * 0.25, cy - stoneR * 0.25),
        stoneR * 0.12,
        Paint()..color = Colors.white.withValues(alpha: isBlack ? 0.18 : 0.45),
      );
    }

    if (winLine.isNotEmpty) {
      final sorted = List<int>.from(winLine)..sort();
      final first = sorted.first;
      final last = sorted.last;
      final start = Offset(padding + (first % gridSize) * cellSize, padding + (first ~/ gridSize) * cellSize);
      final end = Offset(padding + (last % gridSize) * cellSize, padding + (last ~/ gridSize) * cellSize);

      canvas.drawLine(start, end, Paint()
        ..color = Colors.amber.withValues(alpha: 0.45)
        ..strokeWidth = cellSize * 0.14
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawLine(start, end, Paint()
        ..color = Colors.amber.withValues(alpha: 0.8)
        ..strokeWidth = cellSize * 0.06
        ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_GomokuBoardPainter old) => true;
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 4),
          Text(
            '$streak streak!',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: Colors.orange.shade800,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC4B5FD)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars_rounded, size: 14, color: Color(0xFF7C3AED)),
          SizedBox(width: 4),
          Text('New Best!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF7C3AED))),
        ],
      ),
    );
  }
}

class _WinBanner extends StatelessWidget {
  final String label;
  final Color color;
  const _WinBanner({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 2)],
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }
}

class _Confetti extends StatefulWidget {
  final Color color;
  const _Confetti({required this.color});
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_ConfettiParticle> _particles;
  static final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
    _particles = List.generate(36, (i) {
      return _ConfettiParticle(
        angle: (i / 36) * math.pi * 2 + _rng.nextDouble() * 0.5,
        speed: 0.55 + _rng.nextDouble() * 0.35,
        size: 3.0 + _rng.nextDouble() * 4.0,
        hueShift: _rng.nextDouble() * 60 - 30,
      );
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => CustomPaint(
        painter: _ConfettiPainter(progress: _ctrl.value, particles: _particles, baseColor: widget.color),
      ),
    );
  }
}

class _ConfettiParticle {
  final double angle, speed, size, hueShift;
  _ConfettiParticle({required this.angle, required this.speed, required this.size, required this.hueShift});
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiParticle> particles;
  final Color baseColor;
  _ConfettiPainter({required this.progress, required this.particles, required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide * 0.6;
    for (final p in particles) {
      final r = maxR * progress * p.speed;
      final dx = center.dx + math.cos(p.angle) * r;
      final dy = center.dy + math.sin(p.angle) * r - 30 * progress;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final hsl = HSLColor.fromColor(baseColor);
      final color = hsl.withHue((hsl.hue + p.hueShift) % 360).toColor().withValues(alpha: opacity);
      canvas.drawCircle(Offset(dx, dy), p.size * (1 - progress * 0.3), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}
