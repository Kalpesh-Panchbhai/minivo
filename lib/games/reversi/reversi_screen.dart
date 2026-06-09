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
import 'reversi_stats.dart';
import 'reversi_tutorial.dart';
import '../shared/generic_game_result_screen.dart' as game_result;

const int _kN = 8;

const Color _kBlackDisc = Color(0xFF1A1A1A);
const Color _kWhiteDisc = Color(0xFFF5F5F5);
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

class _ReversiScreenState extends State<ReversiScreen> {
  _Mode? _mode;
  _Difficulty _difficulty = _Difficulty.values[DifficultyKind.defaultIndex];

  late List<List<int>> _grid; // 0=empty, 1=black, 2=white
  int _currentPlayer = 1; // black goes first
  bool _gameOver = false;
  bool _aiThinking = false;
  List<List<int>> _validMoves = [];

  int _p1Wins = 0;
  int _p2Wins = 0;
  int _draws = 0;

  int _streak = 0;
  int? _streakOwner;
  bool _showStreakBadge = false;
  bool _wasNewBest = false;

  bool _isFavorite = false;
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
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
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
    });
    _resetBoard(notify: false);
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
      _grid = _initialGrid();
      _currentPlayer = 1;
      _gameOver = false;
      _aiThinking = false;
      _wasNewBest = false;
      _showStreakBadge = false;
      _validMoves = _getValidMoves(1);
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
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
      steps: reversiSteps(),
      gameId: _gameId,
    );
  }

  String _diffLabel(_Difficulty d) => ['EASY', 'MEDIUM', 'HARD'][d.index];

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
    if (_gameOver) return;
    if (_mode == _Mode.ai && (_aiThinking || _currentPlayer != 1)) return;
    if (!_validMoves.any((m) => m[0] == r && m[1] == c)) return;
    _makeMove(r, c);
  }

  void _makeMove(int r, int c) {
    final flips = _wouldFlip(r, c, _currentPlayer);
    setState(() {
      _grid[r][c] = _currentPlayer;
      for (final f in flips) {
        _grid[f[0]][f[1]] = _currentPlayer;
      }
    });
    _audio.playTap();

    final opponent = _currentPlayer == 1 ? 2 : 1;
    final oppMoves = _getValidMoves(opponent);
    if (oppMoves.isNotEmpty) {
      setState(() {
        _currentPlayer = opponent;
        _validMoves = oppMoves;
      });
    } else {
      final myMoves = _getValidMoves(_currentPlayer);
      if (myMoves.isNotEmpty) {
        setState(() => _validMoves = myMoves);
      } else {
        _endRound();
        return;
      }
    }

    _updateScore();

    if (_mode == _Mode.ai && _currentPlayer == 2 && !_gameOver) {
      _scheduleAiMove();
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

    setState(() {
      _gameOver = true;
      _validMoves = [];
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _wrapper.endGame();
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
                gameName: 'Reversi',
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
                color: _kWhiteDisc,
                isActive: _currentPlayer == 2 && !_gameOver,
                isThinking: _aiThinking,
                avatarIcon: _mode == _Mode.ai ? Icons.smart_toy_rounded : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _DiscCount(color: _kBlackDisc, count: black),
                  const SizedBox(width: 16),
                  const Text('—', style: TextStyle(color: Color(0xFF666666), fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 16),
                  _DiscCount(color: _kWhiteDisc, count: white),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _BoardWidget(
                    grid: _grid,
                    validMoves: _validMoves,
                    showHints: !_aiThinking && !_gameOver,
                    onCellTap: _onCellTap,
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
                color: _kBlackDisc,
                isActive: _currentPlayer == 1 && !_gameOver,
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

  const _BoardWidget({
    required this.grid,
    required this.validMoves,
    required this.showHints,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final maxSide = math.min(c.maxWidth, c.maxHeight);
      final cell = maxSide / _kN;
      final side = cell * _kN;

      return SizedBox(
        width: side,
        height: side,
        child: Container(
          decoration: BoxDecoration(
            color: _kBoardGreen,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: _kBoardGreen.withValues(alpha: 0.30),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              CustomPaint(
                size: Size.square(side),
                painter: _GridPainter(),
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
                        child: _CellContent(
                          value: grid[r][col],
                          isValid: showHints &&
                              validMoves.any((m) => m[0] == r && m[1] == col),
                          radius: cell * 0.40,
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      );
    });
  }
}

class _CellContent extends StatelessWidget {
  final int value;
  final bool isValid;
  final double radius;

  const _CellContent({
    required this.value,
    required this.isValid,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    if (value == 0 && isValid) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
      );
    }
    if (value == 0) return const SizedBox.shrink();

    final color = value == 1 ? _kBlackDisc : _kWhiteDisc;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Align(
        alignment: const Alignment(-0.3, -0.3),
        child: Container(
          width: radius * 0.28,
          height: radius * 0.28,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: value == 1 ? 0.20 : 0.45),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _kN;
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (int i = 1; i < _kN; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), paint);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

// ════════════════════════════════════════════════════════════════
// HUD WIDGETS
// ════════════════════════════════════════════════════════════════

class _DiscCount extends StatelessWidget {
  final Color color;
  final int count;
  const _DiscCount({required this.color, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade400, width: 1),
          ),
        ),
        const SizedBox(width: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
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
          child: Row(
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
