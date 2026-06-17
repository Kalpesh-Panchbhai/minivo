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
import '../shared/rewarded_undo_button.dart';
import 'reversi_stats.dart';
import 'reversi_tutorial.dart';
import '../shared/generic_game_result_screen.dart' as game_result;

const int _kN = 8;

const Color _kBlackDisc = Color(0xFF1A1A1A);
const Color _kP1Strip = Color(0xFF5B4FC7);
const Color _kP2Strip = Color(0xFFE5890A);
const Color _kBoardGreen = Color(0xFF2E7D32);
const Color _kDrawColor = Color(0xFFB6A5DD);
const Color _kAccent = Color(0xFF2E7D32);

const Color _kBgTop = Color(0xFFF0F8F0);
const Color _kBgBot = Color(0xFFE8F5E9);

const Color _kEasyColor = Color(0xFF22C55E);
const Color _kMediumColor = Color(0xFFF59E0B);
const Color _kHardColor = Color(0xFFEF4444);

enum _Mode { ai, twoPlayer }

enum _Difficulty { easy, medium, hard }

const _dirs = [
  [-1, -1], [-1, 0], [-1, 1],
  [0, -1],           [0, 1],
  [1, -1],  [1, 0],  [1, 1],
];

class ReversiScreen extends StatefulWidget {
  const ReversiScreen({super.key});

  @override
  State<ReversiScreen> createState() => _ReversiScreenState();
}

