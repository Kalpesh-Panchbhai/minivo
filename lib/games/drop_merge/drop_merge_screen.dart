import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/ads_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../game_picker_scaffold.dart';
import '../game_registry.dart';
import '../game_wrapper.dart';
import '../shared/animated_background.dart';
import '../shared/game_control_buttons.dart';
import '../shared/game_hud_bar.dart';
import '../shared/animated_difficulty_icon.dart';
import '../shared/game_difficulty_picker.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/rewarded_continue_action.dart';
import '../shared/rewarded_undo_button.dart';
import 'drop_merge_logo.dart';
import 'drop_merge_stats.dart';
import 'drop_merge_tutorial.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kAccent = Color(0xFFFF922B);
const _kBgTop  = Color(0xFFFFF9F0);
const _kBgBot  = Color(0xFFFFF0D9);

// ── Difficulty palette ────────────────────────────────────────────────────────
const Color _kEasyColor   = Color(0xFF4CB97A);
const Color _kMediumColor = Color(0xFFEFA63A);
const Color _kHardColor   = Color(0xFFE8533D);

// ── Enums ─────────────────────────────────────────────────────────────────────
enum _Difficulty { easy, medium, hard }

// ── Falling tile state ────────────────────────────────────────────────────────
class _FallingDrop {
  final int col, value, targetRow;
  final Duration duration;
  const _FallingDrop({required this.col, required this.value, required this.targetRow, required this.duration});
}

class _GravityMove {
  final int col, fromRow, toRow;
  const _GravityMove({required this.col, required this.fromRow, required this.toRow});
}

extension _DiffX on _Difficulty {
  String get label  => ['EASY', 'MEDIUM', 'HARD'][index];
  Color  get color  => [_kEasyColor, _kMediumColor, _kHardColor][index];
  String get subKey => ['easy', 'medium', 'hard'][index];
  String get hint   => [
    'Gentler tile pool — great for learning merges.',
    'Balanced pool with some high-value tiles.',
    'High-value tiles only — plan ahead!',
  ][index];
  DifficultyKind get kind => [
    DifficultyKind.easy,
    DifficultyKind.medium,
    DifficultyKind.hard,
  ][index];
}

// ── Tile pool ─────────────────────────────────────────────────────────────────
const _kEasyPool   = [2, 2, 2, 2, 2, 4, 4, 4, 8];
const _kMediumPool = [2, 2, 2, 4, 4, 4, 8, 8, 16];
const _kHardPool   = [2, 2, 4, 4, 8, 8, 16, 16, 32];

int _nextTile(_Difficulty diff, math.Random rng) {
  final pool = switch (diff) {
    _Difficulty.easy   => _kEasyPool,
    _Difficulty.medium => _kMediumPool,
    _Difficulty.hard   => _kHardPool,
  };
  return pool[rng.nextInt(pool.length)];
}

// ── Tile colors ───────────────────────────────────────────────────────────────
Color _tileColor(int v) {
  if (v <= 2)    return const Color(0xFFFFF3BF);
  if (v <= 4)    return const Color(0xFFFFE066);
  if (v <= 8)    return const Color(0xFFFFA94D);
  if (v <= 16)   return const Color(0xFFFF6B6B);
  if (v <= 32)   return const Color(0xFFE64980);
  if (v <= 64)   return const Color(0xFFCC5DE8);
  if (v <= 128)  return const Color(0xFF845EF7);
  if (v <= 256)  return const Color(0xFF5C7CFA);
  if (v <= 512)  return const Color(0xFF339AF0);
  return const Color(0xFF20C997);
}

Color _tileTextColor(int v) => v <= 4 ? Colors.black : Colors.white;

// Uniform font size across all tiles — shrinks only when digits need more room.
double _tileFontSize(int v) {
  final digits = v.toString().length;
  if (digits <= 2) return 20;
  if (digits == 3) return 17;
  if (digits == 4) return 14;
  if (digits == 5) return 11;
  return 9;
}

// ── Pure game logic ───────────────────────────────────────────────────────────

typedef _Grid = List<List<int>>;

_Grid _emptyGrid() => List.generate(4, (_) => List.filled(4, 0));
_Grid _copyGrid(_Grid g) => [for (final r in g) List<int>.from(r)];

(_Grid, int, int) _dropTile(_Grid grid, int col, int value) {
  int landingRow = -1;
  for (int r = 3; r >= 0; r--) {
    if (grid[r][col] == 0) {
      landingRow = r;
      break;
    }
  }

  if (landingRow >= 0) {
    final ng = _copyGrid(grid);
    ng[landingRow][col] = value;
    return (ng, landingRow, 0);
  }

  if (grid[0][col] == value) {
    final ng = _copyGrid(grid);
    ng[0][col] = value * 2;
    return (ng, 0, value * 2);
  }

  return (grid, -1, 0);
}

