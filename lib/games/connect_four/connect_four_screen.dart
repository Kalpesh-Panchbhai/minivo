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
import 'connect_four_stats.dart';
import 'connect_four_tutorial.dart';
import '../shared/generic_game_result_screen.dart' as game_result;

const int _kRows = 6;
const int _kCols = 7;

const Color _kP1Color = Color(0xFFE85D75);
const Color _kP2Color = Color(0xFFF5C542);
const Color _kDrawColor = Color(0xFFB6A5DD);
const Color _kBoardColor = Color(0xFF3366CC);
const Color _kAccent = Color(0xFF3366CC);

const Color _kTintP1Top = Color(0xFFFFF0EE);
const Color _kTintP1Bot = Color(0xFFFFE4E0);
const Color _kTintP2Top = Color(0xFFFFFBE8);
const Color _kTintP2Bot = Color(0xFFFFF3C4);
const Color _kTintNeutralTop = Color(0xFFF0F4FF);
const Color _kTintNeutralBot = Color(0xFFE8EEFF);

const Color _kBgTop = Color(0xFFF0F4FF);
const Color _kBgBot = Color(0xFFE8EEFF);

const Color _kEasyColor = Color(0xFF22C55E);
const Color _kMediumColor = Color(0xFFF59E0B);
const Color _kHardColor = Color(0xFFEF4444);

enum _Mode { ai, twoPlayer }

enum _Difficulty { easy, medium, hard }

class ConnectFourScreen extends StatefulWidget {
  const ConnectFourScreen({super.key});

  @override
  State<ConnectFourScreen> createState() => _ConnectFourScreenState();
}