class _ReversiScreenState extends State<ReversiScreen>
    with TickerProviderStateMixin {
  _Mode? _mode;
  _Difficulty _difficulty = _Difficulty.values[DifficultyKind.defaultIndex];

  late List<List<int>> _grid; // 0=empty, 1=black, 2=white
  int _currentPlayer = 1; // black goes first
  bool _gameOver = false;
  bool _aiThinking = false;
  List<List<int>> _validMoves = [];
  bool _celebrating = false;

  int _p1Wins = 0;
  int _p2Wins = 0;
  int _draws = 0;

  int _streak = 0;
  int? _streakOwner;
  bool _showStreakBadge = false;
  bool _wasNewBest = false;

  Map<String, int> _flippingFrom = {};
  late final AnimationController _flipCtrl;
  int? _lastPlacedR;
  int? _lastPlacedC;
  late final AnimationController _placeCtrl;
  bool _waitingForFlip = false;
  int _pendingOpponent = 0;
  List<List<int>> _pendingOppMoves = [];
  bool _pendingEnd = false;

  List<List<int>>? _undoGridSnapshot;
  List<List<int>> _undoPrevValidMoves = [];
  int _undosUsed = 0;
  static const _kMaxUndos = 2;
  bool _inUndoWindow = false;

  bool _isFavorite = false;
  int _starter = 1;
  bool _firstRoundOfSession = true;
  static const _gameId = kReversiGameId;

  final _audio = AudioService();
  final _rng = math.Random();
  Timer? _aiTimer;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(_gameId);
    _grid = _initialGrid();
    _validMoves = _getValidMoves(1);
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _onFlipDone();
      });
    _placeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    _flipCtrl.dispose();
    _placeCtrl.dispose();
    super.dispose();
  }

  GameWrapperState get _wrapper => GameWrapper.of(context);

  static List<List<int>> _initialGrid() {
    final g = List.generate(_kN, (_) => List.filled(_kN, 0));
    final m = _kN ~/ 2;
    g[m - 1][m - 1] = 2;
    g[m][m] = 2;
    g[m - 1][m] = 1;
    g[m][m - 1] = 1;
    return g;
  }

  // ════════════════════════════════════════════════════════════════
  // SESSION / FLOW
  // ════════════════════════════════════════════════════════════════

  void _selectMode(_Mode mode) {
    setState(() {
      _mode = mode;
      _p1Wins = 0;
      _p2Wins = 0;
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
      _p1Wins = 0;
      _p2Wins = 0;
      _draws = 0;
      _streak = 0;
      _streakOwner = null;
      _showStreakBadge = false;
      _firstRoundOfSession = true;
    });
    _resetBoard(notify: false);
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

  void _resetBoard({bool notify = true}) {
    void apply() {
      if (_firstRoundOfSession) {
        _starter = _rng.nextBool() ? 1 : 2;
        _firstRoundOfSession = false;
      } else {
        _starter = _starter == 1 ? 2 : 1;
      }
      _grid = _initialGrid();
      _currentPlayer = _starter;
      _gameOver = false;
      _aiThinking = false;
      _wasNewBest = false;
      _showStreakBadge = false;
      _celebrating = false;
      _validMoves = _getValidMoves(_currentPlayer);
      _flippingFrom = {};
      _lastPlacedR = null;
      _lastPlacedC = null;
      _waitingForFlip = false;
      _pendingEnd = false;
      _undoGridSnapshot = null;
      _undoPrevValidMoves = [];
      _undosUsed = 0;
      _inUndoWindow = false;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
    if (_mode == _Mode.ai && _currentPlayer == 2) {
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
    _wrapper.handleExit(() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    });
  }

  void _showHelp() {
    final game = GameRegistry.getById(_gameId);
    if (game == null) return;
    showHowToPlaySheet(
      context,
      title: game.name,
      howToPlay: game.howToPlay,
      accent: _kAccent,
      steps: reversiSteps(),
      gameId: _gameId,
    );
  }

  String _diffLabel(_Difficulty d) => ['EASY', 'MEDIUM', 'HARD'][d.index];

  // ════════════════════════════════════════════════════════════════
  // UNDO (AI mode only, 1 per round)
  // ════════════════════════════════════════════════════════════════

  bool get _canUndo => _inUndoWindow && !_gameOver;

  void _onUndoExpired() {
    if (!mounted || _gameOver || !_inUndoWindow) return;
    setState(() {
      _inUndoWindow = false;
      _currentPlayer = _pendingOpponent;
      _validMoves = _pendingOppMoves;
    });
    _scheduleAiMove();
  }

  void _performUndo() {
    final snap = _undoGridSnapshot;
    if (snap == null) return;
    setState(() {
      _grid = snap;
      _currentPlayer = 1;
      _validMoves = _undoPrevValidMoves;
      _inUndoWindow = false;
      _undoGridSnapshot = null;
      _undosUsed++;
      _lastPlacedR = null;
      _lastPlacedC = null;
    });
  }

  // ════════════════════════════════════════════════════════════════
  // GAME LOGIC
  // ════════════════════════════════════════════════════════════════

  List<List<int>> _getValidMoves(int player) {
    final moves = <List<int>>[];
    for (int r = 0; r < _kN; r++) {
      for (int c = 0; c < _kN; c++) {
        if (_grid[r][c] == 0 && _wouldFlip(r, c, player).isNotEmpty) {
          moves.add([r, c]);
        }
      }
    }
    return moves;
  }

  List<List<int>> _wouldFlip(int r, int c, int player) {
    final opponent = player == 1 ? 2 : 1;
    final flips = <List<int>>[];
    for (final d in _dirs) {
      final line = <List<int>>[];
      int nr = r + d[0];
      int nc = c + d[1];
      while (nr >= 0 && nr < _kN && nc >= 0 && nc < _kN && _grid[nr][nc] == opponent) {
        line.add([nr, nc]);
        nr += d[0];
        nc += d[1];
      }
      if (line.isNotEmpty && nr >= 0 && nr < _kN && nc >= 0 && nc < _kN && _grid[nr][nc] == player) {
        flips.addAll(line);
      }
    }
    return flips;
  }

  void _onCellTap(int r, int c) {
    if (_gameOver || _waitingForFlip || _inUndoWindow) return;
    if (_mode == _Mode.ai && (_aiThinking || _currentPlayer != 1)) return;
    if (!_validMoves.any((m) => m[0] == r && m[1] == c)) return;
    _makeMove(r, c);
  }

  void _makeMove(int r, int c) {
    final flips = _wouldFlip(r, c, _currentPlayer);

    if (_mode == _Mode.ai && _currentPlayer == 1) {
      _undoGridSnapshot = _grid.map((row) => List<int>.from(row)).toList();
      _undoPrevValidMoves = List<List<int>>.from(_validMoves);
    }

    _flippingFrom = {};
    for (final f in flips) {
      _flippingFrom['${f[0]},${f[1]}'] = _grid[f[0]][f[1]];
    }

    setState(() {
      _grid[r][c] = _currentPlayer;
      for (final f in flips) {
        _grid[f[0]][f[1]] = _currentPlayer;
      }
      _lastPlacedR = r;
      _lastPlacedC = c;
    });
    _audio.playTap();
    _placeCtrl.forward(from: 0);

    final opponent = _currentPlayer == 1 ? 2 : 1;
    final oppMoves = _getValidMoves(opponent);

    if (flips.isNotEmpty) {
      _waitingForFlip = true;
      if (oppMoves.isNotEmpty) {
        _pendingOpponent = opponent;
        _pendingOppMoves = oppMoves;
        _pendingEnd = false;
      } else {
        final myMoves = _getValidMoves(_currentPlayer);
        if (myMoves.isNotEmpty) {
          _pendingOpponent = _currentPlayer;
          _pendingOppMoves = myMoves;
          _pendingEnd = false;
        } else {
          _pendingEnd = true;
        }
      }
      _flipCtrl.forward(from: 0);
    } else {
      if (oppMoves.isNotEmpty) {
        final undoAvail = _mode == _Mode.ai && _currentPlayer == 1 &&
            _undosUsed < _kMaxUndos && AdsService().isRewardedReady;
        if (undoAvail) {
          _pendingOpponent = opponent;
          _pendingOppMoves = oppMoves;
          _updateScore();
          setState(() => _inUndoWindow = true);
        } else {
          setState(() {
            _currentPlayer = opponent;
            _validMoves = oppMoves;
          });
          _updateScore();
          if (_mode == _Mode.ai && _currentPlayer == 2 && !_gameOver) {
            _scheduleAiMove();
          }
        }
      } else {
        final myMoves = _getValidMoves(_currentPlayer);
        if (myMoves.isNotEmpty) {
          setState(() => _validMoves = myMoves);
        } else {
          _endRound();
          return;
        }
        _updateScore();
      }
    }
  }

  void _onFlipDone() {
    if (!mounted) return;
    setState(() {
      _flippingFrom = {};
      _waitingForFlip = false;
    });
    if (_pendingEnd) {
      _endRound();
      return;
    }
    final undoAvail = _mode == _Mode.ai && _pendingOpponent == 2 &&
        _undosUsed < _kMaxUndos && AdsService().isRewardedReady;
    if (undoAvail) {
      _updateScore();
      setState(() => _inUndoWindow = true);
    } else {
      setState(() {
        _currentPlayer = _pendingOpponent;
        _validMoves = _pendingOppMoves;
      });
      _updateScore();
      if (_mode == _Mode.ai && _currentPlayer == 2 && !_gameOver) {
        _scheduleAiMove();
      }
    }
  }

  void _updateScore() {
    int black = 0, white = 0;
    for (int r = 0; r < _kN; r++) {
      for (int c = 0; c < _kN; c++) {
        if (_grid[r][c] == 1) black++;
        if (_grid[r][c] == 2) white++;
      }
    }
    _wrapper.updateScore(_mode == _Mode.ai ? black : math.max(black, white));
  }

  void _endRound() {
    int black = 0, white = 0;
    for (int r = 0; r < _kN; r++) {
      for (int c = 0; c < _kN; c++) {
        if (_grid[r][c] == 1) black++;
        if (_grid[r][c] == 2) white++;
      }
    }

    final isAi = _mode == _Mode.ai;
    int? winner;
    if (black > white) {
      winner = 1;
      _p1Wins++;
    } else if (white > black) {
      winner = 2;
      _p2Wins++;
    } else {
      _draws++;
    }

    if (winner != null) {
      if (_streakOwner == winner) {
        _streak++;
      } else {
        _streakOwner = winner;
        _streak = 1;
      }
      _showStreakBadge = _streak >= 2;

      if (isAi && winner == 1) {
        final subKey = _aiSubKey();
        if (subKey != null) {
          ScoreService()
              .saveScore(_gameId, _streak, subKey: subKey)
              .then((isNew) {
            if (mounted && isNew) setState(() => _wasNewBest = true);
          });
        }
      }
      _audio.playSuccess();
    } else {
      _streak = 0;
      _streakOwner = null;
      _showStreakBadge = false;
      _wasNewBest = false;
    }

    if (isAi && winner == 1) _wrapper.updateScore(_streak);

    setState(() {
      _gameOver = true;
      _validMoves = [];
      if (winner != null) _celebrating = true;
    });

    final gameResult = winner == null
        ? 'draw'
        : isAi ? (winner == 1 ? 'win' : 'loss') : 'win';
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _wrapper.endGame(result: gameResult);
    });
  }

  String? _aiSubKey() {
    if (_mode != _Mode.ai) return null;
    return switch (_difficulty) {
      _Difficulty.easy => kRvSubKeyEasy,
      _Difficulty.medium => kRvSubKeyMedium,
      _Difficulty.hard => kRvSubKeyHard,
    };
  }

  // ════════════════════════════════════════════════════════════════
  // AI
  // ════════════════════════════════════════════════════════════════

  void _scheduleAiMove() {
    setState(() => _aiThinking = true);
    final ms = switch (_difficulty) {
      _Difficulty.easy => 500,
      _Difficulty.medium => 700,
      _Difficulty.hard => 900,
    };
    _aiTimer?.cancel();
    _aiTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted || _gameOver) return;
      final move = _pickAiMove();
      setState(() => _aiThinking = false);
      _makeMove(move[0], move[1]);
    });
  }

  List<int> _pickAiMove() {
    switch (_difficulty) {
      case _Difficulty.easy:
        return _validMoves[_rng.nextInt(_validMoves.length)];
      case _Difficulty.medium:
        return _greedyMove();
      case _Difficulty.hard:
        return _strategicMove();
    }
  }

  List<int> _greedyMove() {
    int bestFlips = -1;
    List<int> best = _validMoves.first;
    for (final m in _validMoves) {
      final flips = _wouldFlip(m[0], m[1], 2).length;
      if (flips > bestFlips) {
        bestFlips = flips;
        best = m;
      }
    }
    return best;
  }

  static const _cornerPositions = [[0, 0], [0, 7], [7, 0], [7, 7]];
  static const _edgePositions = [
    [0, 2], [0, 3], [0, 4], [0, 5],
    [7, 2], [7, 3], [7, 4], [7, 5],
    [2, 0], [3, 0], [4, 0], [5, 0],
    [2, 7], [3, 7], [4, 7], [5, 7],
  ];
  static const _badPositions = [
    [0, 1], [1, 0], [1, 1],
    [0, 6], [1, 7], [1, 6],
    [6, 0], [7, 1], [6, 1],
    [6, 7], [7, 6], [6, 6],
  ];

  List<int> _strategicMove() {
    for (final m in _validMoves) {
      if (_cornerPositions.any((c) => c[0] == m[0] && c[1] == m[1])) return m;
    }

    final safe = _validMoves.where((m) =>
        !_badPositions.any((b) => b[0] == m[0] && b[1] == m[1])).toList();
    final pool = safe.isNotEmpty ? safe : _validMoves;

    for (final m in pool) {
      if (_edgePositions.any((e) => e[0] == m[0] && e[1] == m[1])) return m;
    }

    int bestScore = -1000;
    List<int> best = pool.first;
    for (final m in pool) {
      final flips = _wouldFlip(m[0], m[1], 2).length;
      int positional = 0;
      if (m[0] == 0 || m[0] == _kN - 1) positional += 2;
      if (m[1] == 0 || m[1] == _kN - 1) positional += 2;
      final score = flips * 2 + positional;
      if (score > bestScore) {
        bestScore = score;
        best = m;
      }
    }
    return best;
  }

  // ════════════════════════════════════════════════════════════════
  // COUNTS
  // ════════════════════════════════════════════════════════════════

  (int, int) get _discCounts {
    int b = 0, w = 0;
    for (int r = 0; r < _kN; r++) {
      for (int c = 0; c < _kN; c++) {
        if (_grid[r][c] == 1) b++;
        if (_grid[r][c] == 2) w++;
      }
    }
    return (b, w);
  }

  // ════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final state = _wrapper.state;

    if (state == GameState.ready || _mode == null) {
      return _buildPicker();
    }
    if (state == GameState.gameOver) {
      return _buildResultScreen();
    }
    return _buildGame();
  }

  Widget _buildPicker() {
    return GamePickerScaffold(
      bgColorTop: _kBgTop,
      bgColorBottom: _kBgBot,
      animatedBg: AnimatedBackground(
        factory: (t) => _ReversiBgPainter(t),
        period: const Duration(seconds: 9),
      ),
      iconRingColors: const [_kBoardGreen, _kBlackDisc, Color(0xFF4CAF50)],
      iconChild: Builder(builder: (ctx) {
        final info = GameRegistry.getById(_gameId);
        final logo = info?.buildBrandedLogo(size: 84);
        if (logo != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(42),
            child: logo,
          );
        }
        return const Icon(Icons.circle, size: 40, color: _kAccent);
      }),
      title: 'Reversi',
      subtitle: 'Flip discs, dominate the board!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: _gameId,
      tallThreshold: 860,
      body: GameAiPickerBody(
        difficulties: _Difficulty.values.map((d) {
          final subKey = switch (d) {
            _Difficulty.easy => kRvSubKeyEasy,
            _Difficulty.medium => kRvSubKeyMedium,
            _Difficulty.hard => kRvSubKeyHard,
          };
          return GameDifficultyData(
            label: _diffLabel(d),
            color: [_kEasyColor, _kMediumColor, _kHardColor][d.index],
            kind: [DifficultyKind.easy, DifficultyKind.medium, DifficultyKind.hard][d.index],
            hint: switch (d) {
              _Difficulty.easy => 'Random moves — learn the rules.',
              _Difficulty.medium => 'Greedy — flips as many as possible.',
              _Difficulty.hard => 'Strategic — controls corners and edges.',
            },
            bestScore: bestReversiStreak(subKey),
            bestLabel: (s) => 'Best $s in a row',
          );
        }).toList(),
        activeIndex: _difficulty.index,
        onChanged: (i) => setState(() => _difficulty = _Difficulty.values[i]),
        onPlayAi: () => _selectMode(_Mode.ai),
        onPlayFriend: () => _selectMode(_Mode.twoPlayer),
      ),
    );
  }

  Widget _buildGame() {
    final (black, white) = _discCounts;
    final isP1Turn = _currentPlayer == 1 || _inUndoWindow;
    final topC = _gameOver ? _kBgTop : (isP1Turn ? const Color(0xFFF0F5F0) : const Color(0xFFF5F5F0));
    final botC = _gameOver ? _kBgBot : (isP1Turn ? const Color(0xFFE0EDE0) : const Color(0xFFEDE8E0));

    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 400),
      tween: ColorTween(end: topC),
      builder: (context, animTop, _) {
        return TweenAnimationBuilder<Color?>(
          duration: const Duration(milliseconds: 400),
          tween: ColorTween(end: botC),
          builder: (context, animBot, _) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [animTop ?? topC, animBot ?? botC],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    GameHudBar(
                      leading: GameBackButton(onTap: _backOrHome),
                      centerContent: _ScorePill(
                        mode: _mode!,
                        difficulty: _difficulty,
                        p1Wins: _p1Wins,
                        p2Wins: _p2Wins,
                      ),
                      trailing: GameRestartButton(
                        gameName: 'Reversi',
                        accentColor: _kAccent,
                        onRestart: _playAgain,
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      child: _showStreakBadge
                          ? Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: _StreakChip(streak: _streak),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: PlayerStrip(
                        label: _mode == _Mode.ai ? 'AI' : 'P2',
                        mark: '●',
                        color: _kP2Strip,
                        isActive: _currentPlayer == 2 && !_inUndoWindow && !_gameOver && !_waitingForFlip,
                        isThinking: _aiThinking,
                        avatarIcon: _mode == _Mode.ai ? Icons.smart_toy_rounded : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _DiscCount3D(isBlack: true, count: black),
                          const SizedBox(width: 16),
                          const Text('—', style: TextStyle(color: Color(0xFF666666), fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 16),
                          _DiscCount3D(isBlack: false, count: white),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Stack(
                            children: [
                              _BoardWidget(
                                grid: _grid,
                                validMoves: _validMoves,
                                showHints: !_aiThinking && !_gameOver && !_waitingForFlip,
                                onCellTap: _onCellTap,
                                flippingFrom: _flippingFrom,
                                flipCtrl: _flipCtrl,
                                lastPlacedR: _lastPlacedR,
                                lastPlacedC: _lastPlacedC,
                                placeCtrl: _placeCtrl,
                                currentPlayer: _currentPlayer,
                              ),
                              if (_celebrating)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: _Confetti(color: _kBoardGreen),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: PlayerStrip(
                        label: _mode == _Mode.ai ? 'You' : 'P1',
                        mark: '●',
                        color: _kP1Strip,
                        isActive: isP1Turn && !_gameOver,
                        isThinking: false,
                      ),
                    ),
                    SizedBox(
                      height: 44,
                      child: _canUndo
                          ? Center(
                              child: RewardedUndoButton(
                                key: ValueKey('undo_rv_${_grid.map((r) => r.join()).join("_")}'),
                                onUndo: _performUndo,
                                onExpired: _onUndoExpired,
                                accentColor: _kBoardGreen,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildResultScreen() {
    final isAi = _mode == _Mode.ai;
    final (black, white) = _discCounts;
    String headline;
    String big;
    Color bigColor;
    if (black > white) {
      headline = isAi ? 'You Win!' : 'Player 1 Wins!';
      big = '⚫';
      bigColor = _kBlackDisc;
    } else if (white > black) {
      headline = isAi ? 'AI Wins!' : 'Player 2 Wins!';
      big = '⚪';
      bigColor = const Color(0xFF888888);
    } else {
      headline = "It's a Draw!";
      big = '=';
      bigColor = _kDrawColor;
    }

    final winner = black > white ? 1 : (white > black ? 2 : null);
    final showStreak = _streak >= 2 && _streakOwner == winner;
    final extraBadges = <Widget>[
      if (showStreak) _StreakChip(streak: _streak),
      if (_wasNewBest) _NewBestChip(),
    ];

    return game_result.GenericGameResultScreen(
      gameId: _gameId,
      score: _streak,
      headline: headline,
      subtitle: '$black - $white',
      badgeContent: big,
      badgeColor: bigColor,
      showNewBestBadge: false,
      extraBadges: extraBadges,
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(label: isAi ? 'YOU' : 'P1', value: _p1Wins, color: const Color(0xFF333333)),
          game_result.StatItem(label: 'DRAWS', value: _draws, color: const Color(0xFF8B7BA7)),
          game_result.StatItem(label: isAi ? 'AI' : 'P2', value: _p2Wins, color: const Color(0xFF888888)),
          if (isAi)
            game_result.StatItem(
              label: 'BEST',
              value: ScoreService().getHighScore(_gameId, subKey: _aiSubKey()),
              color: const Color(0xFF6C63FF),
            ),
        ],
      ),
      actions: [
        game_result.GameResultAction(
          label: 'Play Again',
          icon: Icons.refresh_rounded,
          onTap: _playAgain,
          filled: true,
          color: _kAccent,
          actionId: 'play_again',
        ),
        game_result.GameResultAction(
          label: 'Change Mode',
          icon: Icons.swap_horiz_rounded,
          onTap: _changeMode,
          actionId: 'change_mode',
        ),
        game_result.GameResultAction(
          label: 'Home',
          icon: Icons.home_rounded,
          onTap: _backOrHome,
          actionId: 'home',
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// BOARD WIDGET
// ════════════════════════════════════════════════════════════════

class _BoardWidget extends StatelessWidget {
  final List<List<int>> grid;
  final List<List<int>> validMoves;
  final bool showHints;
  final void Function(int r, int c) onCellTap;
  final Map<String, int> flippingFrom;
  final AnimationController flipCtrl;
  final int? lastPlacedR;
  final int? lastPlacedC;
  final AnimationController placeCtrl;
  final int currentPlayer;

  const _BoardWidget({
    required this.grid,
    required this.validMoves,
    required this.showHints,
    required this.onCellTap,
    required this.flippingFrom,
    required this.flipCtrl,
    required this.lastPlacedR,
    required this.lastPlacedC,
    required this.placeCtrl,
    required this.currentPlayer,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final maxSide = math.min(c.maxWidth, c.maxHeight);
      final frame = 6.0;
      final inner = maxSide - frame * 2;
      final cell = inner / _kN;
      final side = cell * _kN;

      return SizedBox(
        width: side + frame * 2,
        height: side + frame * 2,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [Color(0xFF5A3E1B), Color(0xFF3E2A10), Color(0xFF2D1E0A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.40),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFF7A5C30).withValues(alpha: 0.30),
                blurRadius: 1,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          padding: EdgeInsets.all(frame),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                CustomPaint(
                  size: Size.square(side),
                  painter: _Board3DPainter(),
                ),
                for (int r = 0; r < _kN; r++)
                  for (int col = 0; col < _kN; col++)
                    Positioned(
                      left: col * cell,
                      top: r * cell,
                      width: cell,
                      height: cell,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onCellTap(r, col),
                        child: Center(
                          child: _buildCell(r, col, cell * 0.40),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildCell(int r, int c, double radius) {
    final value = grid[r][c];
    final key = '$r,$c';
    final isFlipping = flippingFrom.containsKey(key);
    final isPlaced = lastPlacedR == r && lastPlacedC == c;
    final isValid = showHints && validMoves.any((m) => m[0] == r && m[1] == c);

    if (value == 0 && isValid) {
      return _ValidHint(radius: radius, currentPlayer: currentPlayer);
    }
    if (value == 0) return const SizedBox.shrink();

    if (isFlipping) {
      final oldPlayer = flippingFrom[key]!;
      return AnimatedBuilder(
        animation: flipCtrl,
        builder: (_, _) {
          final t = flipCtrl.value;
          final scaleX = (t < 0.5)
              ? 1.0 - t * 2.0
              : (t - 0.5) * 2.0;
          final showPlayer = t < 0.5 ? oldPlayer : value;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(scaleX.clamp(0.02, 1.0), 1.0, 1.0),
            child: _ReversiDisc3D(isBlack: showPlayer == 1, radius: radius),
          );
        },
      );
    }

    if (isPlaced) {
      return AnimatedBuilder(
        animation: placeCtrl,
        builder: (_, _) {
          final s = Curves.elasticOut.transform(placeCtrl.value.clamp(0.0, 1.0));
          return Transform.scale(
            scale: s,
            child: _ReversiDisc3D(isBlack: value == 1, radius: radius),
          );
        },
      );
    }

    return _ReversiDisc3D(isBlack: value == 1, radius: radius);
  }
}

class _ValidHint extends StatefulWidget {
  final double radius;
  final int currentPlayer;
  const _ValidHint({required this.radius, required this.currentPlayer});

  @override
  State<_ValidHint> createState() => _ValidHintState();
}

class _ValidHintState extends State<_ValidHint> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, _) {
        final a = 0.12 + _pulse.value * 0.14;
        return Container(
          width: widget.radius * 2,
          height: widget.radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (widget.currentPlayer == 1 ? Colors.black : Colors.white).withValues(alpha: a),
            border: Border.all(
              color: (widget.currentPlayer == 1 ? Colors.black : Colors.white).withValues(alpha: a + 0.05),
              width: 1,
            ),
          ),
        );
      },
    );
  }
}

class _Board3DPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _kN;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF3A8F3A), Color(0xFF2E7D32), Color(0xFF256B28)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );

    final darkLine = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..strokeWidth = 1.2;
    final lightLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 0.8;
    for (int i = 1; i < _kN; i++) {
      final p = i * cell;
      canvas.drawLine(Offset(p, 0), Offset(p, size.height), darkLine);
      canvas.drawLine(Offset(p + 1, 0), Offset(p + 1, size.height), lightLine);
      canvas.drawLine(Offset(0, p), Offset(size.width, p), darkLine);
      canvas.drawLine(Offset(0, p + 1), Offset(size.width, p + 1), lightLine);
    }

    final dotPaint = Paint()..color = Colors.black.withValues(alpha: 0.35);
    for (final pos in [[2, 2], [2, 6], [6, 2], [6, 6]]) {
      canvas.drawCircle(Offset(pos[1] * cell, pos[0] * cell), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_Board3DPainter old) => false;
}

class _ReversiDisc3D extends StatelessWidget {
  final bool isBlack;
  final double radius;
  const _ReversiDisc3D({required this.isBlack, required this.radius});

  @override
  Widget build(BuildContext context) {
    final d = radius * 2;
    return SizedBox(
      width: d,
      height: d,
      child: CustomPaint(painter: _Disc3DPainter(isBlack: isBlack, radius: radius)),
    );
  }
}

class _Disc3DPainter extends CustomPainter {
  final bool isBlack;
  final double radius;
  _Disc3DPainter({required this.isBlack, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(
      Offset(center.dx + 1, center.dy + 2),
      radius,
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );

    if (isBlack) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.40),
            radius: 1.1,
            colors: const [
              Color(0xFF4A4A4A),
              Color(0xFF2A2A2A),
              Color(0xFF0A0A0A),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );

      canvas.drawCircle(
        center,
        radius * 0.70,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.20, -0.25),
            radius: 0.8,
            colors: [
              Colors.white.withValues(alpha: 0.0),
              Colors.white.withValues(alpha: 0.04),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius * 0.70)),
      );

      final specC = Offset(center.dx - radius * 0.25, center.dy - radius * 0.28);
      canvas.drawCircle(
        specC,
        radius * 0.18,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.50),
              Colors.white.withValues(alpha: 0.12),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: specC, radius: radius * 0.18)),
      );
    } else {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.40),
            radius: 1.1,
            colors: const [
              Color(0xFFFFFFFF),
              Color(0xFFF0F0F0),
              Color(0xFFD8D8D8),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );

      canvas.drawCircle(
        center,
        radius * 0.70,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.20, -0.25),
            radius: 0.8,
            colors: [
              Colors.white.withValues(alpha: 0.0),
              Colors.white.withValues(alpha: 0.15),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius * 0.70)),
      );

      final specC = Offset(center.dx - radius * 0.25, center.dy - radius * 0.28);
      canvas.drawCircle(
        specC,
        radius * 0.20,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.90),
              Colors.white.withValues(alpha: 0.30),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: specC, radius: radius * 0.20)),
      );

      canvas.drawCircle(
        center,
        radius - 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0xFFBBBBBB),
      );
    }

    canvas.drawCircle(
      center,
      radius - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = Colors.black.withValues(alpha: isBlack ? 0.30 : 0.10),
    );
  }

  @override
  bool shouldRepaint(_Disc3DPainter old) => old.isBlack != isBlack || old.radius != radius;
}