_Grid _applyGravity(_Grid grid) {
  final ng = _emptyGrid();
  for (int c = 0; c < 4; c++) {
    int fill = 3;
    for (int r = 3; r >= 0; r--) {
      if (grid[r][c] != 0) {
        ng[fill][c] = grid[r][c];
        fill--;
      }
    }
  }
  return ng;
}

({_Grid grid, Set<String> merged, Set<String> consumed, int score})
    _mergePass(_Grid grid, {int dropCol = -1}) {
  final ng = _copyGrid(grid);
  final merged   = <String>{};
  final consumed = <String>{};
  int score = 0;

  // Phase 1: vertical merges only (top→bottom scan).
  // Upper cell is consumed, lower cell keeps the doubled value.
  for (int r = 0; r < 3; r++) {
    for (int c = 0; c < 4; c++) {
      if (ng[r][c] == 0) continue;
      if (consumed.contains('$r,$c') || merged.contains('$r,$c')) continue;
      final val = ng[r][c];
      if (ng[r + 1][c] == val &&
          !consumed.contains('${r + 1},$c') &&
          !merged.contains('${r + 1},$c')) {
        score        += val * 2;
        ng[r + 1][c]  = val * 2;
        ng[r][c]      = 0;
        merged.add('${r + 1},$c');
        consumed.add('$r,$c');
      }
    }
  }

  // If any vertical merge happened, return now (horizontal is deferred).
  if (score > 0) return (grid: ng, merged: merged, consumed: consumed, score: score);

  // Phase 2: horizontal merges only (left→right scan).
  // The cell that is in `dropCol` (or the current cell when neither is dropCol)
  // keeps the doubled value; the neighbour is consumed.
  for (int r = 0; r < 4; r++) {
    for (int c = 0; c < 4; c++) {
      if (ng[r][c] == 0) continue;
      if (consumed.contains('$r,$c') || merged.contains('$r,$c')) continue;
      final val = ng[r][c];

      // Left neighbour
      if (c - 1 >= 0 &&
          ng[r][c - 1] == val &&
          !consumed.contains('$r,${c - 1}') &&
          !merged.contains('$r,${c - 1}')) {
        // Decide which column keeps the result: prefer dropCol, else current (c).
        final keepLeft = (c - 1 == dropCol);
        if (keepLeft) {
          ng[r][c - 1] = val * 2;
          ng[r][c]     = 0;
          merged.add('$r,${c - 1}');
          consumed.add('$r,$c');
        } else {
          ng[r][c]     = val * 2;
          ng[r][c - 1] = 0;
          merged.add('$r,$c');
          consumed.add('$r,${c - 1}');
        }
        score += val * 2;
        continue;
      }

      // Right neighbour
      if (c + 1 < 4 &&
          ng[r][c + 1] == val &&
          !consumed.contains('$r,${c + 1}') &&
          !merged.contains('$r,${c + 1}')) {
        // Decide which column keeps the result: prefer dropCol, else current (c).
        final keepRight = (c + 1 == dropCol);
        if (keepRight) {
          ng[r][c + 1] = val * 2;
          ng[r][c]     = 0;
          merged.add('$r,${c + 1}');
          consumed.add('$r,$c');
        } else {
          ng[r][c]     = val * 2;
          ng[r][c + 1] = 0;
          merged.add('$r,$c');
          consumed.add('$r,${c + 1}');
        }
        score += val * 2;
      }
    }
  }

  return (grid: ng, merged: merged, consumed: consumed, score: score);
}

List<_GravityMove> _computeGravityMoves(_Grid before, _Grid after) {
  final moves = <_GravityMove>[];
  for (int c = 0; c < 4; c++) {
    final beforeRows = <int>[];
    final afterRows  = <int>[];
    for (int r = 0; r < 4; r++) {
      if (before[r][c] != 0) beforeRows.add(r);
      if (after[r][c]  != 0) afterRows.add(r);
    }
    for (int i = 0; i < beforeRows.length && i < afterRows.length; i++) {
      if (beforeRows[i] != afterRows[i]) {
        moves.add(_GravityMove(col: c, fromRow: beforeRows[i], toRow: afterRows[i]));
      }
    }
  }
  return moves;
}

int _calcFinalScore(int mergeScore, int chains) {
  if (chains == 0) return mergeScore;
  final multiplier = 1.0 + (chains - 1) * 0.5;
  return (mergeScore * multiplier).round();
}

bool _isGameOver(_Grid grid, int nextVal) {
  for (int c = 0; c < 4; c++) {
    if (grid[0][c] == 0) return false;
  }
  for (int c = 0; c < 4; c++) {
    if (grid[0][c] == nextVal) return false;
  }
  return true;
}

