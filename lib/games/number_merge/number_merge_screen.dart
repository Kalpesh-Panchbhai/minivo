import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/audio_service.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../game_picker_scaffold.dart';
import '../game_registry.dart';
import '../game_wrapper.dart';
import 'number_merge_stats.dart';

// ── Design tokens ──────────────────────────────────────────────────────────
const Color _kBgTop    = Color(0xFFFFFBF0);
const Color _kBgBot    = Color(0xFFFFF5E0);
const Color _kCardBg   = Colors.white;
const Color _kTextDark = Color(0xFF2D2600);
const Color _kTextMid  = Color(0xFF9E8B5C);

// ── 2048 brand colors ──────────────────────────────────────────────────────
const Color _kGolden = Color(0xFFEDC22E);
const Color _kOrange = Color(0xFFF67C5F);

// ── Difficulty palette ─────────────────────────────────────────────────────
const Color _kEasyColor   = Color(0xFF22C55E);
const Color _kMediumColor = Color(0xFFF59E0B);
const Color _kHardColor   = Color(0xFFEF4444);

// ── Tile color palette ─────────────────────────────────────────────────────
const Map<int, _TileStyle> _kTileStyles = {
  0:    _TileStyle(Color(0xFFCDC1B4), Colors.transparent),
  2:    _TileStyle(Color(0xFFEEE4DA), Color(0xFF776E65)),
  4:    _TileStyle(Color(0xFFEDE0C8), Color(0xFF776E65)),
  8:    _TileStyle(Color(0xFFF2B179), Color(0xFFF9F6F2)),
  16:   _TileStyle(Color(0xFFF59563), Color(0xFFF9F6F2)),
  32:   _TileStyle(Color(0xFFF67C5F), Color(0xFFF9F6F2)),
  64:   _TileStyle(Color(0xFFF65E3B), Color(0xFFF9F6F2)),
  128:  _TileStyle(Color(0xFFEDCF72), Color(0xFFF9F6F2)),
  256:  _TileStyle(Color(0xFFEDCC61), Color(0xFFF9F6F2)),
  512:  _TileStyle(Color(0xFFEDC850), Color(0xFFF9F6F2)),
  1024: _TileStyle(Color(0xFFEDC53F), Color(0xFFF9F6F2)),
  2048: _TileStyle(Color(0xFFEDC22E), Color(0xFFF9F6F2)),
};

_TileStyle _styleFor(int v) =>
    _kTileStyles[v] ?? const _TileStyle(Color(0xFF3C3A32), Color(0xFFF9F6F2));

class _TileStyle {
  final Color bg;
  final Color fg;
  const _TileStyle(this.bg, this.fg);
}

double _tileFont(int v) {
  if (v < 100)   return 30;
  if (v < 1000)  return 24;
  if (v < 10000) return 18;
  return 14;
}

// ── Difficulty enum ────────────────────────────────────────────────────────
enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label   => ['EASY', 'MEDIUM', 'HARD'][index];
  String get emoji   => ['🌱', '🔥', '💀'][index];
  Color  get color   => [_kEasyColor, _kMediumColor, _kHardColor][index];
  int    get target  => [1024, 2048, 4096][index];
  double get twoProb => [0.90, 0.80, 0.65][index];
  String get subKey  => ['easy', 'medium', 'hard'][index];
  String get desc    =>
      ['Reach 1024 — great for beginners',
       'Reach 2048 — the classic challenge',
       'Reach 4096 — only for the brave'][index];
}

// ── Tile identity tracking ─────────────────────────────────────────────────
class _Tile {
  final int id;
  int value;
  int row;
  int col;
  bool justSpawned;
  bool mergedOut = false;

  _Tile({
    required this.id,
    required this.value,
    required this.row,
    required this.col,
    this.justSpawned = false,
  });
}

const int _kN = 4; // board size

// ════════════════════════════════════════════════════════════════
// Root screen
// ════════════════════════════════════════════════════════════════

