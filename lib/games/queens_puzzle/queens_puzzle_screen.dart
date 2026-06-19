import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/ads_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/level_progress_service.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../game_registry.dart';
import '../game_wrapper.dart';
import '../game_picker_scaffold.dart';
import '../shared/animated_background.dart';
import '../shared/animated_difficulty_icon.dart';
import '../shared/game_control_buttons.dart';
import '../shared/game_difficulty_picker.dart';
import '../shared/continue_dialog.dart';
import '../shared/game_hud_bar.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/level_complete_overlay.dart';
import 'queens_puzzle_logo.dart';
import 'queens_puzzle_level_gen.dart' as gen;
import 'queens_puzzle_tutorial.dart';

const kQueensPuzzleGameId = 'queens_puzzle';

const _kAccent = Color(0xFF9B59B6);
const _kEasyColor = Color(0xFF22C55E);
const _kMediumColor = Color(0xFFF59E0B);
const _kHardColor = Color(0xFFEF4444);

const _regionColors = [
  Color(0xFFFF6B6B),
  Color(0xFF51CF66),
  Color(0xFF339AF0),
  Color(0xFFFFD43B),
  Color(0xFFCC5DE8),
  Color(0xFFFF922B),
  Color(0xFF20C997),
  Color(0xFFF06595),
];

enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label => ['EASY', 'MEDIUM', 'HARD'][index];
  Color get color => [_kEasyColor, _kMediumColor, _kHardColor][index];
  DifficultyKind get kind => [DifficultyKind.easy, DifficultyKind.medium, DifficultyKind.hard][index];
  String get hint => ['5×5 boards', '6×6 – 7×7 boards', '7×7 – 8×8 boards'][index];
  String get subKey => ['easy', 'medium', 'hard'][index];
}

class QueensPuzzleScreen extends StatefulWidget {
  const QueensPuzzleScreen({super.key});

  @override
  State<QueensPuzzleScreen> createState() => _QueensPuzzleScreenState();
}

class _QueensPuzzleScreenState extends State<QueensPuzzleScreen> with SingleTickerProviderStateMixin {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.values[DifficultyKind.defaultIndex];
  bool _isFavorite = false;

  int _level = 1;
  bool _gameOver = false;
  bool _won = false;

  int _boardSize = 5;
  List<int> _solutionCols = [];
  List<List<int>> _regions = [];
  List<int> _regionOf = [];

  List<int> _playerQueens = [];
  Set<int> _xMarkers = {};
  Set<int> _invalidCells = {};

  OverlayEntry? _appreciationOverlay;

  int _hintsUsed = 0;
  static const _kMaxHints = 3;
  Timer? _idleTimer;
  bool _idleStuck = false;
  static const _kIdleTimeout = Duration(seconds: 8);

