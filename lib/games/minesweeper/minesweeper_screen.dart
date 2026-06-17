import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/ads_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../game_registry.dart';
import '../game_wrapper.dart';
import '../game_picker_scaffold.dart';
import '../shared/animated_background.dart';
import '../shared/animated_difficulty_icon.dart';
import '../shared/game_control_buttons.dart';
import '../shared/game_difficulty_picker.dart';
import '../shared/game_hud_bar.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/rewarded_continue_action.dart';
import 'minesweeper_logo.dart';
import 'minesweeper_tutorial.dart';

const kMinesweeperGameId = 'minesweeper';

const _kBgTop = Color(0xFFF0F4FF);
const _kBgBottom = Color(0xFFE8ECF8);
const _kAccent = Color(0xFF4A7CFF);

const _kEasyColor = Color(0xFF22C55E);
const _kMediumColor = Color(0xFFF59E0B);
const _kHardColor = Color(0xFFEF4444);

enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label => ['EASY', 'MEDIUM', 'HARD'][index];
  Color get color => [_kEasyColor, _kMediumColor, _kHardColor][index];
  DifficultyKind get kind => [DifficultyKind.easy, DifficultyKind.medium, DifficultyKind.hard][index];
  String get hint => ['9×9 grid, 10 mines', '16×16 grid, 40 mines', '16×30 grid, 99 mines'][index];
  String get subKey => ['easy', 'medium', 'hard'][index];
  int get rows => [9, 16, 16][index];
  int get cols => [9, 16, 30][index];
  int get mines => [10, 40, 99][index];
}

enum _CellState { hidden, revealed, flagged }

class _Cell {
  bool isMine;
  _CellState state;
  int adjacentMines;

  _Cell({this.isMine = false, this.state = _CellState.hidden, this.adjacentMines = 0});
}

class MinesweeperScreen extends StatefulWidget {
  const MinesweeperScreen({super.key});

  @override
  State<MinesweeperScreen> createState() => _MinesweeperScreenState();
}

class _MinesweeperScreenState extends State<MinesweeperScreen> {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.values[DifficultyKind.defaultIndex];
  bool _isFavorite = false;

  List<List<_Cell>> _grid = [];
  bool _gameOver = false;
  bool _won = false;
  bool _firstTap = true;
  int _flagCount = 0;
  int _revealedCount = 0;
  int _score = 0;
  int _bestScore = 0;
  bool _isNewBest = false;

  Timer? _ticker;
  final Stopwatch _stopwatch = Stopwatch();
  int _elapsedSeconds = 0;

  int _hintsUsed = 0;
  static const _kMaxHints = 2;
  Timer? _idleTimer;
  bool _idleStuck = false;
  static const _kIdleTimeout = Duration(seconds: 15);

  bool _flagMode = false;