// ════════════════════════════════════════════════════════════════
// HUD WIDGETS
// ════════════════════════════════════════════════════════════════

class _DiscCount3D extends StatelessWidget {
  final bool isBlack;
  final int count;
  const _DiscCount3D({required this.isBlack, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CustomPaint(
            painter: _Disc3DPainter(isBlack: isBlack, radius: 10),
          ),
        ),
        const SizedBox(width: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Text(
            '$count',
            key: ValueKey(count),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF333333)),
          ),
        ),
      ],
    );
  }
}

class _ScorePill extends StatelessWidget {
  final _Mode mode;
  final _Difficulty difficulty;
  final int p1Wins;
  final int p2Wins;

  const _ScorePill({
    required this.mode,
    required this.difficulty,
    required this.p1Wins,
    required this.p2Wins,
  });

  @override
  Widget build(BuildContext context) {
    final isAi = mode == _Mode.ai;
    final tabLabel = isAi ? ['EASY', 'MEDIUM', 'HARD'][difficulty.index] : 'PASS & PLAY';
    final tabColor = isAi
        ? [_kEasyColor, _kMediumColor, _kHardColor][difficulty.index]
        : const Color(0xFF8475C2);

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
              if (isAi) ...[
                AnimatedDifficultyIcon(
                  kind: [DifficultyKind.easy, DifficultyKind.medium, DifficultyKind.hard][difficulty.index],
                  size: 14,
                  prominent: false,
                ),
                const SizedBox(width: 6),
              ],
              Text(tabLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _kAccent.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _scoreCol(isAi ? 'YOU' : 'P1', p1Wins, const Color(0xFF333333)),
                  const SizedBox(width: 14),
                  const Text('VS', style: TextStyle(color: Color(0xFF8B7BA7), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  const SizedBox(width: 14),
                  _scoreCol(isAi ? 'AI' : 'P2', p2Wins, const Color(0xFF888888)),
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
      _Difficulty.easy => kRvSubKeyEasy,
      _Difficulty.medium => kRvSubKeyMedium,
      _Difficulty.hard => kRvSubKeyHard,
    };
    final best = ScoreService().getHighScore(kReversiGameId, subKey: subKey);
    if (best <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text('best $best',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _scoreCol(String label, int value, Color color) {
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
          child: Text('$value', key: ValueKey(value), style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
        ),
      ],
    );
  }
}

class _StreakChip extends StatelessWidget {
  final int streak;
  const _StreakChip({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFB36B), Color(0xFFFF7A89)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: const Color(0xFFFF7A89).withValues(alpha: 0.30), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text('Streak $streak', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6)),
        ],
      ),
    );
  }
}