  late final AnimationController _winAnim;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kQueensPuzzleGameId);
    _winAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  }

  @override
  void dispose() {
    _appreciationOverlay?.remove();
    _appreciationOverlay = null;
    _idleTimer?.cancel();
    _winAnim.dispose();
    super.dispose();
  }

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kQueensPuzzleGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kQueensPuzzleGameId);
    if (info == null) return;
    showHowToPlaySheet(context, title: info.name, howToPlay: info.howToPlay,
      accent: _kAccent, steps: queensPuzzleSteps(), gameId: kQueensPuzzleGameId);
  }

  void _startGame(_Difficulty diff) async {
    final lps = LevelProgressService();
    _level = lps.getCurrentLevel(kQueensPuzzleGameId, diff.subKey);

    final saved = lps.getGameState(kQueensPuzzleGameId, diff.subKey);
    final hasSave = saved != null && saved['level'] == _level;

    bool shouldContinue = false;
    if (hasSave) {
      shouldContinue = await showContinueDialog(
        context,
        gameName: 'Queens Puzzle',
        accentColor: diff.color,
        level: _level,
      );
      if (!mounted) return;
    }

    _gameOver = false;
    _won = false;
    _hintsUsed = 0;
    _generateLevel(diff);

    if (hasSave && shouldContinue) {
      _playerQueens = List<int>.from(saved['queens'] as List);
      _xMarkers = Set<int>.from((saved['xMarkers'] as List).cast<int>());
      _hintsUsed = (saved['hintsUsed'] as int?) ?? 0;
      _invalidCells.clear();
      _validateBoard();
    } else {
      if (hasSave) lps.clearGameState(kQueensPuzzleGameId, diff.subKey);
      _playerQueens = List<int>.filled(_boardSize, -1);
      _xMarkers = {};
      _invalidCells = {};
    }

    _resetIdleTimer();
    setState(() => _activeDifficulty = diff);
    GameWrapper.of(context).setDifficultyAndMode(difficulty: diff.label, subKey: diff.subKey);
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _generateLevel(_Difficulty diff) {
    final result = gen.generateQueensPuzzleLevel(_level, diff.index);
    _boardSize = result.boardSize;
    _solutionCols = result.queenCols;
    _regions = result.regions;
    _regionOf = List<int>.filled(_boardSize * _boardSize, -1);
    for (int reg = 0; reg < _regions.length; reg++) {
      for (final idx in _regions[reg]) {
        _regionOf[idx] = reg;
      }
    }
    _playerQueens = List<int>.filled(_boardSize, -1);
    _xMarkers = {};
    _invalidCells = {};
  }

  void _onCellTap(int row, int col) {
    if (_gameOver || _won) return;
    _resetIdleTimer();
    final reg = _regionOf[row * _boardSize + col];
    if (reg < 0) return;

    if (_playerQueens[reg] == row * _boardSize + col) {
      setState(() {
        _playerQueens[reg] = -1;
        _invalidCells.clear();
        _validateBoard();
      });
      AudioService().playTap();
      _saveState();
      return;
    }

    if (_xMarkers.contains(row * _boardSize + col)) return;

    setState(() {
      _playerQueens[reg] = row * _boardSize + col;
      _invalidCells.clear();
      _validateBoard();
    });
    AudioService().playTap();
    _saveState();
    _checkWin();
  }

  void _onCellLongPress(int row, int col) {
    if (_gameOver || _won) return;
    _resetIdleTimer();
    final idx = row * _boardSize + col;
    final reg = _regionOf[idx];
    if (reg < 0) return;

    if (_playerQueens[reg] == idx) return;

    setState(() {
      if (_xMarkers.contains(idx)) {
        _xMarkers.remove(idx);
      } else {
        _xMarkers.add(idx);
      }
    });
    AudioService().playTap();
    _saveState();
  }

  void _validateBoard() {
    _invalidCells.clear();
    final n = _boardSize;
    final placedQueens = <int, int>{};

    for (int reg = 0; reg < n; reg++) {
      final qi = _playerQueens[reg];
      if (qi < 0) continue;
      placedQueens[reg] = qi;
    }

    final rowUsed = <int, List<int>>{};
    final colUsed = <int, List<int>>{};

    for (final entry in placedQueens.entries) {
      final qi = entry.value;
      final r = qi ~/ n, c = qi % n;
      rowUsed.putIfAbsent(r, () => []).add(qi);
      colUsed.putIfAbsent(c, () => []).add(qi);
    }

    for (final cells in rowUsed.values) {
      if (cells.length > 1) _invalidCells.addAll(cells);
    }
    for (final cells in colUsed.values) {
      if (cells.length > 1) _invalidCells.addAll(cells);
    }

    final allQueens = placedQueens.values.toList();
    for (int i = 0; i < allQueens.length; i++) {
      for (int j = i + 1; j < allQueens.length; j++) {
        final qi = allQueens[i], qj = allQueens[j];
        final ri = qi ~/ n, ci = qi % n;
        final rj = qj ~/ n, cj = qj % n;
        if ((ri - rj).abs() <= 1 && (ci - cj).abs() <= 1) {
          _invalidCells.add(qi);
          _invalidCells.add(qj);
        }
      }
    }
  }

  void _checkWin() {
    final n = _boardSize;
    if (_playerQueens.any((q) => q < 0)) return;
    if (_invalidCells.isNotEmpty) return;

    final rows = _playerQueens.map((q) => q ~/ n).toSet();
    final cols = _playerQueens.map((q) => q % n).toSet();
    if (rows.length != n || cols.length != n) return;

    _won = true;
    _winAnim.forward(from: 0);
    _endGame(true);
  }

  void _endGame(bool won) {
    _won = won;
    if (won) {
      final diff = _activeDifficulty!;
      final lps = LevelProgressService();
      lps.advanceLevel(kQueensPuzzleGameId, diff.subKey);
      lps.clearGameState(kQueensPuzzleGameId, diff.subKey);
      GameWrapper.of(context).updateScore(_level);
      AudioService().playScore();
      _showAppreciation();
      return;
    }
    _gameOver = true;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GameWrapper.of(context).endGame(result: 'loss');
    });
  }

  void _showAppreciation() {
    _appreciationOverlay?.remove();
    final diff = _activeDifficulty!;
    _appreciationOverlay = OverlayEntry(
      builder: (_) => LevelCompleteOverlay(
        level: _level,
        accentColor: diff.color,
        onComplete: () {
          _appreciationOverlay?.remove();
          _appreciationOverlay = null;
          if (!mounted) return;
          GameWrapper.of(context).completeLevelWithAd(
            onComplete: () {
              if (mounted) _nextLevel();
            },
          );
        },
      ),
    );
    Overlay.of(context).insert(_appreciationOverlay!);
  }

  void _nextLevel() {
    final diff = _activeDifficulty!;
    setState(() {
      _level++;
      _gameOver = false;
      _won = false;
      _hintsUsed = 0;
    });
    _generateLevel(diff);
    _resetIdleTimer();
    GameWrapper.of(context).restartGame();
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _restartLevel() {
    setState(() {
      _gameOver = false;
      _won = false;
      _hintsUsed = 0;
      _playerQueens = List<int>.filled(_boardSize, -1);
      _xMarkers = {};
      _invalidCells = {};
    });
    if (_activeDifficulty != null) {
      LevelProgressService().clearGameState(kQueensPuzzleGameId, _activeDifficulty!.subKey);
    }
    _resetIdleTimer();
    GameWrapper.of(context).restartGame();
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_idleStuck) setState(() => _idleStuck = false);
    _idleTimer = Timer(_kIdleTimeout, () {
      if (mounted && _activeDifficulty != null && !_gameOver && !_won) {
        setState(() => _idleStuck = true);
      }
    });
  }

  void _onHint() {
    if (_gameOver || _won) return;
    if (_hintsUsed >= _kMaxHints) return;
    if (!AdsService().isRewardedReady) {
      _applyHint();
      return;
    }
    AdsService().showRewarded(
      rewardType: RewardType.hint,
      gameId: kQueensPuzzleGameId,
      onRewarded: (_) {
        if (!mounted) return;
        _applyHint();
      },
    );
  }

  void _applyHint() {
    _hintsUsed++;
    _idleStuck = false;
    _resetIdleTimer();
    final n = _boardSize;

    for (int reg = 0; reg < n; reg++) {
      if (_playerQueens[reg] >= 0) continue;
      final correctCell = reg * n + _solutionCols[reg];
      final actualReg = _regionOf[correctCell];
      if (actualReg != reg) continue;
      setState(() {
        _playerQueens[reg] = correctCell;
        _xMarkers.remove(correctCell);
        _invalidCells.clear();
        _validateBoard();
      });
      AudioService().playTap();
      _saveState();
      _checkWin();
      return;
    }

    for (int reg = 0; reg < n; reg++) {
      if (_playerQueens[reg] >= 0) continue;
      for (final idx in _regions[reg]) {
        if (idx == reg * n + _solutionCols[reg]) {
          setState(() {
            _playerQueens[reg] = idx;
            _xMarkers.remove(idx);
            _invalidCells.clear();
            _validateBoard();
          });
          AudioService().playTap();
          _saveState();
          _checkWin();
          return;
        }
      }
    }
  }

  void _saveState() {
    final diff = _activeDifficulty;
    if (diff == null || _gameOver || _won) return;
    if (!_playerQueens.any((q) => q >= 0) && _xMarkers.isEmpty) return;
    LevelProgressService().saveGameState(kQueensPuzzleGameId, diff.subKey, {
      'level': _level,
      'queens': _playerQueens,
      'xMarkers': _xMarkers.toList(),
      'hintsUsed': _hintsUsed,
    });
  }

  void _backOrHome() {
    _saveState();
    final wrapper = GameWrapper.of(context);
    wrapper.handleExit(() {
      if (context.canPop()) context.pop(); else context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_activeDifficulty == null) return _buildPicker();
    if (_gameOver && !_won) return _buildResult();
    return _buildGame();
  }

  Widget _buildPicker() {
    final difficulties = _Difficulty.values.map((d) => GameDifficultyData(
      label: d.label,
      color: d.color,
      kind: d.kind,
      hint: d.hint,
      bestScore: LevelProgressService().getHighestLevel(kQueensPuzzleGameId, d.subKey),
      bestLabel: (s) {
        if (s <= 0) return '';
        return 'Completed: Level $s';
      },
    )).toList();

    return GamePickerScaffold(
      bgColorTop: const Color(0xFFF3E8FF),
      bgColorBottom: const Color(0xFFE9D5FF),
      animatedBg: AnimatedBackground(
        factory: (t) => GenericAnimatedBgPainter(t, accent: _kAccent, icon: Icons.auto_awesome_rounded),
      ),
      iconRingColors: const [_kAccent, Color(0xFFD4A0FF), Color(0xFF7C3AED)],
      iconChild: buildQueensPuzzleLogo(60),
      title: 'Queens',
      subtitle: 'Place queens without conflict!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kQueensPuzzleGameId,
      body: GameSinglePickerBody(
        difficulties: difficulties,
        activeIndex: _pickerDifficulty.index,
        onChanged: (i) => setState(() => _pickerDifficulty = _Difficulty.values[i]),
        playLabel: 'Play Queens',
        playSubLabel: 'Level ${LevelProgressService().getCurrentLevel(kQueensPuzzleGameId, _pickerDifficulty.subKey)}',
        onPlay: () => _startGame(_pickerDifficulty),
        accentColor: _kAccent,
      ),
    );
  }

  Widget _buildGame() {
    final diff = _activeDifficulty!;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8F4FF), Color(0xFFF0E6FF)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            GameHudBar(
              leading: GameBackButton(
                onTap: _backOrHome,
                bgColor: _kAccent.withValues(alpha: 0.12),
                iconColor: _kAccent,
              ),
              centerContent: _buildHud(diff),
              trailing: GameRestartButton(
                gameName: 'Queens',
                accentColor: diff.color,
                onRestart: _restartLevel,
                bgColor: _kAccent.withValues(alpha: 0.12),
                iconColor: _kAccent,
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(builder: (_, c) => _buildGrid(c)),
                ),
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: !_gameOver && !_won && _hintsUsed < _kMaxHints ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: _gameOver || _won || _hintsUsed >= _kMaxHints,
                child: _QueensHintNudge(onTap: _onHint, isStuck: _idleStuck),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHud(_Difficulty diff) {
    final clr = diff.color;
    final placed = _playerQueens.where((q) => q >= 0).length;
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: clr,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              boxShadow: [BoxShadow(color: clr.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedDifficultyIcon(kind: diff.kind, size: 14, prominent: false),
                const SizedBox(width: 6),
                Text(diff.label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: _kAccent.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _statCol('LEVEL', '$_level', clr),
                _pillDivider(),
                _statCol('QUEENS', '$placed/$_boardSize', const Color(0xFF6B7280)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String label, String value, Color c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: c.withValues(alpha: 0.70), letterSpacing: 1.0)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c, height: 1)),
        ]),
      );

  Widget _pillDivider() => Container(
        width: 1,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: const Color(0xFFE5E7EB),
      );

  Widget _buildGrid(BoxConstraints con) {
    final n = _boardSize;
    final maxSz = math.min(con.maxWidth, con.maxHeight - 16);
    const borderW = 3.0;
    final cellSz = ((maxSz - 2 * borderW) / n).floorToDouble();
    final gridSz = cellSz * n;

    return Container(
      width: gridSz + 2 * borderW,
      height: gridSz + 2 * borderW,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2D2D3F), width: borderW),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14 - borderW),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(n, (row) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(n, (col) {
                return _buildCell(row, col, cellSz);
              }),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col, double cellSz) {
    final n = _boardSize;
    final idx = row * n + col;
    final reg = _regionOf[idx];
    final regColor = reg >= 0 ? _regionColors[reg % _regionColors.length] : Colors.grey;
    final hasQueen = reg >= 0 && _playerQueens[reg] == idx;
    final hasX = _xMarkers.contains(idx);
    final isInvalid = _invalidCells.contains(idx);

    final borderSides = _computeBorderSides(row, col, reg);

    return GestureDetector(
      onTap: () => _onCellTap(row, col),
      onLongPress: () => _onCellLongPress(row, col),
      child: Container(
        width: cellSz,
        height: cellSz,
        decoration: BoxDecoration(
          color: hasQueen && isInvalid
              ? Colors.red.withValues(alpha: 0.35)
              : regColor.withValues(alpha: 0.45),
          border: Border(
            top: borderSides[0],
            right: borderSides[1],
            bottom: borderSides[2],
            left: borderSides[3],
          ),
        ),
        child: Center(
          child: hasQueen
              ? _buildQueen(cellSz, isInvalid, regColor)
              : hasX
                  ? _buildXMarker(cellSz)
                  : const SizedBox.shrink(),
        ),
      ),
    );
  }

  List<BorderSide> _computeBorderSides(int row, int col, int reg) {
    final n = _boardSize;
    const thin = BorderSide(color: Color(0xFF2D2D3F), width: 0.5);
    const thick = BorderSide(color: Color(0xFF2D2D3F), width: 1.5);

    BorderSide side(int r2, int c2) {
      if (r2 < 0 || r2 >= n || c2 < 0 || c2 >= n) return BorderSide.none;
      return _regionOf[r2 * n + c2] == reg ? thin : thick;
    }

    return [
      side(row - 1, col),
      side(row, col + 1),
      side(row + 1, col),
      side(row, col - 1),
    ];
  }

  Widget _buildQueen(double cellSz, bool isInvalid, Color regColor) {
    final size = cellSz * 0.58;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CrownPainter(isInvalid: isInvalid),
      ),
    );
  }

  Widget _buildXMarker(double cellSz) {
    final size = cellSz * 0.30;
    return Icon(Icons.close_rounded, size: size, color: Colors.grey.withValues(alpha: 0.50));
  }

  Widget _buildResult() {
    final diff = _activeDifficulty!;
    return game_result.GenericGameResultScreen(
      headline: _won ? 'Level $_level Complete!' : 'Stuck!',
      subtitle: _won ? 'All queens placed!' : 'Try again or restart',
      badgeContent: _won ? '👑' : '😔',
      badgeColor: diff.color,
      showNewBestBadge: false,
      gameId: kQueensPuzzleGameId,
      score: _level,
      statsWidget: game_result.GameResultStatsRow(stats: [
        game_result.StatItem(label: 'LEVEL', value: _level, color: diff.color),
        game_result.StatItem(label: 'BOARD', value: _boardSize, color: const Color(0xFF6B7280)),
      ]),
      actions: [
        if (_won)
          game_result.GameResultAction(label: 'Next Level', icon: Icons.arrow_forward_rounded, onTap: _nextLevel, filled: true, color: diff.color, actionId: 'play_again')
        else
          game_result.GameResultAction(label: 'Retry Level', icon: Icons.refresh_rounded, onTap: _restartLevel, filled: true, color: diff.color, actionId: 'play_again'),
        game_result.GameResultAction(
          label: 'Change Difficulty',
          icon: Icons.tune_rounded,
          onTap: () {
            setState(() { _activeDifficulty = null; _gameOver = false; });
            GameWrapper.of(context).restartGame();
          },
          filled: false,
          actionId: 'change_mode',
        ),
        game_result.GameResultAction(label: 'Home', icon: Icons.home_rounded, onTap: () => context.go('/home'), actionId: 'home', filled: false),
      ],
    );
  }
}