  bool _showingBlast = false;
  int _hitRow = -1;
  int _hitCol = -1;
  Timer? _blastTimer;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kMinesweeperGameId);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _blastTimer?.cancel();
    _idleTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kMinesweeperGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kMinesweeperGameId);
    if (info == null) return;
    showHowToPlaySheet(context, title: info.name, howToPlay: info.howToPlay,
      accent: _kAccent, steps: minesweeperSteps(), gameId: kMinesweeperGameId);
  }

  void _startGame(_Difficulty diff) {
    final rows = diff.rows;
    final cols = diff.cols;
    _grid = List.generate(rows, (_) => List.generate(cols, (_) => _Cell()));
    _gameOver = false;
    _won = false;
    _firstTap = true;
    _flagCount = 0;
    _revealedCount = 0;
    _score = 0;
    _bestScore = ScoreService().getHighScore(kMinesweeperGameId, subKey: diff.subKey);
    _isNewBest = false;
    _elapsedSeconds = 0;
    _flagMode = false;
    _idleStuck = false;
    _hintsUsed = 0;
    _showingBlast = false;
    _hitRow = -1;
    _hitCol = -1;
    _blastTimer?.cancel();
    _ticker?.cancel();
    _stopwatch.reset();

    setState(() {
      _activeDifficulty = diff;
    });

    _startTimer();

    if (mounted) {
      GameWrapper.of(context).setDifficultyAndMode(difficulty: diff.label, subKey: diff.subKey);
      GameWrapper.of(context).startGame();
      GameWrapper.of(context).updateScore(0);
    }
  }

  void _onHint() {
    if (_gameOver || _firstTap || _activeDifficulty == null) return;
    if (_hintsUsed >= _kMaxHints) return;
    if (!AdsService().isRewardedReady) return;
    AudioService().playTap();
    bool earned = false;
    AdsService().showRewarded(
      rewardType: RewardType.hint,
      gameId: kMinesweeperGameId,
      onRewarded: (_) => earned = true,
      onComplete: () {
        if (!earned || !mounted) return;
        _idleStuck = false;
        _hintsUsed++;
        _resetIdleTimer();
        final diff = _activeDifficulty!;
        final safeCells = <List<int>>[];
        for (int r = 0; r < diff.rows; r++) {
          for (int c = 0; c < diff.cols; c++) {
            final cell = _grid[r][c];
            if (!cell.isMine && cell.state == _CellState.hidden) {
              safeCells.add([r, c]);
            }
          }
        }
        if (safeCells.isEmpty) return;
        final pick = safeCells[math.Random().nextInt(safeCells.length)];
        _reveal(pick[0], pick[1], diff);
        _score = _revealedCount;
        AudioService().playScore();
        GameWrapper.of(context).updateScore(_score);
        _checkWin(diff);
        setState(() {});
      },
    );
  }

  void _newGame() => _startGame(_activeDifficulty ?? _pickerDifficulty);

  void _backToPicker() {
    _ticker?.cancel();
    _blastTimer?.cancel();
    _idleTimer?.cancel();
    _stopwatch.stop();
    setState(() {
      _activeDifficulty = null;
      _gameOver = false;
    });
    GameWrapper.of(context).restartGame();
  }

  void _backOrHome() {
    final wrapper = GameWrapper.of(context);
    wrapper.handleExit(() {
      _ticker?.cancel();
      _blastTimer?.cancel();
      _idleTimer?.cancel();
      _stopwatch.stop();
      if (context.canPop()) context.pop(); else context.go('/home');
    });
  }

  void _placeMines(_Difficulty diff, int safeRow, int safeCol) {
    final rng = math.Random();
    final rows = diff.rows;
    final cols = diff.cols;
    int placed = 0;
    while (placed < diff.mines) {
      final r = rng.nextInt(rows);
      final c = rng.nextInt(cols);
      if (_grid[r][c].isMine) continue;
      if ((r - safeRow).abs() <= 1 && (c - safeCol).abs() <= 1) continue;
      _grid[r][c].isMine = true;
      placed++;
    }
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (_grid[r][c].isMine) continue;
        int count = 0;
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            final nr = r + dr, nc = c + dc;
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && _grid[nr][nc].isMine) count++;
          }
        }
        _grid[r][c].adjacentMines = count;
      }
    }
  }

  void _startTimer() {
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
    });
    _resetIdleTimer();
  }

  bool get _isStuck => _idleStuck;

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_idleStuck) setState(() => _idleStuck = false);
    _idleTimer = Timer(_kIdleTimeout, () {
      if (mounted && _activeDifficulty != null && !_gameOver) {
        setState(() => _idleStuck = true);
      }
    });
  }

  void _onCellTap(int row, int col) {
    if (_gameOver || _showingBlast) return;
    final diff = _activeDifficulty!;
    final cell = _grid[row][col];

    if (_flagMode) {
      _onCellLongPress(row, col);
      return;
    }

    if (cell.state == _CellState.flagged || cell.state == _CellState.revealed) return;
    _resetIdleTimer();

    if (_firstTap) {
      _firstTap = false;
      _placeMines(diff, row, col);
    }

    if (cell.isMine) {
      AudioService().playGameOver();
      cell.state = _CellState.revealed;
      _ticker?.cancel();
      _stopwatch.stop();
      _won = false;
      _hitRow = row;
      _hitCol = col;
      _showingBlast = true;
      setState(() {});
      _startBlastSequence(diff);
      return;
    }

    _reveal(row, col, diff);
    _score = _revealedCount;
    AudioService().playScore();
    GameWrapper.of(context).updateScore(_score);
    _checkWin(diff);
    setState(() {});
  }

  void _onCellLongPress(int row, int col) {
    if (_gameOver || _showingBlast || _firstTap) return;
    final cell = _grid[row][col];
    if (cell.state == _CellState.revealed) return;
    _resetIdleTimer();

    setState(() {
      if (cell.state == _CellState.flagged) {
        cell.state = _CellState.hidden;
        _flagCount--;
      } else {
        cell.state = _CellState.flagged;
        _flagCount++;
      }
    });
    AudioService().playTap();
  }

  void _reveal(int row, int col, _Difficulty diff) {
    if (row < 0 || row >= diff.rows || col < 0 || col >= diff.cols) return;
    final cell = _grid[row][col];
    if (cell.state != _CellState.hidden || cell.isMine) return;

    cell.state = _CellState.revealed;
    _revealedCount++;

    if (cell.adjacentMines == 0) {
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          _reveal(row + dr, col + dc, diff);
        }
      }
    }
  }

  void _checkWin(_Difficulty diff) {
    final totalSafe = diff.rows * diff.cols - diff.mines;
    if (_revealedCount >= totalSafe) {
      _gameOver = true;
      _won = true;
      _ticker?.cancel();
      _stopwatch.stop();
      _calculateScore(diff);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) GameWrapper.of(context).endGame(result: 'win');
      });
    }
  }

  void _startBlastSequence(_Difficulty diff) {
    for (int r = 0; r < diff.rows; r++) {
      for (int c = 0; c < diff.cols; c++) {
        if (_grid[r][c].isMine) {
          _grid[r][c].state = _CellState.revealed;
        }
      }
    }
    setState(() {});

    _blastTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _calculateScore(diff);
      setState(() {
        _showingBlast = false;
        _gameOver = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) GameWrapper.of(context).endGame(result: 'loss');
      });
    });
  }

  void _calculateScore(_Difficulty diff) {
    if (_won) {
      final baseScore = diff.mines * 10;
      final timeBonus = math.max(0, 300 - _elapsedSeconds);
      _score = baseScore + timeBonus;
    } else {
      _score = _revealedCount;
    }
    _isNewBest = _score > _bestScore;
    if (_isNewBest) {
      _bestScore = _score;
      ScoreService().saveScore(kMinesweeperGameId, _score, subKey: diff.subKey);
    }
    GameWrapper.of(context).updateScore(_score);
  }

  void _continueGame() {
    if (_activeDifficulty == null) return;
    final diff = _activeDifficulty!;
    for (int r = 0; r < diff.rows; r++) {
      for (int c = 0; c < diff.cols; c++) {
        if (_grid[r][c].isMine && _grid[r][c].state == _CellState.revealed) {
          _grid[r][c].state = _CellState.hidden;
        }
      }
    }
    setState(() {
      _gameOver = false;
      _won = false;
      _showingBlast = false;
      _hitRow = -1;
      _hitCol = -1;
    });
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
    });
    GameWrapper.of(context).continueAfterGameOver();
  }

  @override
  Widget build(BuildContext context) {
    if (_activeDifficulty == null) return _buildPicker();
    if (_gameOver && !_showingBlast) return _buildResult();
    return _buildGame();
  }

  Widget _buildPicker() {
    final difficulties = _Difficulty.values.map((d) => GameDifficultyData(
      label: d.label,
      color: d.color,
      kind: d.kind,
      hint: d.hint,
      bestScore: ScoreService().getHighScore(kMinesweeperGameId, subKey: d.subKey),
      bestLabel: (s) => 'Best: $s pts',
    )).toList();

    return GamePickerScaffold(
      bgColorTop: _kBgTop,
      bgColorBottom: _kBgBottom,
      animatedBg: AnimatedBackground(
        factory: (t) => GenericAnimatedBgPainter(t, accent: _kAccent, icon: Icons.grid_view_rounded),
      ),
      iconRingColors: const [_kAccent, Color(0xFF7C9FFF), Color(0xFF2A5CCC)],
      iconChild: buildMinesweeperLogo(60),
      title: 'Minesweeper',
      subtitle: 'Clear the board — avoid the mines!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kMinesweeperGameId,
      body: GameSinglePickerBody(
        difficulties: difficulties,
        activeIndex: _pickerDifficulty.index,
        onChanged: (i) => setState(() => _pickerDifficulty = _Difficulty.values[i]),
        playLabel: 'Play Minesweeper',
        playSubLabel: 'Sweep the field!',
        onPlay: () => _startGame(_pickerDifficulty),
        accentColor: _kAccent,
      ),
    );
  }

  Widget _buildGame() {
    final diff = _activeDifficulty!;
    final rows = diff.rows;
    final cols = diff.cols;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF5F7FF), Color(0xFFE8ECF8)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 4),
            GameHudBar(
              leading: GameBackButton(onTap: _backOrHome),
              centerContent: _MinesweeperScorePill(
                difficulty: diff,
                score: _score,
                best: _bestScore,
                time: _formatTime(_elapsedSeconds),
                minesLeft: diff.mines - _flagCount,
              ),
              trailing: GameRestartButton(
                gameName: 'Minesweeper',
                accentColor: diff.color,
                onRestart: _newGame,
                onDialogOpened: () { _ticker?.cancel(); _stopwatch.stop(); },
                onDialogDismissed: () {
                  if (!_gameOver && !_firstTap) {
                    _stopwatch.start();
                    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
                      if (mounted) setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildGrid(rows, cols)),
            if (!_gameOver && !_showingBlast)
              Opacity(
                opacity: AdsService().isRewardedReady && _hintsUsed < _kMaxHints ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !AdsService().isRewardedReady || _hintsUsed >= _kMaxHints,
                  child: _MinesweeperHintNudge(onTap: _onHint, isStuck: _isStuck),
                ),
              ),
            _buildModeToggle(diff),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle(_Difficulty diff) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: diff.color.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _modeButton(
              icon: Icons.touch_app_rounded,
              label: 'Dig',
              isActive: !_flagMode,
              activeColor: diff.color,
              onTap: () => setState(() => _flagMode = false),
            ),
            const SizedBox(width: 4),
            _modeButton(
              icon: Icons.flag_rounded,
              label: 'Flag',
              isActive: _flagMode,
              activeColor: const Color(0xFFEF4444),
              onTap: () => setState(() => _flagMode = true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isActive ? Colors.white : const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(int rows, int cols) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth - 16;
        final maxH = constraints.maxHeight - 8;
        final cellSize = math.min(maxW / cols, maxH / rows).clamp(18.0, 44.0);
        final gridW = cellSize * cols;
        final gridH = cellSize * rows;
        final radius = BorderRadius.circular(12);

        return Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: Container(
                width: gridW + 4,
                height: gridH + 4,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFFB8C4D0),
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A7CFF).withValues(alpha: 0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Column(
                    children: List.generate(rows, (r) => Row(
                      children: List.generate(cols, (c) => _buildCell(r, c, cellSize)),
                    )),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell(int row, int col, double size) {
    final cell = _grid[row][col];
    final isEvenCell = (row + col) % 2 == 0;

    if (cell.state == _CellState.revealed) {
      if (cell.isMine) {
        final isHitMine = row == _hitRow && col == _hitCol;
        return GestureDetector(
          onTap: () => _onCellTap(row, col),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isHitMine
                    ? [const Color(0xFFFF2020), const Color(0xFFCC0000)]
                    : [const Color(0xFFFF6B6B), const Color(0xFFEF4444)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: isHitMine ? const Color(0xFFFF4444) : const Color(0xFFFF8A8A),
                width: isHitMine ? 1.5 : 0.5,
              ),
              boxShadow: isHitMine && _showingBlast
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF0000).withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Icon(
              isHitMine ? Icons.flash_on_rounded : Icons.brightness_7_rounded,
              size: isHitMine ? size * 0.58 : size * 0.52,
              color: isHitMine ? const Color(0xFFFFEB3B) : Colors.white,
            ),
          ),
        );
      }
      final revealedColor = isEvenCell ? const Color(0xFFE8ECF2) : const Color(0xFFDEE3EB);
      return GestureDetector(
        onTap: () => _onCellTap(row, col),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: revealedColor,
            border: Border.all(color: const Color(0xFFD0D7E0), width: 0.3),
          ),
          alignment: Alignment.center,
          child: cell.adjacentMines > 0
              ? Text(
                  '${cell.adjacentMines}',
                  style: TextStyle(
                    fontSize: size * 0.50,
                    fontWeight: FontWeight.w900,
                    color: _numberColor(cell.adjacentMines),
                  ),
                )
              : null,
        ),
      );
    }

    if (cell.state == _CellState.flagged) {
      return GestureDetector(
        onTap: () => _onCellTap(row, col),
        onLongPress: () => _onCellLongPress(row, col),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isEvenCell
                  ? [const Color(0xFFA8C4E0), const Color(0xFF96B4D0)]
                  : [const Color(0xFF9EBCD8), const Color(0xFF8CACC8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFB8D0E8), width: 0.5),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.flag_rounded, size: size * 0.48, color: const Color(0xFFEF4444)),
        ),
      );
    }

    final hiddenLight = isEvenCell ? const Color(0xFFA8C4E0) : const Color(0xFF9EBCD8);
    final hiddenDark = isEvenCell ? const Color(0xFF96B4D0) : const Color(0xFF8CACC8);
    final showMine = _gameOver && cell.isMine;

    return GestureDetector(
      onTap: () => _onCellTap(row, col),
      onLongPress: () => _onCellLongPress(row, col),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: showMine
                ? [const Color(0xFFFFCDD2), const Color(0xFFFFB3B8)]
                : [hiddenLight, hiddenDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: showMine ? const Color(0xFFFF8A8A) : const Color(0xFFB8D0E8),
            width: 0.5,
          ),
        ),
        alignment: Alignment.center,
        child: showMine
            ? Icon(Icons.brightness_7_rounded, size: size * 0.48, color: const Color(0xFFEF4444))
            : null,
      ),
    );
  }

  Color _numberColor(int n) {
    const colors = [
      Color(0xFF2196F3),
      Color(0xFF4CAF50),
      Color(0xFFF44336),
      Color(0xFF9C27B0),
      Color(0xFFFF9800),
      Color(0xFF00BCD4),
      Color(0xFF795548),
      Color(0xFF607D8B),
    ];
    return colors[(n - 1).clamp(0, colors.length - 1)];
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildResult() {
    final diff = _activeDifficulty!;
    final continueAction = _won ? null : rewardedContinueAction(
      context: context,
      label: 'Watch Ad to Continue',
      color: diff.color,
      onRewarded: _continueGame,
    );

    return game_result.GenericGameResultScreen(
      headline: _won ? 'Cleared!' : 'Game Over',
      subtitle: _won ? 'All mines found in ${_formatTime(_elapsedSeconds)}' : 'You hit a mine!',
      badgeContent: _won ? '💣' : '💥',
      badgeColor: diff.color,
      showNewBestBadge: _isNewBest,
      gameId: kMinesweeperGameId,
      score: _score,
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(label: 'SCORE', value: _score, color: diff.color),
          game_result.StatItem(label: 'TIME', value: _elapsedSeconds, displayValue: _formatTime(_elapsedSeconds), color: const Color(0xFF6B7280)),
          game_result.StatItem(label: 'BEST', value: _bestScore, color: const Color(0xFFFEC84B)),
        ],
      ),
      actions: [
        ?continueAction,
        game_result.GameResultAction(
          label: 'Play Again',
          icon: Icons.refresh_rounded,
          onTap: _newGame,
          filled: continueAction == null,
          color: diff.color,
          actionId: 'play_again',
        ),
        game_result.GameResultAction(
          label: 'Change Difficulty',
          icon: Icons.tune_rounded,
          onTap: _backToPicker,
          filled: false,
          actionId: 'change_mode',
        ),
        game_result.GameResultAction(
          label: 'Home',
          icon: Icons.home_rounded,
          onTap: () => context.go('/home'),
          actionId: 'home',
          filled: false,
        ),
      ],
    );
  }
}

