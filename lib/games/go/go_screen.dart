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
import 'go_stats.dart';
import 'go_tutorial.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/rewarded_undo_button.dart';

const Color _kBlackStone = Color(0xFF212121);
const Color _kWhiteStone = Color(0xFFF5F5F5);
const Color _kDrawColor = Color(0xFFB6A5DD);
const Color _kAiColor = Color(0xFFC4944E);
const Color _kBgTop = Color(0xFFFFF8E7);
const Color _kBgBot = Color(0xFFF5ECD8);
const Color _kBoardColor = Color(0xFFD4A76A);
const Color _kLineColor = Color(0xFF5D4037);
const Color _kEasyColor = Color(0xFF22C55E);
const Color _kMediumColor = Color(0xFFF59E0B);
const Color _kHardColor = Color(0xFFEF4444);

const Color _kTintBlackTop = Color(0xFFFFF6E0);
const Color _kTintBlackBot = Color(0xFFF2E5CC);
const Color _kTintWhiteTop = Color(0xFFF8F2EA);
const Color _kTintWhiteBot = Color(0xFFEDE5D8);
const Color _kTintNeutralTop = Color(0xFFFFF8E7);
const Color _kTintNeutralBot = Color(0xFFF5ECD8);

enum _Mode { ai, twoPlayer }
enum _Difficulty { easy, medium, hard }

class GoScreen extends StatefulWidget {
  const GoScreen({super.key});
  @override
  State<GoScreen> createState() => _GoScreenState();
}

class _GoScreenState extends State<GoScreen> with TickerProviderStateMixin {
  static const _gridSize = 9;
  static const _totalCells = _gridSize * _gridSize;

  _Mode? _mode;
  _Difficulty _difficulty = _Difficulty.values[DifficultyKind.defaultIndex];

  // Board: 0=empty, 1=black, 2=white
  List<int> _board = List.filled(_totalCells, 0);
  int _currentPlayer = 1; // 1=black, 2=white
  bool _gameOver = false;
  int? _winner;
  bool _aiThinking = false;
  int _blackCaptures = 0;
  int _whiteCaptures = 0;
  int _consecutivePasses = 0;
  List<int>? _prevBoard;
  int _blackWins = 0;
  int _whiteWins = 0;
  int _draws = 0;
  int _streak = 0;
  String? _streakOwner;
  bool _wasNewBest = false;
  bool _isFavorite = false;
  bool _showStreakBadge = false;
  bool _celebrating = false;
  String? _bannerLabel;
  Color _bannerColor = _kDrawColor;
  bool _showWinBanner = false;

  List<int>? _undoBoardSnapshot;
  int _undoBlackCaptures = 0;
  int _undoWhiteCaptures = 0;
  List<int>? _undoPrevBoard;
  bool _undoUsedThisRound = false;
  bool _inUndoWindow = false;