class _CrownPainter extends CustomPainter {
  final bool isInvalid;
  const _CrownPainter({required this.isInvalid});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final goldLight = isInvalid ? const Color(0xFFFF8A8A) : const Color(0xFFFFD43B);
    final goldMid = isInvalid ? const Color(0xFFEF4444) : const Color(0xFFE8A817);
    final goldDark = isInvalid ? const Color(0xFFCC0000) : const Color(0xFFB8860B);

    final body = Path()
      ..moveTo(w * 0.10, h * 0.82)
      ..lineTo(w * 0.10, h * 0.55)
      ..lineTo(w * 0.13, h * 0.20)
      ..lineTo(w * 0.33, h * 0.48)
      ..lineTo(w * 0.50, h * 0.10)
      ..lineTo(w * 0.67, h * 0.48)
      ..lineTo(w * 0.87, h * 0.20)
      ..lineTo(w * 0.90, h * 0.55)
      ..lineTo(w * 0.90, h * 0.82)
      ..close();

    final rect = body.getBounds();
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [goldLight, goldMid, goldDark],
    );
    canvas.drawPath(body, Paint()..shader = gradient.createShader(rect));

    canvas.drawPath(body, Paint()
      ..color = goldDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round);

    canvas.drawLine(
      Offset(w * 0.12, h * 0.68),
      Offset(w * 0.88, h * 0.68),
      Paint()..color = goldDark..strokeWidth = 1.0,
    );

    final dotR = w * 0.050;
    final dotFill = Paint()..color = goldMid;
    final dotBorder = Paint()
      ..color = goldDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (final c in [Offset(w * 0.50, h * 0.10), Offset(w * 0.13, h * 0.20), Offset(w * 0.87, h * 0.20)]) {
      canvas.drawCircle(c, dotR, dotFill);
      canvas.drawCircle(c, dotR, dotBorder);
    }
  }

  @override
  bool shouldRepaint(_CrownPainter old) => old.isInvalid != isInvalid;
}

class _QueensHintNudge extends StatelessWidget {
  final VoidCallback onTap;
  final bool isStuck;
  const _QueensHintNudge({required this.onTap, required this.isStuck});

  static const _kBg = Color(0xFFFFD43B);
  static const _kFg = Color(0xFF5C4600);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE6BE00), width: 1.5),
                boxShadow: [BoxShadow(color: _kBg.withValues(alpha: 0.30), blurRadius: 12, offset: const Offset(0, 3))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lightbulb_rounded, size: 16, color: _kFg),
                  const SizedBox(width: 6),
                  const Text('HINT', style: TextStyle(color: _kFg, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.0, height: 1)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: _kFg.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, size: 12, color: _kFg),
                        SizedBox(width: 2),
                        Text('AD', style: TextStyle(color: _kFg, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8, height: 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isStuck)
            Positioned(
              bottom: 40,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: const Text('Stuck? Try a hint!', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                  ),
                  CustomPaint(size: const Size(14, 7), painter: _BubbleTailPainter()),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF7C3AED));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