class _MinesweeperScorePill extends StatelessWidget {
  final _Difficulty difficulty;
  final int score;
  final int best;
  final String time;
  final int minesLeft;

  const _MinesweeperScorePill({
    required this.difficulty,
    required this.score,
    required this.best,
    required this.time,
    required this.minesLeft,
  });

  @override
  Widget build(BuildContext context) {
    final color = difficulty.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.30),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDifficultyIcon(
                kind: difficulty.kind,
                size: 14,
                prominent: false,
              ),
              const SizedBox(width: 6),
              Text(
                difficulty.label,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              _statCol('SCORE', '$score', color),
              _divider(),
              _statCol('TIME', time, const Color(0xFF6B7280)),
              _divider(),
              _statCol('💣', '$minesLeft', const Color(0xFFEF4444)),
              _divider(),
              _statCol('BEST', '$best', const Color(0xFFF59E0B)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCol(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.85),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
    );
  }
}

class _MinesweeperHintNudge extends StatefulWidget {
  final VoidCallback onTap;
  final bool isStuck;
  const _MinesweeperHintNudge({required this.onTap, required this.isStuck});
  @override
  State<_MinesweeperHintNudge> createState() => _MinesweeperHintNudgeState();
}

class _MinesweeperHintNudgeState extends State<_MinesweeperHintNudge> with TickerProviderStateMixin {
  static const _kBg = Color(0xFFFFD43B);
  static const _kFg = Color(0xFF5C4600);