  final _rng = math.Random();
  final _audio = AudioService();
  Timer? _aiMoveTimer;
  Timer? _endGameTimer;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kGoGameId);
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
      _currentPlayer = 1;
      _gameOver = false;
      _winner = null;
      _aiThinking = false;
      _blackCaptures = 0;
      _whiteCaptures = 0;
      _consecutivePasses = 0;
      _prevBoard = null;
      _wasNewBest = false;
      _showStreakBadge = false;
      _celebrating = false;
      _showWinBanner = false;
      _bannerLabel = null;
      _undoBoardSnapshot = null;
      _undoUsedThisRound = false;
      _inUndoWindow = false;
    });
    if (_mode == _Mode.ai && _currentPlayer == 2) {
      _scheduleAiMove();
    }
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
      ScoreService().toggleFavorite(kGoGameId);
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
    final game = GameRegistry.getById(kGoGameId);
    if (game == null) return;
    showHowToPlaySheet(context, title: game.name, howToPlay: game.howToPlay,
      accent: _kAiColor, steps: goSteps(), gameId: kGoGameId);
  }

  // ── Undo ──

  bool get _canUndo => _inUndoWindow && !_gameOver;

  void _onUndoExpired() {
    if (!mounted || _gameOver || !_inUndoWindow) return;
    setState(() => _inUndoWindow = false);
    _scheduleAiMove();
  }

  void _performUndo() {
    final snap = _undoBoardSnapshot;
    if (snap == null) return;
    setState(() {
      _board = List<int>.from(snap);
      _blackCaptures = _undoBlackCaptures;
      _whiteCaptures = _undoWhiteCaptures;
      _prevBoard = _undoPrevBoard != null ? List<int>.from(_undoPrevBoard!) : null;
      _currentPlayer = 1;
      _consecutivePasses = 0;
      _inUndoWindow = false;
      _undoBoardSnapshot = null;
      _undoUsedThisRound = true;
    });
  }

  // ── Go Logic ──

  List<int> _getGroup(List<int> board, int pos) {
    final color = board[pos];
    if (color == 0) return [];
    final group = <int>{pos};
    final queue = [pos];
    while (queue.isNotEmpty) {
      final p = queue.removeLast();
      for (final n in _neighbors(p)) {
        if (!group.contains(n) && board[n] == color) {
          group.add(n);
          queue.add(n);
        }
      }
    }
    return group.toList();
  }

  int _liberties(List<int> board, List<int> group) {
    final libs = <int>{};
    for (final p in group) {
      for (final n in _neighbors(p)) {
        if (board[n] == 0) libs.add(n);
      }
    }
    return libs.length;
  }

  List<int> _neighbors(int pos) {
    final r = pos ~/ _gridSize;
    final c = pos % _gridSize;
    final result = <int>[];
    if (r > 0) result.add((r - 1) * _gridSize + c);
    if (r < _gridSize - 1) result.add((r + 1) * _gridSize + c);
    if (c > 0) result.add(r * _gridSize + (c - 1));
    if (c < _gridSize - 1) result.add(r * _gridSize + (c + 1));
    return result;
  }

  bool _isValidMove(int pos, int player) {
    if (_board[pos] != 0) return false;
    final testBoard = List<int>.from(_board);
    testBoard[pos] = player;
    final opponent = player == 1 ? 2 : 1;

    int captured = 0;
    for (final n in _neighbors(pos)) {
      if (testBoard[n] == opponent) {
        final group = _getGroup(testBoard, n);
        if (_liberties(testBoard, group) == 0) {
          for (final g in group) {
            testBoard[g] = 0;
          }
          captured += group.length;
        }
      }
    }

    final ownGroup = _getGroup(testBoard, pos);
    if (_liberties(testBoard, ownGroup) == 0) return false;

    if (_prevBoard != null && _listsEqual(testBoard, _prevBoard!)) return false;

    return true;
  }

  bool _listsEqual(List<int> a, List<int> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _placeStone(int pos) {
    if (_gameOver || _aiThinking) return;
    if (_mode == _Mode.ai && (_inUndoWindow || _currentPlayer == 2)) return;
    if (!_isValidMove(pos, _currentPlayer)) return;

    if (_mode == _Mode.ai && _currentPlayer == 1) {
      _undoBoardSnapshot = List<int>.from(_board);
      _undoBlackCaptures = _blackCaptures;
      _undoWhiteCaptures = _whiteCaptures;
      _undoPrevBoard = _prevBoard != null ? List<int>.from(_prevBoard!) : null;
    }
    _applyMove(pos);
  }

  void _applyMove(int pos) {
    _prevBoard = List<int>.from(_board);
    final opponent = _currentPlayer == 1 ? 2 : 1;

    setState(() {
      _board[pos] = _currentPlayer;
      _consecutivePasses = 0;
    });
    _audio.playTap();

    int captured = 0;
    for (final n in _neighbors(pos)) {
      if (_board[n] == opponent) {
        final group = _getGroup(_board, n);
        if (_liberties(_board, group) == 0) {
          for (final g in group) {
            _board[g] = 0;
          }
          captured += group.length;
        }
      }
    }

    setState(() {
      if (_currentPlayer == 1) {
        _blackCaptures += captured;
      } else {
        _whiteCaptures += captured;
      }
    });

    if (captured > 0) _audio.playScore();
    _switchTurn();
  }

  void _pass() {
    if (_gameOver || _aiThinking) return;
    if (_mode == _Mode.ai && (_inUndoWindow || _currentPlayer == 2)) return;
    _audio.playTap();
    setState(() => _consecutivePasses++);
    if (_consecutivePasses >= 2) {
      _endByScoring();
      return;
    }
    _switchTurn();
  }

  void _switchTurn() {
    final wasHuman = _mode == _Mode.ai && _currentPlayer == 1;
    final undoAvailable = wasHuman && !_undoUsedThisRound && AdsService().isRewardedReady;
    setState(() => _currentPlayer = _currentPlayer == 1 ? 2 : 1);
    if (_mode == _Mode.ai && _currentPlayer == 2 && !_gameOver) {
      if (undoAvailable) {
        setState(() => _inUndoWindow = true);
      } else {
        _scheduleAiMove();
      }
    }
  }

  void _endByScoring() {
    int blackTerritory = 0;
    int whiteTerritory = 0;
    final visited = <int>{};

    for (int i = 0; i < _totalCells; i++) {
      if (_board[i] != 0 || visited.contains(i)) continue;
      final region = <int>{i};
      final queue = [i];
      bool touchesBlack = false;
      bool touchesWhite = false;
      while (queue.isNotEmpty) {
        final p = queue.removeLast();
        for (final n in _neighbors(p)) {
          if (_board[n] == 1) {
            touchesBlack = true;
          } else if (_board[n] == 2) {
            touchesWhite = true;
          } else if (!region.contains(n)) {
            region.add(n);
            queue.add(n);
          }
        }
      }
      visited.addAll(region);
      if (touchesBlack && !touchesWhite) blackTerritory += region.length;
      if (touchesWhite && !touchesBlack) whiteTerritory += region.length;
    }

    final blackScore = blackTerritory + _blackCaptures;
    final whiteScore = whiteTerritory + _whiteCaptures + 6; // 6.5 komi rounded

    if (blackScore > whiteScore) {
      _onWin(1);
    } else if (whiteScore > blackScore) {
      _onWin(2);
    } else {
      _onDraw();
    }
  }

  void _onWin(int winner) {
    final isAi = _mode == _Mode.ai;
    final label = winner == 1 ? 'black' : 'white';
    setState(() {
      _gameOver = true;
      _winner = winner;
      _showWinBanner = true;
      _celebrating = true;
      if (winner == 1) {
        _blackWins++;
        _bannerLabel = isAi ? 'You Win!' : 'Player 1 Wins!';
        _bannerColor = _kBlackStone;
      } else {
        _whiteWins++;
        _bannerLabel = isAi ? 'AI Wins!' : 'Player 2 Wins!';
        _bannerColor = const Color(0xFF757575);
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
      final subKey = _aiSubKey();
      if (subKey != null) {
        ScoreService().saveScore(kGoGameId, _streak, subKey: subKey).then((isNew) {
          if (mounted && isNew) setState(() => _wasNewBest = true);
        });
      }
      _wrapper.updateScore(_streak);
    } else {
      _wasNewBest = false;
    }

    final gameResult = isAi ? (winner == 1 ? 'win' : 'loss') : 'win';
    _audio.playSuccess();
    _endGameTimer?.cancel();
    _endGameTimer = Timer(const Duration(milliseconds: 1200), () {
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

  String? _aiSubKey() {
    if (_mode != _Mode.ai) return null;
    return switch (_difficulty) {
      _Difficulty.easy => kGoSubKeyEasy,
      _Difficulty.medium => kGoSubKeyMedium,
      _Difficulty.hard => kGoSubKeyHard,
    };
  }

  // ── AI ──

  void _scheduleAiMove() {
    setState(() => _aiThinking = true);
    final thinkMs = switch (_difficulty) {
      _Difficulty.easy => 500,
      _Difficulty.medium => 800,
      _Difficulty.hard => 1100,
    };
    _aiMoveTimer?.cancel();
    _aiMoveTimer = Timer(Duration(milliseconds: thinkMs), () {
      if (!mounted || _gameOver) return;
      _performAiMove();
    });
  }

  void _performAiMove() {
    final validMoves = <int>[];
    for (int i = 0; i < _totalCells; i++) {
      if (_isValidMove(i, 2)) validMoves.add(i);
    }

    if (validMoves.isEmpty) {
      setState(() {
        _aiThinking = false;
        _consecutivePasses++;
      });
      if (_consecutivePasses >= 2) {
        _endByScoring();
      } else {
        _switchTurn();
      }
      return;
    }

    int chosen;
    switch (_difficulty) {
      case _Difficulty.easy:
        chosen = validMoves[_rng.nextInt(validMoves.length)];
      case _Difficulty.medium:
        chosen = _pickSmartGoMove(validMoves, 0.4);
      case _Difficulty.hard:
        chosen = _pickSmartGoMove(validMoves, 0.15);
    }

    setState(() {
      _aiThinking = false;
      _undoBoardSnapshot = null;
    });
    _applyMove(chosen);
  }

  int _pickSmartGoMove(List<int> moves, double randomFactor) {
    if (_rng.nextDouble() < randomFactor) {
      return moves[_rng.nextInt(moves.length)];
    }

    int bestScore = -9999;
    int bestMove = moves.first;

    for (final pos in moves) {
      int score = 0;
      final r = pos ~/ _gridSize;
      final c = pos % _gridSize;

      final testBoard = List<int>.from(_board);
      testBoard[pos] = 2;
      for (final n in _neighbors(pos)) {
        if (testBoard[n] == 1) {
          final group = _getGroup(testBoard, n);
          if (_liberties(testBoard, group) == 0) score += group.length * 5;
          else if (_liberties(testBoard, group) == 1) score += 3;
        }
      }

      if (r >= 2 && r <= _gridSize - 3 && c >= 2 && c <= _gridSize - 3) score += 2;
      int adjFriendly = 0;
      for (final n in _neighbors(pos)) {
        if (_board[n] == 2) adjFriendly++;
      }
      score += adjFriendly;
      score += _rng.nextInt(2);

      if (score > bestScore) {
        bestScore = score;
        bestMove = pos;
      }
    }
    return bestMove;
  }

  // ── Helpers ──

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
        factory: (t) => GenericAnimatedBgPainter(t, accent: _kAiColor, icon: Icons.circle_outlined),
        period: const Duration(seconds: 9),
      ),
      iconRingColors: const [Color(0xFFC4944E), Color(0xFF212121), Color(0xFFC4944E)],
      iconChild: Builder(builder: (ctx) {
        final info = GameRegistry.getById(kGoGameId);
        final logo = info?.buildBrandedLogo(size: 84);
        if (logo != null) {
          return ClipRRect(borderRadius: BorderRadius.circular(42), child: logo);
        }
        return const Icon(Icons.circle_outlined, size: 40, color: _kAiColor);
      }),
      title: 'Go',
      subtitle: 'Ancient strategy on a 9×9 board.',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kGoGameId,
      body: GameAiPickerBody(
        difficulties: _Difficulty.values.map((d) {
          final subKey = switch (d) {
            _Difficulty.easy => kGoSubKeyEasy,
            _Difficulty.medium => kGoSubKeyMedium,
            _Difficulty.hard => kGoSubKeyHard,
          };
          return GameDifficultyData(
            label: _diffLabel(d),
            color: _diffColor(d),
            kind: _kindFor(d),
            hint: switch (d) {
              _Difficulty.easy => 'Random moves — learn the basics.',
              _Difficulty.medium => 'Captures aggressively.',
              _Difficulty.hard => 'Territorial and strategic.',
            },
            bestScore: bestGoStreak(subKey),
            bestLabel: (s) => 'Best $s in a row',
          );
        }).toList(),
        activeIndex: _Difficulty.values.indexOf(_difficulty),
        onChanged: (i) => setState(() => _difficulty = _Difficulty.values[i]),
        onPlayAi: () => _selectMode(_Mode.ai),
        onPlayFriend: () => _selectMode(_Mode.twoPlayer),
        aiGradient: const [Color(0xFFC4944E), Color(0xFFD4A76A)],
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
                blackCaptures: _blackCaptures,
                whiteCaptures: _whiteCaptures,
              ),
              trailing: GameRestartButton(
                gameName: 'Go',
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
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: PlayerStrip(
                      label: isAi ? 'AI' : 'Player 2',
                      mark: '○',
                      color: const Color(0xFF757575),
                      isActive: _currentPlayer == 2 && !_inUndoWindow && !_gameOver,
                      isThinking: _aiThinking,
                      avatarIcon: isAi ? Icons.smart_toy_rounded : null,
                    ),
                  ),
                  if (!isAi) ...[
                    const SizedBox(width: 8),
                    _PassButton(
                      onTap: _pass,
                      enabled: !_gameOver && _currentPlayer == 2,
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(builder: (context, constraints) {
                      return Stack(
                        children: [
                          _GoBoardWidget(
                            board: _board,
                            boardSize: constraints.maxWidth,
                            gridSize: _gridSize,
                            onCellTap: _placeStone,
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
              child: Row(
                children: [
                  Expanded(
                    child: PlayerStrip(
                      label: isAi ? 'You' : 'Player 1',
                      mark: '●',
                      color: _kBlackStone,
                      isActive: (_currentPlayer == 1 || _inUndoWindow) && !_gameOver,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PassButton(
                    onTap: _pass,
                    enabled: !_gameOver && !_aiThinking && _currentPlayer == 1,
                  ),
                ],
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
                        accentColor: _kBlackStone,
                      ),
                    )
                  : const SizedBox.shrink(),
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

  Widget _buildResult() {
    final isAi = _mode == _Mode.ai;
    String headline;
    String big;
    Color bigColor;
    if (_winner == 1) {
      headline = isAi ? 'You Win!' : 'Player 1 Wins!';
      big = '●';
      bigColor = _kBlackStone;
    } else if (_winner == 2) {
      headline = isAi ? 'AI Wins!' : 'Player 2 Wins!';
      big = '○';
      bigColor = const Color(0xFF757575);
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
      gameId: kGoGameId,
      score: _streak,
      headline: headline,
      badgeContent: big,
      badgeColor: bigColor,
      showNewBestBadge: false,
      extraBadges: extraBadges,
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(label: isAi ? 'YOU' : 'P1', value: _blackWins, color: _kBlackStone),
          game_result.StatItem(label: 'DRAWS', value: _draws, color: const Color(0xFF8B7BA7)),
          game_result.StatItem(label: isAi ? 'AI' : 'P2', value: _whiteWins, color: const Color(0xFF757575)),
          if (isAi)
            game_result.StatItem(
              label: 'BEST',
              value: ScoreService().getHighScore(kGoGameId, subKey: _aiSubKey()),
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
  final int blackCaptures;
  final int whiteCaptures;

  const _ScoreBoardPill({
    required this.mode,
    required this.difficulty,
    required this.blackCaptures,
    required this.whiteCaptures,
  });

  @override
  Widget build(BuildContext context) {
    final isAi = mode == _Mode.ai;
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
            boxShadow: [
              BoxShadow(color: tabColor.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 3)),
            ],
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                children: [
                  Container(width: 12, height: 12, decoration: const BoxDecoration(color: _kBlackStone, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('$blackCaptures', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('captures', style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E), fontWeight: FontWeight.w500)),
                  ),
                  Text('$whiteCaptures', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(width: 4),
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: _kWhiteStone, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Colors.grey.shade400, width: 1)))),
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
      _Difficulty.easy => kGoSubKeyEasy,
      _Difficulty.medium => kGoSubKeyMedium,
      _Difficulty.hard => kGoSubKeyHard,
    };
    final best = ScoreService().getHighScore(kGoGameId, subKey: subKey);
    if (best <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text('best $best',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ── Pass Button ──

class _PassButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool enabled;
  const _PassButton({required this.onTap, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: const Text('PASS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1, color: Color(0xFF5D4037))),
        ),
      ),
    );
  }
}

// ── Board Widget ──

class _GoBoardWidget extends StatelessWidget {
  final List<int> board;
  final double boardSize;
  final int gridSize;
  final ValueChanged<int> onCellTap;

  const _GoBoardWidget({
    required this.board,
    required this.boardSize,
    required this.gridSize,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kBoardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: boardSize,
          height: boardSize,
          child: LayoutBuilder(builder: (context, constraints) {
            final padding = boardSize * 0.06;
            final innerSize = boardSize - padding * 2;
            final cellSize = innerSize / (gridSize - 1);
            return Stack(
              children: [
                CustomPaint(
                  size: Size(boardSize, boardSize),
                  painter: _GoBoardPainter(board: board, gridSize: gridSize, padding: padding, cellSize: cellSize),
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

class _GoBoardPainter extends CustomPainter {
  final List<int> board;
  final int gridSize;
  final double padding;
  final double cellSize;

  _GoBoardPainter({required this.board, required this.gridSize, required this.padding, required this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = _kLineColor.withValues(alpha: 0.45)
      ..strokeWidth = 1.0;

    for (int i = 0; i < gridSize; i++) {
      final offset = padding + i * cellSize;
      canvas.drawLine(Offset(padding, offset), Offset(padding + (gridSize - 1) * cellSize, offset), linePaint);
      canvas.drawLine(Offset(offset, padding), Offset(offset, padding + (gridSize - 1) * cellSize), linePaint);
    }

    final starPoints = [2, 4, 6];
    for (final r in starPoints) {
      for (final c in starPoints) {
        if (r < gridSize && c < gridSize) {
          canvas.drawCircle(
            Offset(padding + c * cellSize, padding + r * cellSize),
            cellSize * 0.08,
            Paint()..color = _kLineColor.withValues(alpha: 0.5),
          );
        }
      }
    }

    for (int i = 0; i < board.length; i++) {
      if (board[i] == 0) continue;
      final r = i ~/ gridSize;
      final c = i % gridSize;
      final cx = padding + c * cellSize;
      final cy = padding + r * cellSize;
      final radius = cellSize * 0.42;
      final isBlack = board[i] == 1;

      canvas.drawCircle(Offset(cx, cy + 1), radius, Paint()..color = Colors.black.withValues(alpha: 0.15));
      canvas.drawCircle(Offset(cx, cy), radius, Paint()..color = isBlack ? _kBlackStone : _kWhiteStone);
      if (!isBlack) {
        canvas.drawCircle(Offset(cx, cy), radius, Paint()..color = Colors.grey.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 0.8);
      }
      canvas.drawCircle(
        Offset(cx - radius * 0.25, cy - radius * 0.25),
        radius * 0.15,
        Paint()..color = Colors.white.withValues(alpha: isBlack ? 0.2 : 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(_GoBoardPainter old) => true;
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
          Text('$streak streak!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.orange.shade800)),
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