class NumberMergeScreen extends StatefulWidget {
  const NumberMergeScreen({super.key});

  @override
  State<NumberMergeScreen> createState() => _NumberMergeScreenState();
}

class _NumberMergeScreenState extends State<NumberMergeScreen> {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.medium;

  bool _isFavorite = false;

  // ── Tile state ───────────────────────────────────────────────────────────
  final _rng = Random();
  List<_Tile> _tiles = [];
  int _nextId = 0;
  int _score = 0;
  int _bestScore = 0;

  bool _won = false;
  bool _continueAfterWin = false;
  bool _gameOver = false;

  // For swipe gesture tracking
  Offset? _panStart;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kNumberMergeGameId);
    _bestScore = _loadBest(_Difficulty.medium);
  }

  int _loadBest(_Difficulty d) =>
      ScoreService().getHighScore(kNumberMergeGameId, subKey: d.subKey);

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kNumberMergeGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kNumberMergeGameId);
    if (info == null) return;
    showHowToPlaySheet(
      context,
      title: info.name,
      howToPlay: info.howToPlay,
      accent: _kGolden,
    );
  }

  // ── Game start / restart ─────────────────────────────────────────────────

  void _startGame(_Difficulty diff) {
    final tiles = <_Tile>[];
    _nextId = 0;
    // Spawn 2 initial tiles
    tiles.addAll(_spawnNewTile(tiles));
    tiles.addAll(_spawnNewTile(tiles));

    setState(() {
      _activeDifficulty = diff;
      _pickerDifficulty = diff;
      _tiles = tiles;
      _score = 0;
      _bestScore = _loadBest(diff);
      _won = false;
      _continueAfterWin = false;
      _gameOver = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GameWrapper.of(context).startGame();
        GameWrapper.of(context).updateScore(0);
      }
    });
  }

  void _newGame() => _startGame(_activeDifficulty ?? _pickerDifficulty);

  void _backToPicker() {
    GameWrapper.of(context).restartGame();
    setState(() {
      _activeDifficulty = null;
      _won = false;
      _continueAfterWin = false;
      _gameOver = false;
      _score = 0;
    });
  }

  // ── Tile spawning ────────────────────────────────────────────────────────

  List<_Tile> _spawnNewTile(List<_Tile> existing, {double? twoProb}) {
    final occupied = <String>{};
    for (final t in existing) {
      if (!t.mergedOut) occupied.add('${t.row},${t.col}');
    }
    final empties = <(int, int)>[];
    for (int r = 0; r < _kN; r++) {
      for (int c = 0; c < _kN; c++) {
        if (!occupied.contains('$r,$c')) empties.add((r, c));
      }
    }
    if (empties.isEmpty) return [];
    final (r, c) = empties[_rng.nextInt(empties.length)];
    final prob = twoProb ?? 0.9;
    final value = _rng.nextDouble() < prob ? 2 : 4;
    return [_Tile(id: _nextId++, value: value, row: r, col: c, justSpawned: true)];
  }

  // ── Slide logic ───────────────────────────────────────────────────────────

  (List<_Tile>, int, bool) _slideLeft(List<_Tile> tiles) {
    final result = <_Tile>[];
    int score = 0;
    bool moved = false;

    for (int row = 0; row < _kN; row++) {
      final rowTiles = tiles.where((t) => t.row == row && !t.mergedOut).toList()
        ..sort((a, b) => a.col.compareTo(b.col));

      int targetCol = 0;
      int i = 0;
      while (i < rowTiles.length) {
        final tile = rowTiles[i];
        if (i + 1 < rowTiles.length && tile.value == rowTiles[i + 1].value) {
          final merged = tile..value = tile.value * 2;
          if (merged.col != targetCol || merged.row != row) moved = true;
          merged.col = targetCol;
          merged.row = row;
          result.add(merged);

          final loser = rowTiles[i + 1];
          if (loser.col != targetCol || loser.row != row) moved = true;
          loser.col = targetCol;
          loser.row = row;
          loser.mergedOut = true;
          result.add(loser);

          score += merged.value;
          i += 2;
        } else {
          if (tile.col != targetCol || tile.row != row) moved = true;
          tile.col = targetCol;
          tile.row = row;
          result.add(tile);
          i++;
        }
        targetCol++;
      }
    }
    return (result, score, moved);
  }

  (List<_Tile>, int, bool) _slideRight(List<_Tile> tiles) {
    final result = <_Tile>[];
    int score = 0;
    bool moved = false;

    for (int row = 0; row < _kN; row++) {
      final rowTiles = tiles.where((t) => t.row == row && !t.mergedOut).toList()
        ..sort((a, b) => b.col.compareTo(a.col));

      int targetCol = _kN - 1;
      int i = 0;
      while (i < rowTiles.length) {
        final tile = rowTiles[i];
        if (i + 1 < rowTiles.length && tile.value == rowTiles[i + 1].value) {
          final merged = tile..value = tile.value * 2;
          if (merged.col != targetCol || merged.row != row) moved = true;
          merged.col = targetCol;
          merged.row = row;
          result.add(merged);

          final loser = rowTiles[i + 1];
          if (loser.col != targetCol || loser.row != row) moved = true;
          loser.col = targetCol;
          loser.row = row;
          loser.mergedOut = true;
          result.add(loser);

          score += merged.value;
          i += 2;
        } else {
          if (tile.col != targetCol || tile.row != row) moved = true;
          tile.col = targetCol;
          tile.row = row;
          result.add(tile);
          i++;
        }
        targetCol--;
      }
    }
    return (result, score, moved);
  }

  (List<_Tile>, int, bool) _slideUp(List<_Tile> tiles) {
    final result = <_Tile>[];
    int score = 0;
    bool moved = false;

    for (int col = 0; col < _kN; col++) {
      final colTiles = tiles.where((t) => t.col == col && !t.mergedOut).toList()
        ..sort((a, b) => a.row.compareTo(b.row));

      int targetRow = 0;
      int i = 0;
      while (i < colTiles.length) {
        final tile = colTiles[i];
        if (i + 1 < colTiles.length && tile.value == colTiles[i + 1].value) {
          final merged = tile..value = tile.value * 2;
          if (merged.row != targetRow || merged.col != col) moved = true;
          merged.row = targetRow;
          merged.col = col;
          result.add(merged);

          final loser = colTiles[i + 1];
          if (loser.row != targetRow || loser.col != col) moved = true;
          loser.row = targetRow;
          loser.col = col;
          loser.mergedOut = true;
          result.add(loser);

          score += merged.value;
          i += 2;
        } else {
          if (tile.row != targetRow || tile.col != col) moved = true;
          tile.row = targetRow;
          tile.col = col;
          result.add(tile);
          i++;
        }
        targetRow++;
      }
    }
    return (result, score, moved);
  }

  (List<_Tile>, int, bool) _slideDown(List<_Tile> tiles) {
    final result = <_Tile>[];
    int score = 0;
    bool moved = false;

    for (int col = 0; col < _kN; col++) {
      final colTiles = tiles.where((t) => t.col == col && !t.mergedOut).toList()
        ..sort((a, b) => b.row.compareTo(a.row));

      int targetRow = _kN - 1;
      int i = 0;
      while (i < colTiles.length) {
        final tile = colTiles[i];
        if (i + 1 < colTiles.length && tile.value == colTiles[i + 1].value) {
          final merged = tile..value = tile.value * 2;
          if (merged.row != targetRow || merged.col != col) moved = true;
          merged.row = targetRow;
          merged.col = col;
          result.add(merged);

          final loser = colTiles[i + 1];
          if (loser.row != targetRow || loser.col != col) moved = true;
          loser.row = targetRow;
          loser.col = col;
          loser.mergedOut = true;
          result.add(loser);

          score += merged.value;
          i += 2;
        } else {
          if (tile.row != targetRow || tile.col != col) moved = true;
          tile.row = targetRow;
          tile.col = col;
          result.add(tile);
          i++;
        }
        targetRow--;
      }
    }
    return (result, score, moved);
  }

  bool _isGameOver(List<_Tile> tiles) {
    // Board full?
    final occupied = <String>{};
    for (final t in tiles) {
      if (!t.mergedOut) occupied.add('${t.row},${t.col}');
    }
    if (occupied.length < _kN * _kN) return false;

    // Any adjacent merge possible?
    for (final t in tiles) {
      if (t.mergedOut) continue;
      for (final other in tiles) {
        if (other.mergedOut || other.id == t.id) continue;
        if (other.value == t.value) {
          if ((other.row == t.row && (other.col - t.col).abs() == 1) ||
              (other.col == t.col && (other.row - t.row).abs() == 1)) {
            return false;
          }
        }
      }
    }
    return true;
  }

  void _handleSwipeDirection(String dir) {
    if (_activeDifficulty == null || _gameOver) return;

    final (slidResult, gained, moved) = switch (dir) {
      'left'  => _slideLeft(List.from(_tiles)),
      'right' => _slideRight(List.from(_tiles)),
      'up'    => _slideUp(List.from(_tiles)),
      _       => _slideDown(List.from(_tiles)),
    };

    if (!moved) return;

    final diff = _activeDifficulty!;
    final spawned = _spawnNewTile(slidResult, twoProb: diff.twoProb);
    final allTiles = [...slidResult, ...spawned];

    final newScore = _score + gained;
    if (newScore > _bestScore) _bestScore = newScore;
    ScoreService().saveScore(kNumberMergeGameId, newScore, subKey: diff.subKey);
    if (gained > 0) AudioService().playScore();

    setState(() {
      _tiles = allTiles;
      _score = newScore;
    });

    GameWrapper.of(context).updateScore(newScore);

    if (!_won && allTiles.any((t) => !t.mergedOut && t.value >= diff.target)) {
      setState(() => _won = true);
    }

    // Cleanup after animation
    Future.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      setState(() {
        _tiles.removeWhere((t) => t.mergedOut);
        for (final t in _tiles) {
          t.justSpawned = false;
        }
      });

      if (_isGameOver(_tiles)) {
        setState(() => _gameOver = true);
        GameWrapper.of(context).endGame();
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_activeDifficulty == null) {
      return _buildPicker();
    }
    return _buildGame();
  }

  // ════════════════════════════════════════════════════════════════
  // MODE PICKER — uses GamePickerScaffold
  // ════════════════════════════════════════════════════════════════

  Widget _buildPicker() {
    return GamePickerScaffold(
      bgColorTop: _kBgTop,
      bgColorBottom: _kBgBot,
      bgPainter: _MergeBgPainter(),
      iconRingColors: const [_kGolden, _kOrange, _kGolden],
      iconChild: Container(
        decoration: BoxDecoration(
          color: _kGolden.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text(
            '2048',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _kGolden,
              letterSpacing: -1,
              height: 1,
            ),
          ),
        ),
      ),
      title: '2048 Merge',
      subtitle: 'Slide • Merge • Reach the goal',
      onBack: () => context.pop(),
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHelp: _showHelp,
      onHowToPlay: _showHelp,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DifficultyCard(
            selected: _pickerDifficulty,
            onChanged: (d) => setState(() => _pickerDifficulty = d),
          ),
          const SizedBox(height: 12),
          _PlayButton(
            difficulty: _pickerDifficulty,
            onTap: () => _startGame(_pickerDifficulty),
          ).animate()
           .fadeIn(delay: 280.ms, duration: 320.ms)
           .slideY(begin: 0.08, end: 0, duration: 320.ms),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // GAME VIEW
  // ════════════════════════════════════════════════════════════════

  Widget _buildGame() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kBgTop, _kBgBot],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: _MergeBgPainter(),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildGameHud(),
                const SizedBox(height: 8),
                Expanded(child: _buildBoardArea()),
                if (_won && !_continueAfterWin) _buildWinBanner(),
                if (_gameOver) _buildGameOverBanner(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameHud() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          _HudBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: _backToPicker),
          const SizedBox(width: 8),
          const _Logo2048(),
          const Spacer(),
          _ScoreChip(label: 'SCORE', value: _score),
          const SizedBox(width: 6),
          _ScoreChip(label: 'BEST', value: _bestScore),
          const SizedBox(width: 8),
          _HudBtn(icon: Icons.refresh_rounded, onTap: _newGame),
        ],
      ),
    );
  }

  Widget _buildBoardArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AspectRatio(
        aspectRatio: 1,
        child: GestureDetector(
          onPanStart: (details) {
            _panStart = details.globalPosition;
          },
          onPanEnd: (details) {
            if (_panStart == null) return;
            final v = details.velocity.pixelsPerSecond;
            final dx = v.dx.abs();
            final dy = v.dy.abs();
            if (dx < 50 && dy < 50) {
              _panStart = null;
              return;
            }
            if (dx > dy) {
              _handleSwipeDirection(v.dx > 0 ? 'right' : 'left');
            } else {
              _handleSwipeDirection(v.dy > 0 ? 'down' : 'up');
            }
            _panStart = null;
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.maxWidth;
              const padding = 8.0;
              const gap = 8.0;
              const n = _kN;
              final cellSize = (side - 2 * padding - (n - 1) * gap) / n;

              double tileLeft(int col) => padding + col * (cellSize + gap);
              double tileTop(int row) => padding + row * (cellSize + gap);

              return Container(
                width: side,
                height: side,
                decoration: BoxDecoration(
                  color: const Color(0xFFBBADA0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    // Static empty cell grid
                    Padding(
                      padding: const EdgeInsets.all(padding),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(n, (r) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(n, (c) => Container(
                            width: cellSize,
                            height: cellSize,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCDC1B4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )),
                        )),
                      ),
                    ),
                    // Animated tiles
                    ..._tiles.map((tile) {
                      final style = _styleFor(tile.value);
                      Widget tileWidget = Container(
                        width: cellSize,
                        height: cellSize,
                        decoration: BoxDecoration(
                          color: style.bg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            '${tile.value}',
                            style: TextStyle(
                              color: style.fg,
                              fontSize: _tileFont(tile.value),
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      );

                      if (tile.justSpawned) {
                        tileWidget = tileWidget
                            .animate()
                            .scale(
                              begin: Offset.zero,
                              end: const Offset(1, 1),
                              duration: 180.ms,
                              curve: Curves.easeOutBack,
                            );
                      }
                      if (tile.mergedOut) {
                        tileWidget = Opacity(opacity: 0.0, child: tileWidget);
                      }

                      return AnimatedPositioned(
                        key: ValueKey(tile.id),
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.easeInOut,
                        left: tileLeft(tile.col),
                        top: tileTop(tile.row),
                        width: cellSize,
                        height: cellSize,
                        child: tileWidget,
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWinBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kGolden,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '🎉  You reached the target!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _continueAfterWin = true),
            child: const Text(
              'Keep going →',
              style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13,
                decoration: TextDecoration.underline, decorationColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildGameOverBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF9F6B6B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '😢  No moves left! Score: ',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          Text(
            '$_score',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _newGame,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _backToPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: const Color(0xFF9F6B6B),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOutCubic);
  }
}

// ════════════════════════════════════════════════════════════════
// PICKER SUB-WIDGETS
// ════════════════════════════════════════════════════════════════

class _DifficultyCard extends StatelessWidget {
  final _Difficulty selected;
  final ValueChanged<_Difficulty> onChanged;
  const _DifficultyCard({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kGolden.withValues(alpha: 0.14),
            blurRadius: 18, offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _kGolden.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune_rounded, size: 18, color: _kGolden),
              ),
              const SizedBox(width: 10),
              const Text(
                'Difficulty',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kTextDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: _Difficulty.values.map((d) {
              final isSelected = d == selected;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: d != _Difficulty.hard ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => onChanged(d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? d.color.withValues(alpha: 0.15)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: d.color, width: 2)
                            : Border.all(color: Colors.transparent, width: 2),
                      ),
                      child: Column(
                        children: [
                          Text(d.emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(height: 4),
                          Text(
                            d.label,
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800,
                              color: isSelected ? d.color : _kTextMid,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.flag_rounded, size: 14, color: selected.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    selected.desc,
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: selected.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 160.ms, duration: 300.ms)
     .slideY(begin: 0.06, end: 0, duration: 300.ms);
  }
}

class _PlayButton extends StatefulWidget {
  final _Difficulty difficulty;
  final VoidCallback onTap;
  const _PlayButton({required this.difficulty, required this.onTap});

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.difficulty.color;
    final lighter = Color.lerp(color, Colors.white, 0.25)!;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, lighter],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.38),
                blurRadius: 16, offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Play Classic',
                      style: TextStyle(
                        color: Colors.white, fontSize: 17,
                        fontWeight: FontWeight.w800, letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      '${widget.difficulty.emoji}  ${widget.difficulty.label}  ·  Target ${widget.difficulty.target}',
                      style: const TextStyle(
                        color: Colors.white70, fontSize: 11,
                        fontWeight: FontWeight.w600, letterSpacing: 0.3,
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
  }
}

// ════════════════════════════════════════════════════════════════
// GAME HUD SUB-WIDGETS
// ════════════════════════════════════════════════════════════════

class _Logo2048 extends StatelessWidget {
  const _Logo2048();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _kGolden,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        '2048',
        style: TextStyle(
          color: Colors.white, fontWeight: FontWeight.w900,
          fontSize: 18, height: 1, letterSpacing: -0.5,
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final int value;
  const _ScoreChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFBBADA0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFEEE4DA), fontSize: 8,
              fontWeight: FontWeight.w700, letterSpacing: 1,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
              child: child,
            ),
            child: Text(
              '$value',
              key: ValueKey<int>(value),
              style: const TextStyle(
                color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w900, height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HudBtn({required this.icon, required this.onTap});

  @override
  State<_HudBtn> createState() => _HudBtnState();
}

class _HudBtnState extends State<_HudBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFBBADA0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(widget.icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// BACKGROUND PAINTER
// ════════════════════════════════════════════════════════════════

class _MergeBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final items = [
      ('2',  Color(0xFFEEE4DA), Offset(size.width * 0.08, size.height * 0.09)),
      ('4',  Color(0xFFEDE0C8), Offset(size.width * 0.82, size.height * 0.07)),
      ('8',  Color(0xFFF2B179), Offset(size.width * 0.18, size.height * 0.84)),
      ('16', Color(0xFFF59563), Offset(size.width * 0.75, size.height * 0.82)),
      ('64', Color(0xFFF65E3B), Offset(size.width * 0.88, size.height * 0.45)),
      ('2',  Color(0xFFEEE4DA), Offset(size.width * 0.04, size.height * 0.55)),
      ('4',  Color(0xFFEDE0C8), Offset(size.width * 0.60, size.height * 0.93)),
      ('8',  Color(0xFFF2B179), Offset(size.width * 0.40, size.height * 0.05)),
    ];

    RRect rrect(Offset center, double sz) =>
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: sz, height: sz),
          Radius.circular(sz * 0.18),
        );

    for (final (label, color, center) in items) {
      const tileSize = 52.0;
      canvas.drawRRect(
        rrect(center, tileSize),
        Paint()..color = color.withValues(alpha: 0.25),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: label.length > 1 ? 14.0 : 18.0,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF776E65).withValues(alpha: 0.30),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        center - Offset(tp.width / 2, tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