class _ConnectFourScreenState extends State<ConnectFourScreen>
    with TickerProviderStateMixin {
  _Mode? _mode;
  _Difficulty _difficulty = _Difficulty.values[DifficultyKind.defaultIndex];

  late List<List<int>> _grid;
  int _currentPlayer = 1;
  bool _gameOver = false;
  bool _aiThinking = false;
  List<List<int>> _winCells = [];
  String? _bannerLabel;
  Color _bannerColor = _kDrawColor;
  bool _showBanner = false;
  bool _celebrating = false;

  int _p1Wins = 0;
  int _p2Wins = 0;
  int _draws = 0;

  int _streak = 0;
  int? _streakOwner;
  bool _showStreakBadge = false;
  bool _wasNewBest = false;

  int _starter = 1;
  bool _firstRound = true;

  int? _lastMoveRow;
  int? _lastMoveCol;
  bool _undoUsedThisRound = false;
  bool _inUndoWindow = false;

  int? _dropCol;
  int? _dropTargetRow;
  int? _dropPlayer;
  late final AnimationController _dropCtrl;

  bool _isFavorite = false;
  static const _gameId = kConnectFourGameId;

  final _audio = AudioService();
  final _rng = math.Random();
  Timer? _aiTimer;
  Timer? _endTimer;

  late final AnimationController _winCtrl;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(_gameId);
    _grid = _emptyGrid();
    _winCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _dropCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _onDropComplete();
      });
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    _endTimer?.cancel();
    _winCtrl.dispose();
    _dropCtrl.dispose();
    super.dispose();
  }

  GameWrapperState get _wrapper => GameWrapper.of(context);

  static List<List<int>> _emptyGrid() =>
      List.generate(_kRows, (_) => List.filled(_kCols, 0));

  bool get _isDropping => _dropCol != null;

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
      _firstRound = true;
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
      _firstRound = true;
      _resetBoard(notify: false);
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

  void _resetBoard({bool notify = true}) {
    void apply() {
      if (_firstRound) {
        _starter = _rng.nextBool() ? 1 : 2;
        _firstRound = false;
      } else {
        _starter = _starter == 1 ? 2 : 1;
      }
      _grid = _emptyGrid();
      _currentPlayer = _starter;
      _gameOver = false;
      _aiThinking = false;
      _winCells = [];
      _showBanner = false;
      _bannerLabel = null;
      _wasNewBest = false;
      _showStreakBadge = false;
      _celebrating = false;
      _winCtrl.value = 0;
      _lastMoveRow = null;
      _lastMoveCol = null;
      _undoUsedThisRound = false;
      _inUndoWindow = false;
      _dropCol = null;
      _dropTargetRow = null;
      _dropPlayer = null;
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
      steps: connectFourSteps(),
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
    setState(() => _inUndoWindow = false);
    _scheduleAiMove();
  }

  void _performUndo() {
    final r = _lastMoveRow;
    final c = _lastMoveCol;
    if (r == null || c == null) return;
    setState(() {
      _grid[r][c] = 0;
      _currentPlayer = 1;
      _inUndoWindow = false;
      _lastMoveRow = null;
      _lastMoveCol = null;
      _undoUsedThisRound = true;
    });
  }

  // ════════════════════════════════════════════════════════════════
  // GAMEPLAY
  // ════════════════════════════════════════════════════════════════

  int? _dropRow(int col) {
    for (int r = _kRows - 1; r >= 0; r--) {
      if (_grid[r][col] == 0) return r;
    }
    return null;
  }

  void _onColumnTap(int col) {
    if (_gameOver || _isDropping) return;
    if (_mode == _Mode.ai && (_aiThinking || _inUndoWindow || _currentPlayer != 1)) return;
    final row = _dropRow(col);
    if (row == null) return;
    _startDrop(row, col, _currentPlayer);
  }

  void _startDrop(int row, int col, int player) {
    setState(() {
      _dropCol = col;
      _dropTargetRow = row;
      _dropPlayer = player;
    });
    _dropCtrl.forward(from: 0);
  }

  void _onDropComplete() {
    if (!mounted) return;
    final row = _dropTargetRow!;
    final col = _dropCol!;
    final player = _dropPlayer!;

    setState(() {
      _grid[row][col] = player;
      _dropCol = null;
      _dropTargetRow = null;
      _dropPlayer = null;
    });
    _audio.playTap();

    final win = _checkWin(player);
    if (win != null) {
      _onWin(win, player);
      return;
    }
    if (_isBoardFull()) {
      _onDraw();
      return;
    }

    final isHumanInAi = _mode == _Mode.ai && player == 1;
    setState(() {
      _currentPlayer = _currentPlayer == 1 ? 2 : 1;
      if (isHumanInAi) {
        _lastMoveRow = row;
        _lastMoveCol = col;
      }
    });

    if (_mode == _Mode.ai && _currentPlayer == 2) {
      final undoAvailable = !_undoUsedThisRound && AdsService().isRewardedReady;
      if (undoAvailable) {
        setState(() => _inUndoWindow = true);
      } else {
        _scheduleAiMove();
      }
    }
  }

  void _scheduleAiMove() {
    setState(() => _aiThinking = true);
    final ms = switch (_difficulty) {
      _Difficulty.easy => 600,
      _Difficulty.medium => 800,
      _Difficulty.hard => 1000,
    };
    _aiTimer?.cancel();
    _aiTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted || _gameOver) return;
      final col = _pickAiMove();
      final row = _dropRow(col)!;
      setState(() {
        _aiThinking = false;
        _lastMoveRow = null;
        _lastMoveCol = null;
      });
      _startDrop(row, col, 2);
    });
  }

  int _pickAiMove() {
    switch (_difficulty) {
      case _Difficulty.easy:
        if (_rng.nextDouble() < 0.6) return _randomMove();
        return _smartMove(depth: 2);
      case _Difficulty.medium:
        return _smartMove(depth: 4);
      case _Difficulty.hard:
        return _smartMove(depth: 6);
    }
  }

  int _randomMove() {
    final valid = <int>[];
    for (int c = 0; c < _kCols; c++) {
      if (_grid[0][c] == 0) valid.add(c);
    }
    return valid[_rng.nextInt(valid.length)];
  }

  int _smartMove({required int depth}) {
    for (int c = 0; c < _kCols; c++) {
      final r = _dropRow(c);
      if (r == null) continue;
      _grid[r][c] = 2;
      if (_checkWin(2) != null) {
        _grid[r][c] = 0;
        return c;
      }
      _grid[r][c] = 0;
    }

    for (int c = 0; c < _kCols; c++) {
      final r = _dropRow(c);
      if (r == null) continue;
      _grid[r][c] = 1;
      if (_checkWin(1) != null) {
        _grid[r][c] = 0;
        return c;
      }
      _grid[r][c] = 0;
    }

    int bestScore = -100000;
    int bestCol = _randomMove();
    for (int c = 0; c < _kCols; c++) {
      final r = _dropRow(c);
      if (r == null) continue;
      _grid[r][c] = 2;
      final score = _minimax(depth - 1, false, -100000, 100000);
      _grid[r][c] = 0;
      if (score > bestScore) {
        bestScore = score;
        bestCol = c;
      }
    }
    return bestCol;
  }

  int _minimax(int depth, bool isMax, int alpha, int beta) {
    if (_checkWin(2) != null) return 1000 + depth;
    if (_checkWin(1) != null) return -(1000 + depth);
    if (_isBoardFull() || depth <= 0) return _evaluate();

    if (isMax) {
      int best = -100000;
      for (int c = 0; c < _kCols; c++) {
        final r = _dropRow(c);
        if (r == null) continue;
        _grid[r][c] = 2;
        final s = _minimax(depth - 1, false, alpha, beta);
        _grid[r][c] = 0;
        if (s > best) best = s;
        if (best > alpha) alpha = best;
        if (beta <= alpha) break;
      }
      return best;
    } else {
      int best = 100000;
      for (int c = 0; c < _kCols; c++) {
        final r = _dropRow(c);
        if (r == null) continue;
        _grid[r][c] = 1;
        final s = _minimax(depth - 1, true, alpha, beta);
        _grid[r][c] = 0;
        if (s < best) best = s;
        if (best < beta) beta = best;
        if (beta <= alpha) break;
      }
      return best;
    }
  }

  int _evaluate() {
    int score = 0;
    score += _grid[_kRows - 1][3] == 2 ? 3 : (_grid[_kRows - 1][3] == 1 ? -3 : 0);

    for (int r = 0; r < _kRows; r++) {
      for (int c = 0; c < _kCols - 3; c++) {
        score += _scoreWindow([_grid[r][c], _grid[r][c + 1], _grid[r][c + 2], _grid[r][c + 3]]);
      }
    }
    for (int c = 0; c < _kCols; c++) {
      for (int r = 0; r < _kRows - 3; r++) {
        score += _scoreWindow([_grid[r][c], _grid[r + 1][c], _grid[r + 2][c], _grid[r + 3][c]]);
      }
    }
    for (int r = 0; r < _kRows - 3; r++) {
      for (int c = 0; c < _kCols - 3; c++) {
        score += _scoreWindow([_grid[r][c], _grid[r + 1][c + 1], _grid[r + 2][c + 2], _grid[r + 3][c + 3]]);
      }
    }
    for (int r = 3; r < _kRows; r++) {
      for (int c = 0; c < _kCols - 3; c++) {
        score += _scoreWindow([_grid[r][c], _grid[r - 1][c + 1], _grid[r - 2][c + 2], _grid[r - 3][c + 3]]);
      }
    }
    return score;
  }

  int _scoreWindow(List<int> w) {
    final ai = w.where((v) => v == 2).length;
    final hu = w.where((v) => v == 1).length;
    final em = w.where((v) => v == 0).length;
    if (ai == 3 && em == 1) return 5;
    if (ai == 2 && em == 2) return 2;
    if (hu == 3 && em == 1) return -4;
    return 0;
  }

  List<List<int>>? _checkWin(int player) {
    for (int r = 0; r < _kRows; r++) {
      for (int c = 0; c < _kCols - 3; c++) {
        if (_grid[r][c] == player && _grid[r][c + 1] == player &&
            _grid[r][c + 2] == player && _grid[r][c + 3] == player) {
          return [[r, c], [r, c + 1], [r, c + 2], [r, c + 3]];
        }
      }
    }
    for (int c = 0; c < _kCols; c++) {
      for (int r = 0; r < _kRows - 3; r++) {
        if (_grid[r][c] == player && _grid[r + 1][c] == player &&
            _grid[r + 2][c] == player && _grid[r + 3][c] == player) {
          return [[r, c], [r + 1, c], [r + 2, c], [r + 3, c]];
        }
      }
    }
    for (int r = 0; r < _kRows - 3; r++) {
      for (int c = 0; c < _kCols - 3; c++) {
        if (_grid[r][c] == player && _grid[r + 1][c + 1] == player &&
            _grid[r + 2][c + 2] == player && _grid[r + 3][c + 3] == player) {
          return [[r, c], [r + 1, c + 1], [r + 2, c + 2], [r + 3, c + 3]];
        }
      }
    }
    for (int r = 3; r < _kRows; r++) {
      for (int c = 0; c < _kCols - 3; c++) {
        if (_grid[r][c] == player && _grid[r - 1][c + 1] == player &&
            _grid[r - 2][c + 2] == player && _grid[r - 3][c + 3] == player) {
          return [[r, c], [r - 1, c + 1], [r - 2, c + 2], [r - 3, c + 3]];
        }
      }
    }
    return null;
  }

  bool _isBoardFull() {
    for (int c = 0; c < _kCols; c++) {
      if (_grid[0][c] == 0) return false;
    }
    return true;
  }

  String? _aiSubKey() {
    if (_mode != _Mode.ai) return null;
    return switch (_difficulty) {
      _Difficulty.easy => kC4SubKeyEasy,
      _Difficulty.medium => kC4SubKeyMedium,
      _Difficulty.hard => kC4SubKeyHard,
    };
  }

  void _onWin(List<List<int>> cells, int player) {
    final isAi = _mode == _Mode.ai;
    setState(() {
      _winCells = cells;
      _gameOver = true;
      _showBanner = true;
      _celebrating = true;
      if (player == 1) {
        _p1Wins++;
        _bannerLabel = isAi ? 'You Win!' : 'Player 1 Wins!';
        _bannerColor = _kP1Color;
      } else {
        _p2Wins++;
        _bannerLabel = isAi ? 'AI Wins!' : 'Player 2 Wins!';
        _bannerColor = _kP2Color;
      }
      if (_streakOwner == player) {
        _streak++;
      } else {
        _streakOwner = player;
        _streak = 1;
      }
      _showStreakBadge = _streak >= 2;
    });

    if (isAi && player == 1) {
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

    if (isAi && player == 1) _wrapper.updateScore(_streak);

    _winCtrl.forward(from: 0);
    final gameResult = isAi ? (player == 1 ? 'win' : 'loss') : 'win';
    _audio.playSuccess();
    _endTimer?.cancel();
    _endTimer = Timer(const Duration(milliseconds: 1700), () {
      if (mounted) _wrapper.endGame(result: gameResult);
    });
  }

  void _onDraw() {
    setState(() {
      _gameOver = true;
      _showBanner = true;
      _draws++;
      _bannerLabel = "It's a Draw!";
      _bannerColor = _kDrawColor;
      _streak = 0;
      _streakOwner = null;
      _showStreakBadge = false;
      _wasNewBest = false;
    });
    _endTimer?.cancel();
    _endTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) _wrapper.endGame(result: 'draw');
    });
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
        factory: (t) => _C4BgPainter(t),
        period: const Duration(seconds: 9),
      ),
      iconRingColors: const [_kBoardColor, _kP1Color, _kP2Color],
      iconChild: Builder(builder: (ctx) {
        final info = GameRegistry.getById(_gameId);
        final logo = info?.buildBrandedLogo(size: 84);
        if (logo != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(42),
            child: logo,
          );
        }
        return const Icon(Icons.grid_4x4_rounded, size: 40, color: _kAccent);
      }),
      title: 'Connect Four',
      subtitle: 'Drop discs, connect 4 to win!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: _gameId,
      tallThreshold: 860,
      body: GameAiPickerBody(
        difficulties: _Difficulty.values.map((d) {
          final subKey = switch (d) {
            _Difficulty.easy => kC4SubKeyEasy,
            _Difficulty.medium => kC4SubKeyMedium,
            _Difficulty.hard => kC4SubKeyHard,
          };
          return GameDifficultyData(
            label: _diffLabel(d),
            color: [_kEasyColor, _kMediumColor, _kHardColor][d.index],
            kind: [DifficultyKind.easy, DifficultyKind.medium, DifficultyKind.hard][d.index],
            hint: switch (d) {
              _Difficulty.easy => 'Mostly random moves.',
              _Difficulty.medium => 'Thinks a few moves ahead.',
              _Difficulty.hard => 'Deep search — tough to beat!',
            },
            bestScore: bestC4Streak(subKey),
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
    final isP1Turn = _currentPlayer == 1 || _inUndoWindow;
    final topColor = (_showBanner)
        ? _kTintNeutralTop
        : (isP1Turn ? _kTintP1Top : _kTintP2Top);
    final botColor = (_showBanner)
        ? _kTintNeutralBot
        : (isP1Turn ? _kTintP1Bot : _kTintP2Bot);

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
                        gameName: 'Connect Four',
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
                        color: _kP2Color,
                        isActive: _currentPlayer == 2 && !_inUndoWindow && !_gameOver,
                        isThinking: _aiThinking,
                        avatarIcon: _mode == _Mode.ai ? Icons.smart_toy_rounded : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Stack(
                            children: [
                              _BoardWidget(
                                grid: _grid,
                                winCells: _winCells,
                                winCtrl: _winCtrl,
                                onColumnTap: _onColumnTap,
                                currentPlayer: _currentPlayer,
                                gameOver: _gameOver,
                                dropCol: _dropCol,
                                dropTargetRow: _dropTargetRow,
                                dropPlayer: _dropPlayer,
                                dropCtrl: _dropCtrl,
                              ),
                              if (_celebrating)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: _Confetti(color: _bannerColor),
                                  ),
                                ),
                              if (_showBanner && _bannerLabel != null)
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
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: PlayerStrip(
                        label: _mode == _Mode.ai ? 'You' : 'P1',
                        mark: '●',
                        color: _kP1Color,
                        isActive: isP1Turn && !_gameOver,
                        isThinking: false,
                      ),
                    ),
                    SizedBox(
                      height: 44,
                      child: _canUndo
                          ? Center(
                              child: RewardedUndoButton(
                                key: ValueKey('undo_${_grid.map((r) => r.join()).join("_")}'),
                                onUndo: _performUndo,
                                onExpired: _onUndoExpired,
                                accentColor: _kP1Color,
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
    String headline;
    String big;
    Color bigColor;
    final winner = _winCells.isNotEmpty
        ? _grid[_winCells[0][0]][_winCells[0][1]]
        : 0;
    if (winner == 1) {
      headline = isAi ? 'You Win!' : 'Player 1 Wins!';
      big = '🔴';
      bigColor = _kP1Color;
    } else if (winner == 2) {
      headline = isAi ? 'AI Wins!' : 'Player 2 Wins!';
      big = '🟡';
      bigColor = _kP2Color;
    } else {
      headline = "It's a Draw!";
      big = '=';
      bigColor = _kDrawColor;
    }

    final showStreak = _streak >= 2 && _streakOwner == winner;
    final extraBadges = <Widget>[
      if (showStreak) _StreakChip(streak: _streak),
      if (_wasNewBest) _NewBestChip(),
    ];

    return game_result.GenericGameResultScreen(
      gameId: _gameId,
      score: _streak,
      headline: headline,
      badgeContent: big,
      badgeColor: bigColor,
      showNewBestBadge: false,
      extraBadges: extraBadges,
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(label: isAi ? 'YOU' : 'P1', value: _p1Wins, color: _kP1Color),
          game_result.StatItem(label: 'DRAWS', value: _draws, color: const Color(0xFF8B7BA7)),
          game_result.StatItem(label: isAi ? 'AI' : 'P2', value: _p2Wins, color: _kP2Color),
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
  final List<List<int>> winCells;
  final AnimationController winCtrl;
  final ValueChanged<int> onColumnTap;
  final int currentPlayer;
  final bool gameOver;
  final int? dropCol;
  final int? dropTargetRow;
  final int? dropPlayer;
  final AnimationController? dropCtrl;

  const _BoardWidget({
    required this.grid,
    required this.winCells,
    required this.winCtrl,
    required this.onColumnTap,
    required this.currentPlayer,
    required this.gameOver,
    this.dropCol,
    this.dropTargetRow,
    this.dropPlayer,
    this.dropCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final maxW = c.maxWidth;
      final maxH = c.maxHeight;
      final cellW = maxW / _kCols;
      final cellH = maxH / _kRows;
      final cell = math.min(cellW, cellH);
      final boardW = cell * _kCols;
      final boardH = cell * _kRows;
      final discR = cell * 0.38;

      return SizedBox(
        width: boardW,
        height: boardH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF4A7FE0),
                    Color(0xFF3366CC),
                    Color(0xFF2952A3),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A3A7A).withValues(alpha: 0.50),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: const Color(0xFF5A8FE8).withValues(alpha: 0.30),
                    blurRadius: 1,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 1,
                ),
              ),
            ),
            for (int r = 0; r < _kRows; r++)
              for (int col = 0; col < _kCols; col++)
                Positioned(
                  left: col * cell,
                  top: r * cell,
                  width: cell,
                  height: cell,
                  child: Center(
                    child: _CellWidget(
                      value: grid[r][col],
                      isWin: winCells.any((w) => w[0] == r && w[1] == col),
                      radius: discR,
                    ),
                  ),
                ),
            if (dropCol != null && dropTargetRow != null && dropPlayer != null && dropCtrl != null)
              AnimatedBuilder(
                animation: dropCtrl!,
                builder: (context, _) {
                  final t = Curves.bounceOut.transform(dropCtrl!.value.clamp(0.0, 1.0));
                  final startY = -cell;
                  final endY = dropTargetRow! * cell + (cell - discR * 2) / 2;
                  final currentY = startY + (endY - startY) * t;
                  final cx = dropCol! * cell + (cell - discR * 2) / 2;
                  return Positioned(
                    left: cx,
                    top: currentY,
                    child: _Disc3D(
                      color: dropPlayer == 1 ? _kP1Color : _kP2Color,
                      radius: discR,
                      isWin: false,
                    ),
                  );
                },
              ),
            for (int col = 0; col < _kCols; col++)
              Positioned(
                left: col * cell,
                top: 0,
                width: cell,
                height: boardH,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onColumnTap(col),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _CellWidget extends StatelessWidget {
  final int value;
  final bool isWin;
  final double radius;

  const _CellWidget({
    required this.value,
    required this.isWin,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    if (value == 0) return _Hole3D(radius: radius);
    final color = value == 1 ? _kP1Color : _kP2Color;
    return _Disc3D(color: color, radius: radius, isWin: isWin);
  }
}

class _Hole3D extends StatelessWidget {
  final double radius;
  const _Hole3D({required this.radius});

  @override
  Widget build(BuildContext context) {
    final d = radius * 2;
    return SizedBox(
      width: d,
      height: d,
      child: CustomPaint(
        painter: _Hole3DPainter(radius: radius),
      ),
    );
  }
}

class _Hole3DPainter extends CustomPainter {
  final double radius;
  _Hole3DPainter({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, 0.0),
          radius: 1.0,
          colors: [
            const Color(0xFF0D2240),
            const Color(0xFF132E56),
            const Color(0xFF1A3A7A),
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..shader = SweepGradient(
          colors: [
            Colors.black.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.06),
            Colors.black.withValues(alpha: 0.20),
            Colors.white.withValues(alpha: 0.04),
            Colors.black.withValues(alpha: 0.25),
          ],
          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_Hole3DPainter old) => old.radius != radius;
}

class _Disc3D extends StatelessWidget {
  final Color color;
  final double radius;
  final bool isWin;

  const _Disc3D({
    required this.color,
    required this.radius,
    required this.isWin,
  });

  @override
  Widget build(BuildContext context) {
    final d = radius * 2;
    return SizedBox(
      width: d,
      height: d,
      child: CustomPaint(
        painter: _Disc3DPainter(color: color, radius: radius, isWin: isWin),
      ),
    );
  }
}

class _Disc3DPainter extends CustomPainter {
  final Color color;
  final double radius;
  final bool isWin;

  _Disc3DPainter({
    required this.color,
    required this.radius,
    required this.isWin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final hsl = HSLColor.fromColor(color);
    final darkEdge = hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();
    final lightFace = hsl.withLightness((hsl.lightness + 0.08).clamp(0.0, 1.0)).toColor();

    if (isWin) {
      canvas.drawCircle(
        center,
        radius + 3,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    canvas.drawCircle(
      Offset(center.dx + 1, center.dy + 2),
      radius,
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.40),
          radius: 1.1,
          colors: [
            lightFace,
            color,
            darkEdge,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    canvas.drawCircle(
      center,
      radius * 0.72,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.30, -0.35),
          radius: 0.9,
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.06),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 0.72)),
    );

    final specCenter = Offset(center.dx - radius * 0.28, center.dy - radius * 0.30);
    canvas.drawCircle(
      specCenter,
      radius * 0.22,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.70),
            Colors.white.withValues(alpha: 0.20),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: specCenter, radius: radius * 0.22)),
    );

    canvas.drawCircle(
      center,
      radius - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = darkEdge.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_Disc3DPainter old) =>
      old.color != color || old.radius != radius || old.isWin != isWin;
}

// ════════════════════════════════════════════════════════════════
// HUD WIDGETS
// ════════════════════════════════════════════════════════════════

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
                  kind: [DifficultyKind.easy, DifficultyKind.medium, DifficultyKind.hard][difficulty.index],
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
                color: _kAccent.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _scoreCol(isAi ? 'YOU' : 'P1', p1Wins, _kP1Color),
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
                  _scoreCol(isAi ? 'AI' : 'P2', p2Wins, _kP2Color),
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
      _Difficulty.easy => kC4SubKeyEasy,
      _Difficulty.medium => kC4SubKeyMedium,
      _Difficulty.hard => kC4SubKeyHard,
    };
    final best = ScoreService().getHighScore(kConnectFourGameId, subKey: subKey);
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
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
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
      canvas.drawCircle(pos, p.size * (0.5 + alpha * 0.5), Paint()..color = colored);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ════════════════════════════════════════════════════════════════
// ANIMATED BACKGROUND
// ════════════════════════════════════════════════════════════════

class _C4BgPainter extends AnimatedBgPainter {
  const _C4BgPainter(super.t);

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final phase = t * 2 * math.pi;
    final w = size.width;
    final h = size.height;

    final redPaint = Paint()..color = _kP1Color.withValues(alpha: 0.08);
    final yellowPaint = Paint()..color = _kP2Color.withValues(alpha: 0.08);

    final items = [
      (true, 0.10, 0.15, 14.0, 0.0),
      (false, 0.85, 0.10, 16.0, 0.7),
      (true, 0.08, 0.50, 12.0, 1.4),
      (false, 0.90, 0.45, 18.0, 2.1),
      (true, 0.15, 0.80, 15.0, 2.8),
      (false, 0.80, 0.85, 13.0, 3.5),
      (true, 0.50, 0.05, 10.0, 4.2),
      (false, 0.45, 0.95, 16.0, 4.9),
      (true, 0.92, 0.65, 11.0, 5.6),
      (false, 0.30, 0.30, 14.0, 0.3),
    ];

    for (final (isRed, xRel, yRel, r, p) in items) {
      final bobY = math.sin(phase + p * 0.5) * (r * 0.15);
      final x = w * xRel;
      final y = h * yRel + bobY;
      canvas.drawCircle(Offset(x, y), r, isRed ? redPaint : yellowPaint);
    }
  }
}
