import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
import 'tile_drop_logo.dart';
import 'tile_drop_stats.dart';
import 'tile_drop_tutorial.dart';

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

// ── Pure game logic ───────────────────────────────────────────────────────────

typedef _Grid = List<List<int>>;

_Grid _emptyGrid() => List.generate(4, (_) => List.filled(4, 0));
_Grid _copyGrid(_Grid g) => [for (final r in g) List<int>.from(r)];

// Drop tile into column. Returns (newGrid, landingRow, directMergeScore).
// landingRow == -1 means can't place.
(_Grid, int, int) _dropTile(_Grid grid, int col, int value) {
  // Find lowest empty row
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

  // Column full — check if top cell matches → instant merge
  if (grid[0][col] == value) {
    final ng = _copyGrid(grid);
    ng[0][col] = value * 2;
    return (ng, 0, value * 2);
  }

  return (grid, -1, 0);
}

// Apply gravity in each column (tiles fall to bottom).
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

// One merge pass: vertical then horizontal.
({_Grid grid, Set<String> merged, Set<String> consumed, int score})
    _mergePass(_Grid grid, int dropCol) {
  final ng = _copyGrid(grid);
  final merged   = <String>{};
  final consumed = <String>{};
  int score = 0;

  // Vertical merges: bottom-up, same-value adjacent pairs in same column
  for (int c = 0; c < 4; c++) {
    for (int r = 3; r > 0; r--) {
      if (ng[r][c] != 0 && ng[r][c] == ng[r - 1][c]) {
        final val = ng[r][c] * 2;
        score += val;
        ng[r][c]     = val;
        ng[r - 1][c] = 0;
        merged.add('$r,$c');
        consumed.add('${r - 1},$c');
      }
    }
  }

  // Horizontal merges: left-right pairs, keep cell closest to dropCol
  for (int r = 0; r < 4; r++) {
    for (int c = 0; c < 3; c++) {
      if (ng[r][c] != 0 && ng[r][c] == ng[r][c + 1]) {
        final val = ng[r][c] * 2;
        score += val;
        // keep closer to dropCol
        final keepLeft = (c - dropCol).abs() <= (c + 1 - dropCol).abs();
        if (keepLeft) {
          ng[r][c]     = val;
          ng[r][c + 1] = 0;
          merged.add('$r,$c');
          consumed.add('$r,${c + 1}');
        } else {
          ng[r][c + 1] = val;
          ng[r][c]     = 0;
          merged.add('$r,${c + 1}');
          consumed.add('$r,$c');
        }
      }
    }
  }

  return (grid: ng, merged: merged, consumed: consumed, score: score);
}

// Run all merge passes until stable.
({_Grid grid, int score, int chains}) _mergeAll(_Grid grid, int dropCol) {
  int totalScore = 0;
  int chains     = 0;
  _Grid cur = _applyGravity(grid);

  for (int pass = 0; pass < 32; pass++) {
    final result = _mergePass(cur, dropCol);
    if (result.score == 0) break;
    chains++;
    totalScore += result.score;
    cur = _applyGravity(result.grid);
  }

  return (grid: cur, score: totalScore, chains: chains);
}

int _calcFinalScore(int mergeScore, int chains) {
  if (chains == 0) return mergeScore;
  final multiplier = 1.0 + (chains - 1) * 0.5;
  return (mergeScore * multiplier).round();
}

bool _isGameOver(_Grid grid, int nextTile) {
  // Not over if any column has space
  for (int c = 0; c < 4; c++) {
    if (grid[0][c] == 0) { return false; }
  }
  // All top cells filled — game over unless one matches nextTile
  for (int c = 0; c < 4; c++) {
    if (grid[0][c] == nextTile) { return false; }
  }
  return true;
}

// ════════════════════════════════════════════════════════════════════════════
// ROOT SCREEN
// ════════════════════════════════════════════════════════════════════════════

class TileDropScreen extends StatefulWidget {
  const TileDropScreen({super.key});

