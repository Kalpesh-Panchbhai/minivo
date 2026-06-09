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
import 'connect_four_stats.dart';
import 'connect_four_tutorial.dart';
import '../shared/generic_game_result_screen.dart' as game_result;

const int _kRows = 6;
const int _kCols = 7;

const Color _kP1Color = Color(0xFFE85D75);
const Color _kP2Color = Color(0xFFF5C542);
const Color _kDrawColor = Color(0xFFB6A5DD);
const Color _kBoardColor = Color(0xFF3366CC);
const Color _kBoardDark = Color(0xFF1A3A7A);
const Color _kAccent = Color(0xFF3366CC);

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

  int _p1Wins = 0;
  int _p2Wins = 0;
  int _draws = 0;

  int _streak = 0;
  int? _streakOwner;
  bool _showStreakBadge = false;
  bool _wasNewBest = false;

  int _starter = 1;
  bool _firstRound = true;

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
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    _endTimer?.cancel();
    _winCtrl.dispose();
    super.dispose();
  }

  GameWrapperState get _wrapper => GameWrapper.of(context);

  static List<List<int>> _emptyGrid() =>
      List.generate(_kRows, (_) => List.filled(_kCols, 0));

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
      _winCtrl.value = 0;
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
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
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
  // GAMEPLAY
  // ════════════════════════════════════════════════════════════════

  int? _dropRow(int col) {
    for (int r = _kRows - 1; r >= 0; r--) {
      if (_grid[r][col] == 0) return r;
    }
    return null;
  }

  void _onColumnTap(int col) {
    if (_gameOver) return;
    if (_mode == _Mode.ai && (_aiThinking || _currentPlayer != 1)) return;
    final row = _dropRow(col);
    if (row == null) return;
    _placePiece(row, col);
  }

  void _placePiece(int row, int col) {
    setState(() => _grid[row][col] = _currentPlayer);
    _audio.playTap();

    final win = _checkWin(_currentPlayer);
    if (win != null) {
      _onWin(win, _currentPlayer);
      return;
    }
    if (_isBoardFull()) {
      _onDraw();
      return;
    }
    setState(() => _currentPlayer = _currentPlayer == 1 ? 2 : 1);
    if (_mode == _Mode.ai && _currentPlayer == 2) {
      _scheduleAiMove();
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
      setState(() => _aiThinking = false);
      _placePiece(row, col);
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

    _winCtrl.forward(from: 0);
    _audio.playSuccess();
    _endTimer?.cancel();
    _endTimer = Timer(const Duration(milliseconds: 1700), () {
      if (mounted) _wrapper.endGame();
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
      if (mounted) _wrapper.endGame();
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
    final isP1Turn = _currentPlayer == 1;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kBgTop, _kBgBot],
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
            if (_showStreakBadge)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _StreakChip(streak: _streak),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PlayerStrip(
                label: _mode == _Mode.ai ? 'AI' : 'P2',
                mark: '●',
                color: _kP2Color,
                isActive: _currentPlayer == 2 && !_gameOver,
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
            const SizedBox(height: 12),
          ],
        ),
      ),
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

  const _BoardWidget({
    required this.grid,
    required this.winCells,
    required this.winCtrl,
    required this.onColumnTap,
    required this.currentPlayer,
    required this.gameOver,
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

      return SizedBox(
        width: boardW,
        height: boardH,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: _kBoardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _kBoardColor.withValues(alpha: 0.30),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
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
                      radius: cell * 0.38,
                    ),
                  ),
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
    Color color;
    if (value == 0) {
      color = _kBoardDark;
    } else if (value == 1) {
      color = _kP1Color;
    } else {
      color = _kP2Color;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: isWin
            ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.70),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: value != 0
          ? Align(
              alignment: const Alignment(-0.3, -0.3),
              child: Container(
                width: radius * 0.35,
                height: radius * 0.35,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.40),
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
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
          child: Row(
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
        ),
      ],
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