// ════════════════════════════════════════════════════════════════════════════
// ROOT SCREEN
// ════════════════════════════════════════════════════════════════════════════

class DropMergeScreen extends StatefulWidget {
  const DropMergeScreen({super.key});

  @override
  State<DropMergeScreen> createState() => _DropMergeScreenState();
}

class _DropMergeScreenState extends State<DropMergeScreen> {
  _Difficulty _difficulty  = _Difficulty.values[DifficultyKind.defaultIndex];
  _Grid       _grid        = _emptyGrid();
  int         _score       = 0;
  int         _currentTile = 2;
  int         _chains      = 0;
  int         _dropCol     = -1;
  bool        _gameOver    = false;
  bool        _dropping    = false;
  bool        _isFavorite  = false;

  // Undo support (1 per game)
  bool  _undoUsed = false;
  bool  _inUndoWindow = false;
  _Grid? _prevGrid;
  int?   _prevScore;
  int?   _prevCurrentTile;

  // Continue support (1 per game)
  bool _continueUsed = false;

  Set<String>       _flashingCells = {};
  Set<String>       _consumedCells = {};
  _FallingDrop?     _fallingDrop;
  List<_GravityMove> _gravityMoves = [];
  Timer?            _stepTimer;
  Timer?            _fallTimer;