  @override
  State<TileDropScreen> createState() => _TileDropScreenState();
}

class _TileDropScreenState extends State<TileDropScreen> {
  _Difficulty _difficulty = _Difficulty.medium;
  _Grid       _grid       = _emptyGrid();
  int         _score      = 0;
  int         _currentTile = 2;
  List<int>   _nextQueue  = [2, 2, 2]; // 3 upcoming tiles
  bool        _gameOver   = false;
  bool        _dropping   = false;
  bool        _isFavorite = false;

  Set<String> _flashingCells  = {};
  Set<String> _consumedCells  = {};
  Timer?      _flashTimer;

  final _audio = AudioService();
  final _rng   = math.Random();

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kTileDropGameId);
    _initGame();
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  GameWrapperState get _wrapper => GameWrapper.of(context);

  void _initGame() {
    _grid        = _emptyGrid();
    _score       = 0;
    _gameOver    = false;
    _dropping    = false;
    _flashingCells  = {};
    _consumedCells  = {};
    _flashTimer?.cancel();
    _currentTile = _nextTile(_difficulty, _rng);
    _nextQueue   = List.generate(3, (_) => _nextTile(_difficulty, _rng));
  }

  void _onColumnTap(int col) {
    if (_gameOver || _dropping) return;

    final (newGrid, landingRow, directMergeScore) =
        _dropTile(_grid, col, _currentTile);

    if (landingRow == -1) return; // can't place

    setState(() => _dropping = true);
    _audio.playTap();

    // Run merges
    final merged = _mergeAll(newGrid, col);
    final totalMergeScore = directMergeScore + merged.score;
    final finalScore = _calcFinalScore(totalMergeScore, merged.chains);

    // Flash merged / consumed cells
    final passResult = _mergePass(newGrid, col);
    final flashMerged   = passResult.merged;
    final flashConsumed = passResult.consumed;

    setState(() {
      _grid  = merged.grid;
      _score += finalScore;
      _flashingCells  = flashMerged;
      _consumedCells  = flashConsumed;
    });

    if (totalMergeScore > 0) _audio.playSuccess();

    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _flashingCells = {};
        _consumedCells = {};
        _dropping      = false;
      });

      // Advance queue
      final next = _nextQueue.first;
      setState(() {
        _currentTile = next;
        _nextQueue   = [..._nextQueue.sublist(1), _nextTile(_difficulty, _rng)];
      });

      // Check game over
      if (_isGameOver(_grid, _currentTile)) {
        setState(() => _gameOver = true);
        ScoreService().saveScore(kTileDropGameId, _score, subKey: _difficulty.subKey);
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) _wrapper.endGame();
        });
      }
    });
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

  void _backOrHome() {
    if (context.canPop()) { context.pop(); } else { context.go('/home'); }
  }

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    ScoreService().toggleFavorite(kTileDropGameId);
    _audio.playTap();
  }

  void _showHelp() {
    final game = GameRegistry.getById(kTileDropGameId);
    if (game == null) return;
    showHowToPlaySheet(context,
        title: game.name, howToPlay: game.howToPlay,
        accent: _kAccent, steps: tileDropSteps());
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
      difficulty:     _difficulty,
      grid:           _grid,
      score:          _score,
      currentTile:    _currentTile,
      nextQueue:      _nextQueue,
      gameOver:       _gameOver,
      flashingCells:  _flashingCells,
      consumedCells:  _consumedCells,
      onColumnTap:    _onColumnTap,
      onBack:         _backOrHome,
      onRestart:      _playAgain,
    );
  }

  Widget _buildResult() {
    final best = ScoreService().getHighScore(kTileDropGameId, subKey: _difficulty.subKey);
    final isNewBest = _score > 0 && _score >= best;
    return game_result.GenericGameResultScreen(
      headline:        'Game Over',
      badgeContent:    '🎯',
      badgeColor:      _kAccent,
      showNewBestBadge: isNewBest,
      gradientColors:  const [Color(0xFFFFF9F0), Color(0xFFFFF0D9), Color(0xFFFFE4C0)],
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(label: 'SCORE', value: _score, color: _kAccent),
          game_result.StatItem(label: 'BEST',  value: best,   color: const Color(0xFF8B7BA7)),
        ],
      ),
      actions: [
        game_result.GameResultAction(
          label: 'Play Again', icon: Icons.refresh_rounded,
          onTap: _playAgain, filled: true, color: _kAccent,
        ),
        game_result.GameResultAction(
          label: 'Home', icon: Icons.home_rounded, onTap: _backOrHome,
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
        factory: (t) => TileDropBgPainter(t),
        period: const Duration(seconds: 12),
      ),
      iconRingColors: const [Color(0xFFFF922B), Color(0xFFE8590C), Color(0xFFFF922B)],
      iconChild: Builder(builder: (ctx) {
        final info = GameRegistry.getById(kTileDropGameId);
        final logo = info?.buildBrandedLogo(size: 84);
        if (logo != null) {
          return ClipRRect(borderRadius: BorderRadius.circular(42), child: logo);
        }
        return const Icon(Icons.view_column_rounded, size: 40, color: Color(0xFFFF922B));
      }),
      title:    'Tile Drop',
      subtitle: 'Drop tiles, merge numbers, chain reactions!',
      onBack:           onBack,
      isFavorite:       isFavorite,
      onFavoriteToggle: onFavoriteToggle,
      onHowToPlay:      onHelp,
      tallThreshold:    860,
      body: GameSinglePickerBody(
        difficulties: _Difficulty.values.map((d) => GameDifficultyData(
          label:     d.label,
          color:     d.color,
          kind:      d.kind,
          hint:      d.hint,
          bestScore: bestTileDropScore(d.subKey),
          bestLabel: (s) => 'Best score: $s',
        )).toList(),
        activeIndex: _Difficulty.values.indexOf(difficulty),
        onChanged:   (i) => onDifficultyChanged(_Difficulty.values[i]),
        playLabel:    'Play Tile Drop',
        playSubLabel: '4×4 grid · merge & chain',
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
  final _Difficulty  difficulty;
  final _Grid        grid;
  final int          score;
  final int          currentTile;
  final List<int>    nextQueue;
  final bool         gameOver;
  final Set<String>  flashingCells;
  final Set<String>  consumedCells;
  final void Function(int) onColumnTap;
  final VoidCallback onBack;
  final VoidCallback onRestart;

  const _BoardScreen({
    required this.difficulty,
    required this.grid,
    required this.score,
    required this.currentTile,
    required this.nextQueue,
    required this.gameOver,
    required this.flashingCells,
    required this.consumedCells,
    required this.onColumnTap,
    required this.onBack,
    required this.onRestart,
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
              gameName:   'Tile Drop',
              accentColor: _kAccent,
              onRestart:  onRestart,
            ),
          ),
          const SizedBox(height: 12),
          // Current tile preview
          _CurrentTilePreview(value: currentTile),
          const SizedBox(height: 8),
          // Board
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _TileBoard(
                  grid:          grid,
                  currentTile:   currentTile,
                  flashingCells: flashingCells,
                  consumedCells: consumedCells,
                  onColumnTap:   onColumnTap,
                  gameOver:      gameOver,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Next queue
          _NextQueueRow(queue: nextQueue),
          const SizedBox(height: 16),
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
    final best  = ScoreService().getHighScore(kTileDropGameId, subKey: _diff.subKey);

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

// ── Current Tile Preview ──────────────────────────────────────────────────────

class _CurrentTilePreview extends StatelessWidget {
  final int value;

  const _CurrentTilePreview({required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('TAP COLUMN ↓',
          style: TextStyle(color: _kAccent.withValues(alpha: 0.80),
              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
      const SizedBox(height: 4),
      _MiniTile(value: value, size: 48),
    ]);
  }
}

// ── Next Queue ────────────────────────────────────────────────────────────────

class _NextQueueRow extends StatelessWidget {
  final List<int> queue;

  const _NextQueueRow({required this.queue});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('NEXT',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 10,
              fontWeight: FontWeight.w700, letterSpacing: 1.4)),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: queue.map((v) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Opacity(opacity: 0.65, child: _MiniTile(value: v, size: 36)),
        )).toList(),
      ),
    ]);
  }
}