class _NewBestChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFC233), Color(0xFFFF8A00)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: const Color(0xFFFF9500).withValues(alpha: 0.40), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_rounded, color: Colors.white, size: 18),
          SizedBox(width: 6),
          Text('New best!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.6)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CONFETTI
// ════════════════════════════════════════════════════════════════

class _Confetti extends StatefulWidget {
  final Color color;
  const _Confetti({required this.color});

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_ConfettiP> _particles;
  static final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _particles = List.generate(36, (i) {
      return _ConfettiP(
        angle: (i / 36) * math.pi * 2 + _rng.nextDouble() * 0.5,
        speed: 0.55 + _rng.nextDouble() * 0.35,
        size: 3.0 + _rng.nextDouble() * 4.0,
        hueShift: _rng.nextDouble(),
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

class _ConfettiP {
  final double angle, speed, size, hueShift;
  _ConfettiP({required this.angle, required this.speed, required this.size, required this.hueShift});
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiP> particles;
  final Color baseColor;
  _ConfettiPainter({required this.progress, required this.particles, required this.baseColor});

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
          .withLightness((hsl.lightness + (p.hueShift - 0.5) * 0.35).clamp(0.35, 0.85))
          .toColor()
          .withValues(alpha: alpha);
      canvas.drawCircle(pos, p.size * (0.5 + alpha * 0.5), Paint()..color = colored);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}

// ════════════════════════════════════════════════════════════════
// ANIMATED BACKGROUND
// ════════════════════════════════════════════════════════════════

class _ReversiBgPainter extends AnimatedBgPainter {
  const _ReversiBgPainter(super.t);

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final phase = t * 2 * math.pi;
    final w = size.width;
    final h = size.height;

    final blackP = Paint()..color = _kBlackDisc.withValues(alpha: 0.06);
    final whiteP = Paint()..color = Colors.grey.withValues(alpha: 0.08);

    final items = [
      (true, 0.12, 0.12, 14.0, 0.0),
      (false, 0.88, 0.08, 16.0, 0.7),
      (true, 0.06, 0.55, 12.0, 1.4),
      (false, 0.92, 0.42, 18.0, 2.1),
      (true, 0.10, 0.85, 15.0, 2.8),
      (false, 0.82, 0.88, 13.0, 3.5),
      (true, 0.50, 0.03, 10.0, 4.2),
      (false, 0.42, 0.96, 16.0, 4.9),
    ];

    for (final (isBlack, xRel, yRel, r, p) in items) {
      final bobY = math.sin(phase + p * 0.5) * (r * 0.15);
      canvas.drawCircle(
        Offset(w * xRel, h * yRel + bobY),
        r,
        isBlack ? blackP : whiteP,
      );
    }
  }
}