  final _audio = AudioService();
  final _rng   = math.Random();

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kDropMergeGameId);
    _initGame();
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _fallTimer?.cancel();
    super.dispose();
  }

  GameWrapperState get _wrapper => GameWrapper.of(context);

  void _initGame() {
    _grid          = _emptyGrid();
    _score         = 0;
    _chains        = 0;
    _gameOver      = false;
    _dropping      = false;
    _flashingCells = {};
    _consumedCells = {};
    _fallingDrop   = null;
    _gravityMoves  = [];
    _stepTimer?.cancel();
    _fallTimer?.cancel();
    _currentTile   = _nextTile(_difficulty, _rng);
    _undoUsed      = false;
    _inUndoWindow  = false;
    _prevGrid      = null;
    _prevScore     = null;
    _prevCurrentTile = null;
    _continueUsed  = false;
  }

  void _onColumnTap(int col) {
    if (_gameOver || _dropping) return;
    if (_inUndoWindow) _onUndoExpired();

    final (newGrid, landingRow, _) = _dropTile(_grid, col, _currentTile);
    if (landingRow == -1) return;

    final snapshotGrid = _copyGrid(_grid);
    final snapshotScore = _score;
    final snapshotTile = _currentTile;

    _prevGrid = snapshotGrid;
    _prevScore = snapshotScore;
    _prevCurrentTile = snapshotTile;

    _audio.playTap();

    // Physics-based fall duration
    final fallDistance = landingRow + 1;
    final fallDuration = Duration(
      milliseconds: (180 + fallDistance * fallDistance * 8 + fallDistance * 30).clamp(220, 500),
    );

    setState(() {
      _dropping    = true;
      _dropCol     = col;
      _fallingDrop = _FallingDrop(col: col, value: _currentTile, targetRow: landingRow, duration: fallDuration);
    });

    _fallTimer?.cancel();
    _fallTimer = Timer(fallDuration, () {
      if (!mounted) return;
      setState(() => _fallingDrop = null);
      _runMergeStep(_applyGravity(newGrid), 0, 0);
    });
  }

  // Runs one merge pass, shows it, then schedules the next after a delay.
  void _runMergeStep(_Grid grid, int chains, int accScore) {
    final result = _mergePass(grid, dropCol: _dropCol);

    if (result.score == 0) {
      _finishTurn(grid, accScore, chains);
      return;
    }

    final newChains   = chains + 1;
    final newAccScore = accScore + result.score;
    final multiplier  = newChains >= 2 ? 1.0 + (newChains - 1) * 0.5 : 1.0;
    final earnedNow   = (result.score * multiplier).round();

    _audio.playSuccess();
    setState(() {
      _grid          = result.grid;
      _score        += earnedNow;
      _chains        = newChains;
      _flashingCells = result.merged;
      _consumedCells = result.consumed;
      _gravityMoves  = [];
    });

    // Show merge animation for 350ms (matches Dropzy tile merge: 140ms up + 210ms down)
    _stepTimer?.cancel();
    _stepTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final beforeGravity = result.grid;
      final afterGravity  = _applyGravity(result.grid);
      final moves         = _computeGravityMoves(beforeGravity, afterGravity);

      setState(() {
        _grid          = afterGravity;
        _flashingCells = {};
        _consumedCells = {};
        _gravityMoves  = moves;
      });

      // Wait for gravity animation (150ms) then continue merge chain
      _stepTimer = Timer(const Duration(milliseconds: 170), () {
        if (!mounted) return;
        setState(() => _gravityMoves = []);
        _runMergeStep(afterGravity, newChains, newAccScore);
      });
    });
  }

  void _finishTurn(_Grid grid, int totalMergeScore, int chains) {
    final next = _nextTile(_difficulty, _rng);
    setState(() {
      _grid          = grid;
      _flashingCells = {};
      _consumedCells = {};
      _gravityMoves  = [];
      _dropping      = false;
      _chains        = 0;
      _currentTile   = next;
    });

    if (_isGameOver(_grid, _currentTile)) {
      setState(() => _gameOver = true);
      ScoreService().saveScore(kDropMergeGameId, _score, subKey: _difficulty.subKey);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) _wrapper.endGame();
      });
      return;
    }

    final undoAvailable = !_undoUsed && AdsService().isRewardedReady;
    if (undoAvailable) {
      setState(() => _inUndoWindow = true);
    }
  }

  void _onUndoExpired() {
    if (!mounted || !_inUndoWindow) return;
    setState(() {
      _inUndoWindow = false;
      _prevGrid = null;
      _prevScore = null;
      _prevCurrentTile = null;
    });
  }

  void _performUndo() {
    final prev = _prevGrid;
    final prevS = _prevScore;
    final prevT = _prevCurrentTile;
    if (prev == null || prevS == null || prevT == null) return;
    setState(() {
      _grid = prev;
      _score = prevS;
      _currentTile = prevT;
      _undoUsed = true;
      _inUndoWindow = false;
      _prevGrid = null;
      _prevScore = null;
      _prevCurrentTile = null;
    });
    _wrapper.updateScore(prevS);
  }

  void _continueGame() {
    final ng = _copyGrid(_grid);
    for (int c = 0; c < 4; c++) {
      ng[0][c] = 0;
    }
    final afterGravity = _applyGravity(ng);
    setState(() {
      _grid = afterGravity;
      _gameOver = false;
      _continueUsed = true;
    });
    _wrapper.continueAfterGameOver();
  }

  void _startGame() {
    setState(() => _initGame());
    _wrapper.startGame();
  }

  void _playAgain() {
    setState(() => _initGame());
    _wrapper.restartGame();
    _wrapper.startGame();
  }

  void _backToPickerScreen() {
    setState(() {
      _gameOver      = false;
      _score         = 0;
      _grid          = _emptyGrid();
      _chains        = 0;
      _dropping      = false;
      _flashingCells = {};
      _consumedCells = {};
      _gravityMoves  = [];
      _fallingDrop   = null;
      _stepTimer?.cancel();
      _fallTimer?.cancel();
    });
    _wrapper.restartGame();
  }

  void _backOrHome() {
    if (context.canPop()) { context.pop(); } else { context.go('/home'); }
  }

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    ScoreService().toggleFavorite(kDropMergeGameId);
    _audio.playTap();
  }

  void _showHelp() {
    final game = GameRegistry.getById(kDropMergeGameId);
    if (game == null) return;
    showHowToPlaySheet(context,
        title: game.name, howToPlay: game.howToPlay,
        accent: _kAccent, steps: dropMergeSteps());
  }

  @override
  Widget build(BuildContext context) {
    final state = _wrapper.state;

    if (state == GameState.ready) {
      return _ModePickerScreen(
        difficulty:          _difficulty,
        onDifficultyChanged: (d) => setState(() => _difficulty = d),
        isFavorite:          _isFavorite,
        onFavoriteToggle:    _toggleFavorite,
        onBack:              _backOrHome,
        onPlay:              _startGame,
        onHelp:              _showHelp,
      );
    }

    if (state == GameState.gameOver) return _buildResult();

    return _BoardScreen(
      difficulty:    _difficulty,
      grid:          _grid,
      score:         _score,
      currentTile:   _currentTile,
      chains:        _chains,
      gameOver:      _gameOver,
      flashingCells: _flashingCells,
      consumedCells: _consumedCells,
      fallingDrop:   _fallingDrop,
      gravityMoves:  _gravityMoves,
      onColumnTap:   _onColumnTap,
      onBack:        _backOrHome,
      onRestart:     _playAgain,
      undoWidget: _inUndoWindow
          ? RewardedUndoButton(
              key: ValueKey('undo_$_prevScore'),
              onUndo: _performUndo,
              onExpired: _onUndoExpired,
              accentColor: _kAccent,
            )
          : null,
    );
  }

  Widget _buildResult() {
    final best = ScoreService().getHighScore(kDropMergeGameId, subKey: _difficulty.subKey);
    final isNewBest = _score > 0 && _score >= best;
    final continueAction = _continueUsed
        ? null
        : rewardedContinueAction(
            context: context,
            label: 'Watch Ad to Continue',
            color: _kAccent,
            onRewarded: _continueGame,
          );
    return game_result.GenericGameResultScreen(
      gameId:           kDropMergeGameId,
      score:            _score,
      headline:         'Game Over',
      badgeContent:     '🎯',
      badgeColor:       _kAccent,
      showNewBestBadge: isNewBest,
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(label: 'SCORE', value: _score, color: _kAccent),
          game_result.StatItem(label: 'BEST',  value: best,   color: const Color(0xFF8B7BA7)),
        ],
      ),
      actions: [
        ?continueAction,
        game_result.GameResultAction(
          label: 'Play Again', icon: Icons.refresh_rounded,
          onTap: _playAgain, filled: continueAction == null, color: _kAccent,
        ),
        game_result.GameResultAction(
          label: 'Change Mode', icon: Icons.tune_rounded,
          onTap: _backToPickerScreen, filled: false,
        ),
        game_result.GameResultAction(
          label: 'Home', icon: Icons.home_rounded,
          onTap: () => context.go('/home'), filled: false,
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MODE PICKER
// ════════════════════════════════════════════════════════════════════════════

class _ModePickerScreen extends StatelessWidget {
  final _Difficulty              difficulty;
  final ValueChanged<_Difficulty> onDifficultyChanged;
  final bool         isFavorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onBack;
  final VoidCallback onPlay;
  final VoidCallback onHelp;

  const _ModePickerScreen({
    required this.difficulty,
    required this.onDifficultyChanged,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.onBack,
    required this.onPlay,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    return GamePickerScaffold(
      bgColorTop:    _kBgTop,
      bgColorBottom: _kBgBot,
      animatedBg: AnimatedBackground(
        factory: (t) => DropMergeBgPainter(t),
        period: const Duration(seconds: 12),
      ),
      iconRingColors: const [Color(0xFFFF922B), Color(0xFFE8590C), Color(0xFFFF922B)],
      iconChild: ClipRRect(
        borderRadius: BorderRadius.circular(42),
        child: buildDropMergeLogo(84),
      ),
      title:    'Drop Merge',
      subtitle: 'Drop tiles, merge numbers, chain reactions!',
      onBack:           onBack,
      isFavorite:       isFavorite,
      onFavoriteToggle: onFavoriteToggle,
      onHowToPlay:      onHelp,
      gameId:           kDropMergeGameId,
      tallThreshold:    860,
      body: GameSinglePickerBody(
        difficulties: _Difficulty.values.map((d) => GameDifficultyData(
          label:     d.label,
          color:     d.color,
          kind:      d.kind,
          hint:      d.hint,
          bestScore: bestDropMergeScore(d.subKey),
          bestLabel: (s) => 'Best score: $s',
        )).toList(),
        activeIndex: _Difficulty.values.indexOf(difficulty),
        onChanged:   (i) => onDifficultyChanged(_Difficulty.values[i]),
        playLabel:    'Play Drop Merge',
        playSubLabel: '4×4 grid · drop & merge',
        onPlay:      onPlay,
        accentColor: _kAccent,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BOARD SCREEN
// ════════════════════════════════════════════════════════════════════════════

class _BoardScreen extends StatelessWidget {
  final _Difficulty        difficulty;
  final _Grid              grid;
  final int                score;
  final int                currentTile;
  final int                chains;
  final bool               gameOver;
  final Set<String>        flashingCells;
  final Set<String>        consumedCells;
  final _FallingDrop?      fallingDrop;
  final List<_GravityMove> gravityMoves;
  final void Function(int) onColumnTap;
  final VoidCallback       onBack;
  final VoidCallback       onRestart;
  final Widget?            undoWidget;

  const _BoardScreen({
    required this.difficulty,
    required this.grid,
    required this.score,
    required this.currentTile,
    required this.chains,
    required this.gameOver,
    required this.flashingCells,
    required this.consumedCells,
    required this.fallingDrop,
    required this.gravityMoves,
    required this.onColumnTap,
    required this.onBack,
    required this.onRestart,
    this.undoWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kBgTop, _kBgBot],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(children: [
          const SizedBox(height: 4),
          GameHudBar(
            leading: GameBackButton(onTap: onBack),
            centerContent: _ScorePill(difficulty: difficulty, score: score),
            trailing: GameRestartButton(
              gameName:    'Drop Merge',
              accentColor: _kAccent,
              onRestart:   onRestart,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: undoWidget ?? const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          _CurrentTile(value: currentTile),
          const SizedBox(height: 16),
          // Board
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _GameBoard(
                  grid:          grid,
                  currentTile:   currentTile,
                  chains:        chains,
                  flashingCells: flashingCells,
                  consumedCells: consumedCells,
                  fallingDrop:   fallingDrop,
                  gravityMoves:  gravityMoves,
                  onColumnTap:   onColumnTap,
                  gameOver:      gameOver,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

// ── Score Pill ────────────────────────────────────────────────────────────────

class _ScorePill extends StatelessWidget {
  final _Difficulty _diff;
  final int score;

  const _ScorePill({required _Difficulty difficulty, required this.score})
      : _diff = difficulty;

  @override
  Widget build(BuildContext context) {
    final color = _diff.color;
    final best  = ScoreService().getHighScore(kDropMergeGameId, subKey: _diff.subKey);

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          boxShadow: [BoxShadow(
              color: color.withValues(alpha: 0.30),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Text(_diff.label,
            style: const TextStyle(color: Colors.white, fontSize: 10,
                fontWeight: FontWeight.w800, letterSpacing: 1.4)),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: _kAccent.withValues(alpha: 0.12),
              blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
              child: FadeTransition(opacity: anim, child: child)),
            child: Text('$score', key: ValueKey<int>(score),
                style: const TextStyle(color: _kAccent, fontSize: 22,
                    fontWeight: FontWeight.w900, height: 1)),
          ),
          if (best > 0)
            Text('best $best',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10,
                    fontWeight: FontWeight.w600)),
        ]),
      ),
    ]);
  }
}

// ── Current Tile Display ──────────────────────────────────────────────────────

class _CurrentTile extends StatelessWidget {
  final int value;

  const _CurrentTile({required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('DROP',
          style: TextStyle(
            color: _kAccent.withValues(alpha: 0.70),
            fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
      const SizedBox(height: 4),
      _TileWidget(value: value, size: 60),
    ]);
  }
}



// ── Tile Widget ───────────────────────────────────────────────────────────────

class _TileWidget extends StatelessWidget {
  final int    value;
  final double size;

  const _TileWidget({super.key, required this.value, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = _tileColor(value);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.18),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.50),
              blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: color.withValues(alpha: 0.25),
              blurRadius: 24, spreadRadius: 2),
        ],
      ),
      alignment: Alignment.center,
      child: Text('$value',
          style: TextStyle(
            color: _tileTextColor(value),
            fontSize: _tileFontSize(value),
            fontWeight: FontWeight.w900,
          )),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// GAME BOARD
// ════════════════════════════════════════════════════════════════════════════

class _PopupEntry {
  final int row, col, value, chains;
  final AnimationController ctrl;
  _PopupEntry({required this.row, required this.col, required this.value, required this.chains, required this.ctrl});
}

class _GameBoard extends StatefulWidget {
  final _Grid              grid;
  final int                currentTile;
  final int                chains;
  final Set<String>        flashingCells;
  final Set<String>        consumedCells;
  final _FallingDrop?      fallingDrop;
  final List<_GravityMove> gravityMoves;
  final void Function(int) onColumnTap;
  final bool               gameOver;

  const _GameBoard({
    required this.grid,
    required this.currentTile,
    required this.chains,
    required this.flashingCells,
    required this.consumedCells,
    required this.fallingDrop,
    required this.gravityMoves,
    required this.onColumnTap,
    required this.gameOver,
  });

  @override
  State<_GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<_GameBoard>
    with TickerProviderStateMixin {
  late final AnimationController _fallCtrl;
  late AnimationController _gravityCtrl;
  _FallingDrop? _activeDrop;
  List<_GravityMove> _activeGravityMoves = [];

  final List<_PopupEntry> _popups = [];
  double _pitch    = 0;
  double _boardPad = 6;
  double _cellPad  = 3;

  @override
  void initState() {
    super.initState();
    _fallCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _gravityCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
  }

  @override
  void didUpdateWidget(_GameBoard old) {
    super.didUpdateWidget(old);

    // Falling drop
    final drop = widget.fallingDrop;
    if (drop != null && drop != old.fallingDrop) {
      _activeDrop = drop;
      _fallCtrl.duration = drop.duration;
      _fallCtrl.forward(from: 0);
    }
    if (drop == null && old.fallingDrop != null) {
      _fallCtrl.reset();
      _activeDrop = null;
    }

    // Gravity moves
    if (widget.gravityMoves.isNotEmpty && widget.gravityMoves != old.gravityMoves) {
      _activeGravityMoves = widget.gravityMoves;
      _gravityCtrl.forward(from: 0);
    }

    // Spawn merge popups for new flashing cells
    final newFlashing = widget.flashingCells.difference(old.flashingCells);
    for (final key in newFlashing) {
      final parts = key.split(',');
      final r = int.parse(parts[0]);
      final c = int.parse(parts[1]);
      final val = widget.grid[r][c];
      if (val > 0) _spawnPopup(r, c, val, widget.chains);
    }
  }

  void _spawnPopup(int row, int col, int value, int chains) {
    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    final entry = _PopupEntry(row: row, col: col, value: value, chains: chains, ctrl: ctrl);
    setState(() => _popups.add(entry));
    ctrl.forward().then((_) {
      ctrl.dispose();
      if (mounted) setState(() => _popups.remove(entry));
    });
  }

  @override
  void dispose() {
    _fallCtrl.dispose();
    _gravityCtrl.dispose();
    for (final p in _popups) p.ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final side    = math.min(constraints.maxWidth, constraints.maxHeight - 60);
      final cellSize = side / 4;
      _boardPad = 6.0;
      _cellPad  = 3.0;
      const gap = 4.0;
      _pitch = (cellSize * 4 - _boardPad * 2) / 4;

      return Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Board card ─────────────────────────────────────────
              Container(
                width:  cellSize * 4,
                height: cellSize * 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBF5),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _kAccent.withValues(alpha: 0.25), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: _kAccent.withValues(alpha: 0.15),
                        blurRadius: 20, offset: const Offset(0, 6)),
                    BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(_boardPad),
                  child: Column(
                    children: List.generate(4, (r) => Expanded(
                      child: Row(
                        children: List.generate(4, (c) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(_cellPad),
                            child: GestureDetector(
                              onTap: widget.gameOver ? null : () => widget.onColumnTap(c),
                              child: _TileCell(
                                value:      widget.grid[r][c],
                                isFlashing: widget.flashingCells.contains('$r,$c'),
                                isConsumed: widget.consumedCells.contains('$r,$c'),
                              ),
                            ),
                          ),
                        )),
                      ),
                    )),
                  ),
                ),
              ),
            ],
          ),

          // ── Falling tile overlay (physics-based) ───────────────────
          if (_activeDrop != null)
            AnimatedBuilder(
              animation: _fallCtrl,
              builder: (ctx, _) {
                final drop  = _activeDrop!;
                final raw   = _fallCtrl.value;
                final tileW = _pitch - _cellPad * 2;
                final x     = _boardPad + drop.col * _pitch + _cellPad;
                final startY = gap + _boardPad + _cellPad;
                final endY   = gap + _boardPad + drop.targetRow * _pitch + _cellPad;
                final fallIntensity = (drop.targetRow / 3.0).clamp(0.0, 1.0);

                double y, sx, sy;

                if (raw < 0.60) {
                  // Gravity acceleration (quadratic ease-in)
                  final t2 = (raw / 0.60) * (raw / 0.60);
                  y = startY + (endY - startY) * t2;
                  final vel = 2 * (raw / 0.60);
                  final stretch = 0.14 * fallIntensity * vel;
                  sy = 1.0 + stretch;
                  sx = 1.0 - stretch * 0.4;
                } else if (raw < 0.78) {
                  // Squash + first bounce
                  final bT = (raw - 0.60) / 0.18;
                  if (bT < 0.28) {
                    final sq = (0.12 + 0.16 * fallIntensity) *
                        Curves.easeOut.transform(bT / 0.28);
                    y = endY; sy = 1.0 - sq; sx = 1.0 + sq * 0.5;
                  } else {
                    final upT = (bT - 0.28) / 0.72;
                    final bH  = cellSize * (0.07 + 0.22 * fallIntensity);
                    final up  = upT < 0.45
                        ? Curves.easeOut.transform(upT / 0.45) * bH
                        : bH * math.pow(1.0 - (upT - 0.45) / 0.55, 2);
                    y = endY - up; sy = 1.0; sx = 1.0;
                  }
                } else {
                  // Micro-wobble settle
                  final sT = (raw - 0.78) / 0.22;
                  final w  = math.sin(sT * math.pi * 2) * (1.0 - sT) * 0.012 * fallIntensity;
                  y = endY; sy = 1.0 + w; sx = 1.0 - w * 0.3;
                }

                return Positioned(
                  left: x,
                  top:  y,
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.diagonal3Values(sx, sy, 1.0),
                    child: Container(
                      width:  tileW,
                      height: tileW,
                      decoration: BoxDecoration(
                        color: _tileColor(drop.value),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(
                          color: _tileColor(drop.value).withValues(alpha: 0.55),
                          blurRadius: 14, offset: const Offset(0, 5),
                        )],
                      ),
                      alignment: Alignment.center,
                      child: Text('${drop.value}',
                        style: TextStyle(
                          color: _tileTextColor(drop.value),
                          fontSize: _tileFontSize(drop.value),
                          fontWeight: FontWeight.w900,
                        )),
                    ),
                  ),
                );
              },
            ),

          // ── Gravity settle animation ────────────────────────────────
          if (_activeGravityMoves.isNotEmpty)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _gravityCtrl,
                builder: (ctx, _) {
                  final t = Curves.easeInQuad.transform(_gravityCtrl.value);
                  return Stack(
                    children: _activeGravityMoves.map((move) {
                      final tileW = _pitch - _cellPad * 2;
                      final x     = _boardPad + move.col * _pitch + _cellPad;
                      final fromY = gap + _boardPad + move.fromRow * _pitch + _cellPad;
                      final toY   = gap + _boardPad + move.toRow   * _pitch + _cellPad;
                      final y     = fromY + (toY - fromY) * t;
                      final val   = widget.grid[move.toRow][move.col];
                      if (val == 0) return const SizedBox.shrink();
                      return Positioned(
                        left: x, top: y,
                        child: Container(
                          width: tileW, height: tileW,
                          decoration: BoxDecoration(
                            color: _tileColor(val),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text('$val',
                            style: TextStyle(
                              color: _tileTextColor(val),
                              fontSize: _tileFontSize(val),
                              fontWeight: FontWeight.w900,
                            )),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),

          // ── Score popups ────────────────────────────────────────────
          for (final popup in _popups)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: popup.ctrl,
                builder: (ctx, _) {
                  final t      = popup.ctrl.value;
                  final tileW  = _pitch - _cellPad * 2;
                  final cx     = _boardPad + popup.col * _pitch + _cellPad + tileW / 2;
                  final baseY  = _boardPad + popup.row * _pitch + _cellPad;
                  final dy     = t * 55;
                  final color  = _tileColor(popup.value);
                  final double opacity;
                  if (t < 0.15)      opacity = t / 0.15;
                  else if (t < 0.55) opacity = 1.0;
                  else               opacity = 1.0 - (t - 0.55) / 0.45;

                  // Positioned must be a direct child of a Stack, not of Positioned.fill
                  return Stack(children: [
                    Positioned(
                      left: cx - 22,
                      top:  baseY - dy,
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [BoxShadow(
                              color: color.withValues(alpha: 0.50),
                              blurRadius: 8,
                            )],
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: _tileTextColor(popup.value),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                              children: [
                                TextSpan(text: '+${popup.value}'),
                                if (popup.chains >= 2)
                                  TextSpan(
                                    text: ' ×${(1.0 + (popup.chains - 1) * 0.5).toStringAsFixed(1)}',
                                    style: TextStyle(
                                      color: _tileTextColor(popup.value).withValues(alpha: 0.85),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]);
                },
              ),
            ),
        ],
      );
    });
  }
}

// ── Tile Cell ─────────────────────────────────────────────────────────────────

class _TileCell extends StatefulWidget {
  final int  value;
  final bool isFlashing;
  final bool isConsumed;

  const _TileCell({
    required this.value,
    required this.isFlashing,
    required this.isConsumed,
  });

  @override
  State<_TileCell> createState() => _TileCellState();
}

class _TileCellState extends State<_TileCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
  }

  @override
  void didUpdateWidget(_TileCell old) {
    super.didUpdateWidget(old);
    if ((widget.isFlashing && !old.isFlashing) ||
        (widget.isConsumed && !old.isConsumed)) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.value == 0;
    final color   = isEmpty ? const Color(0xFFEEEEEE) : _tileColor(widget.value);

    if (isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    if (widget.isConsumed) {
      return AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, _) {
          final t = Curves.easeIn.transform(_ctrl.value);
          return Opacity(
            opacity: (1.0 - t).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: (1.0 - t * 0.6).clamp(0.0, 1.0),
              child: _buildTileBody(color),
            ),
          );
        },
      );
    }

    if (widget.isFlashing) {
      return AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, _) {
          final t = _ctrl.value;
          // 140ms up to 1.25× (t < 0.40), 210ms back down (t >= 0.40) — matches Dropzy
          final double scale;
          if (t < 0.40) {
            scale = 1.0 + Curves.easeOut.transform(t / 0.40) * 0.25;
          } else {
            scale = 1.25 - Curves.easeOut.transform((t - 0.40) / 0.60) * 0.25;
          }
          final flashAlpha = t < 0.20
              ? (t / 0.20) * 0.65
              : t < 0.50
                  ? 0.65 * (1.0 - (t - 0.20) / 0.30)
                  : 0.0;
          final ringScale   = 1.0 + t * 0.60;
          final ringOpacity = math.sin(t * math.pi) * 0.70;

          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: ringScale,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: color.withValues(alpha: ringOpacity.clamp(0, 1)),
                      width: 2.5,
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: scale,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildTileBody(color),
                    if (flashAlpha > 0)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: flashAlpha.clamp(0, 1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    }

    return _buildTileBody(color);
  }

  Widget _buildTileBody(Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 4, offset: const Offset(0, 2))],
      ),
      alignment: Alignment.center,
      child: Text('${widget.value}',
          style: TextStyle(
            color: _tileTextColor(widget.value),
            fontSize: _tileFontSize(widget.value),
            fontWeight: FontWeight.w900,
          )),
    );
  }
}