// ── Mini Tile ─────────────────────────────────────────────────────────────────

class _MiniTile extends StatelessWidget {
  final int    value;
  final double size;

  const _MiniTile({required this.value, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: _tileColor(value),
        borderRadius: BorderRadius.circular(size * 0.18),
        boxShadow: [BoxShadow(
            color: _tileColor(value).withValues(alpha: 0.40),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      alignment: Alignment.center,
      child: Text('$value',
          style: TextStyle(
            color: _tileTextColor(value),
            fontSize: size * 0.36,
            fontWeight: FontWeight.w900,
          )),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TILE BOARD
// ════════════════════════════════════════════════════════════════════════════

class _TileBoard extends StatelessWidget {
  final _Grid        grid;
  final int          currentTile;
  final Set<String>  flashingCells;
  final Set<String>  consumedCells;
  final void Function(int) onColumnTap;
  final bool         gameOver;

  const _TileBoard({
    required this.grid,
    required this.currentTile,
    required this.flashingCells,
    required this.consumedCells,
    required this.onColumnTap,
    required this.gameOver,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final side     = math.min(constraints.maxWidth, constraints.maxHeight);
      final cellSize = side / 4;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Column tap zones (arrow hints)
          SizedBox(
            height: 28,
            child: Row(
              children: List.generate(4, (c) {
                final colFull = grid[0][c] != 0 && grid[0][c] != currentTile;
                return Expanded(
                  child: GestureDetector(
                    onTap: gameOver ? null : () => onColumnTap(c),
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: colFull ? 0.20 : 1.0,
                        child: Icon(Icons.arrow_drop_down_rounded,
                            color: _kAccent, size: 26),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 2),
          // Board card
          Container(
            width:  cellSize * 4,
            height: cellSize * 4,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: _kAccent.withValues(alpha: 0.18),
                    blurRadius: 20, offset: const Offset(0, 6)),
                BoxShadow(color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: List.generate(4, (r) => Expanded(
                  child: Row(
                    children: List.generate(4, (c) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: GestureDetector(
                          onTap: gameOver ? null : () => onColumnTap(c),
                          child: _TileCell(
                            value:     grid[r][c],
                            isFlashing: flashingCells.contains('$r,$c'),
                            isConsumed: consumedCells.contains('$r,$c'),
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
        vsync: this, duration: const Duration(milliseconds: 250));
  }

  @override
  void didUpdateWidget(_TileCell old) {
    super.didUpdateWidget(old);
    if (widget.isFlashing && !old.isFlashing) {
      _ctrl.forward(from: 0).then((_) {
        if (mounted) _ctrl.reverse();
      });
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

    Widget cell = Container(
      decoration: BoxDecoration(
        color: isEmpty ? const Color(0xFFF0F0F0) : _tileColor(widget.value),
        borderRadius: BorderRadius.circular(8),
        boxShadow: isEmpty
            ? null
            : [BoxShadow(
                color: _tileColor(widget.value).withValues(alpha: 0.35),
                blurRadius: 4, offset: const Offset(0, 2))],
      ),
      alignment: Alignment.center,
      child: isEmpty
          ? null
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('${widget.value}',
                  style: TextStyle(
                    color: _tileTextColor(widget.value),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  )),
            ),
    );

    if (widget.isConsumed) {
      cell = FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0).animate(_ctrl),
        child: cell,
      );
    } else if (widget.isFlashing) {
      cell = ScaleTransition(
        scale: TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 50),
        ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
        child: cell,
      );
    }

    return cell;
  }
}