  late final AnimationController _pulseCtrl;
  late final AnimationController _slideCtrl;
  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);
    if (widget.isStuck) {
      _pulseCtrl.repeat(reverse: true);
      _slideCtrl.forward();
    }
  }

  @override
  void didUpdateWidget(_MinesweeperHintNudge old) {
    super.didUpdateWidget(old);
    if (widget.isStuck && !old.isStuck) {
      _pulseCtrl.repeat(reverse: true);
      _slideCtrl.forward();
    } else if (!widget.isStuck && old.isStuck) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
      _slideCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              final glow = widget.isStuck ? _pulseCtrl.value : 0.0;
              final scale = 1.0 + glow * 0.05;
              return Transform.scale(
                scale: scale,
                child: GestureDetector(
                  onTap: widget.onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE6BE00), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: _kBg.withValues(alpha: 0.30 + glow * 0.40),
                          blurRadius: 12 + glow * 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lightbulb_rounded, size: 16, color: _kFg),
                        const SizedBox(width: 6),
                        const Text(
                          'HINT',
                          style: TextStyle(
                            color: _kFg,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _kFg.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded, size: 12, color: _kFg),
                              SizedBox(width: 2),
                              Text(
                                'AD',
                                style: TextStyle(
                                  color: _kFg,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: 38,
            child: AnimatedBuilder(
              animation: _slideCtrl,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnim,
                  child: Transform.translate(
                    offset: Offset(0, (1 - _slideAnim.value.clamp(0.0, 1.0)) * 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _kAccent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: _kAccent.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Stuck? Try a hint!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        CustomPaint(
                          size: const Size(14, 7),
                          painter: _MSBubbleTailPainter(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MSBubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _kAccent;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
