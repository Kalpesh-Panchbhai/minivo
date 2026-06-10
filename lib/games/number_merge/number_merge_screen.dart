import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

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
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/rewarded_continue_action.dart';
import '../shared/rewarded_undo_button.dart';
import 'number_merge_stats.dart';
import 'number_merge_tutorial.dart';

// ── Picker palette (warm cream / lavender, mirrors TicTacToe's tonal feel) ──
const Color _kBgTop    = Color(0xFFFFF9F5);
const Color _kBgBot    = Color(0xFFF8F5FF);
const Color _kTextDark = Color(0xFF1C1B4B);

// ── 2048 brand colors ──────────────────────────────────────────────────────
const Color _kGolden = Color(0xFFEDC22E);
const Color _kOrange = Color(0xFFF67C5F);

// ── Difficulty palette ─────────────────────────────────────────────────────
const Color _kEasyColor   = Color(0xFF22C55E); // green
const Color _kMediumColor = Color(0xFFF59E0B); // amber
const Color _kHardColor   = Color(0xFFEF4444); // red

// ── Board palette (original 2048) ──────────────────────────────────────────
const Color _kBoardBg   = Color(0xFFBBADA0);
const Color _kEmptyCell = Color(0xFFCDC1B4);

// ── Tile color palette (original 2048) ─────────────────────────────────────
const Map<int, _TileStyle> _kTileStyles = {
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
  Color  get color   => [_kEasyColor, _kMediumColor, _kHardColor][index];
  int    get target  => [1024, 2048, 4096][index];
  double get twoProb => [0.90, 0.80, 0.65][index];
  String get subKey  => ['easy', 'medium', 'hard'][index];
  String get hint =>
      ['Reach 1024 — gentle climb.',
       'Reach 2048 — the classic challenge.',
       'Reach 4096 — only for the brave.'][index];
  DifficultyKind get kind => [
        DifficultyKind.easy,
        DifficultyKind.medium,
        DifficultyKind.hard,
      ][index];

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

const int _kN = 4; // 4×4 board

// ════════════════════════════════════════════════════════════════
// Root screen — picker → game transition
// ════════════════════════════════════════════════════════════════

class NumberMergeScreen extends StatefulWidget {
  const NumberMergeScreen({super.key});

  @override
  State<NumberMergeScreen> createState() => _NumberMergeScreenState();
}

class _NumberMergeScreenState extends State<NumberMergeScreen> {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.values[DifficultyKind.defaultIndex];

  bool _isFavorite = false;

  // Board state
  final _rng = math.Random();
  List<_Tile> _tiles = [];
  int _nextId = 0;
  int _score = 0;
  int _bestScore = 0;
  bool _isNewBestScore = false;
  bool _won = false;
  bool _continueAfterWin = false;
  bool _gameOver = false;

  // Undo support (1 per game)
  bool _undoUsed = false;
  bool _inUndoWindow = false;
  List<_Tile>? _prevTiles;
  int? _prevScore;

  // Swipe gesture state — track BOTH velocity (fast flick) and cumulative
  // distance (slow drag) so deliberate touches register reliably.
  double _dragDx = 0;
  double _dragDy = 0;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kNumberMergeGameId);
  }

  int _bestFor(_Difficulty d) =>
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
      steps: numberMergeSteps(),
      gameId: kNumberMergeGameId,
    );
  }

  // ── Game start / restart ─────────────────────────────────────────────────

  void _startGame(_Difficulty diff) {
    final tiles = <_Tile>[];
    _nextId = 0;
    tiles.addAll(_spawnNewTile(tiles));
    tiles.addAll(_spawnNewTile(tiles));

    setState(() {
      _activeDifficulty = diff;
      _pickerDifficulty = diff;
      _tiles = tiles;
      _score = 0;
      _bestScore = _bestFor(diff);
      _isNewBestScore = false;
      _won = false;
      _continueAfterWin = false;
      _gameOver = false;
      _undoUsed = false;
      _inUndoWindow = false;
      _prevTiles = null;
      _prevScore = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GameWrapper.of(context).setDifficultyAndMode(difficulty: diff.label, subKey: diff.subKey);
        GameWrapper.of(context).startGame();
        GameWrapper.of(context).updateScore(0);
      }
    });
  }

  void _newGame() => _startGame(_activeDifficulty ?? _pickerDifficulty);

  void _backOrHome() {
    final wrapper = GameWrapper.of(context);
    wrapper.handleExit(() {
      if (context.canPop()) context.pop(); else context.go('/home');
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
          if (tile.col != targetCol || tile.row != row) moved = true;
          tile
            ..value = tile.value * 2
            ..col = targetCol
            ..row = row;
          result.add(tile);

          final loser = rowTiles[i + 1];
          if (loser.col != targetCol || loser.row != row) moved = true;
          loser
            ..col = targetCol
            ..row = row
            ..mergedOut = true;
          result.add(loser);

          score += tile.value;
          i += 2;
        } else {
          if (tile.col != targetCol || tile.row != row) moved = true;
          tile
            ..col = targetCol
            ..row = row;
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
          if (tile.col != targetCol || tile.row != row) moved = true;
          tile
            ..value = tile.value * 2
            ..col = targetCol
            ..row = row;
          result.add(tile);

          final loser = rowTiles[i + 1];
          if (loser.col != targetCol || loser.row != row) moved = true;
          loser
            ..col = targetCol
            ..row = row
            ..mergedOut = true;
          result.add(loser);

          score += tile.value;
          i += 2;
        } else {
          if (tile.col != targetCol || tile.row != row) moved = true;
          tile
            ..col = targetCol
            ..row = row;
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
          if (tile.row != targetRow || tile.col != col) moved = true;
          tile
            ..value = tile.value * 2
            ..row = targetRow
            ..col = col;
          result.add(tile);

          final loser = colTiles[i + 1];
          if (loser.row != targetRow || loser.col != col) moved = true;
          loser
            ..row = targetRow
            ..col = col
            ..mergedOut = true;
          result.add(loser);

          score += tile.value;
          i += 2;
        } else {
          if (tile.row != targetRow || tile.col != col) moved = true;
          tile
            ..row = targetRow
            ..col = col;
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
          if (tile.row != targetRow || tile.col != col) moved = true;
          tile
            ..value = tile.value * 2
            ..row = targetRow
            ..col = col;
          result.add(tile);

          final loser = colTiles[i + 1];
          if (loser.row != targetRow || loser.col != col) moved = true;
          loser
            ..row = targetRow
            ..col = col
            ..mergedOut = true;
          result.add(loser);

          score += tile.value;
          i += 2;
        } else {
          if (tile.row != targetRow || tile.col != col) moved = true;
          tile
            ..row = targetRow
            ..col = col;
          result.add(tile);
          i++;
        }
        targetRow--;
      }
    }
    return (result, score, moved);
  }

  bool _isGameOver(List<_Tile> tiles) {
    final occupied = <String>{};
    for (final t in tiles) {
      if (!t.mergedOut) occupied.add('${t.row},${t.col}');
    }
    if (occupied.length < _kN * _kN) return false;

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

  List<_Tile> _deepCopyTiles(List<_Tile> tiles) =>
      tiles.map((t) => _Tile(id: t.id, value: t.value, row: t.row, col: t.col)).toList();

  void _handleSwipeDirection(String dir) {
    if (_activeDifficulty == null || _gameOver) return;
    if (_inUndoWindow) _onUndoExpired();

    final snapshotTiles = _deepCopyTiles(_tiles);
    final snapshotScore = _score;

    final (slid, gained, moved) = switch (dir) {
      'left'  => _slideLeft(List.from(_tiles)),
      'right' => _slideRight(List.from(_tiles)),
      'up'    => _slideUp(List.from(_tiles)),
      _       => _slideDown(List.from(_tiles)),
    };

    if (!moved) return;

    final diff = _activeDifficulty!;
    final spawned = _spawnNewTile(slid, twoProb: diff.twoProb);
    final allTiles = [...slid, ...spawned];

    final newScore = _score + gained;
    if (newScore > _bestScore) {
      _bestScore = newScore;
      _isNewBestScore = true;
    }
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
        return;
      }
      final undoAvailable = !_undoUsed && AdsService().isRewardedReady;
      if (undoAvailable) {
        setState(() {
          _inUndoWindow = true;
          _prevTiles = snapshotTiles;
          _prevScore = snapshotScore;
        });
      }
    });
  }

  void _onUndoExpired() {
    if (!mounted || !_inUndoWindow) return;
    setState(() {
      _inUndoWindow = false;
      _prevTiles = null;
      _prevScore = null;
    });
  }

  void _performUndo() {
    final prev = _prevTiles;
    final prevS = _prevScore;
    if (prev == null || prevS == null) return;
    setState(() {
      _tiles = prev;
      _score = prevS;
      _undoUsed = true;
      _inUndoWindow = false;
      _prevTiles = null;
      _prevScore = null;
    });
    GameWrapper.of(context).updateScore(prevS);
  }

  void _continueGame() {
    final sorted = _tiles.where((t) => !t.mergedOut).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final toRemove = sorted.take(math.min(4, sorted.length)).map((t) => t.id).toSet();
    setState(() {
      _tiles.removeWhere((t) => toRemove.contains(t.id));
      _gameOver = false;
    });
    GameWrapper.of(context).continueAfterGameOver();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_activeDifficulty == null) return _buildPicker();
    return _buildGame();
  }

  // ════════════════════════════════════════════════════════════════
  // PICKER
  // ════════════════════════════════════════════════════════════════

  Widget _buildPicker() {
    return GamePickerScaffold(
      bgColorTop: _kBgTop,
      bgColorBottom: _kBgBot,
      animatedBg: AnimatedBackground(
        factory: (t) => _MergeBgPainter(t),
        period: const Duration(seconds: 10),
      ),
      iconRingColors: const [_kGolden, _kOrange, _kGolden],
      iconChild: ClipOval(
        child: GameRegistry.getById(kNumberMergeGameId)
                ?.buildBrandedLogo(size: 84) ??
            const SizedBox.shrink(),
      ),
      title: '2048 Merge',
      subtitle: 'Slide • Merge • Reach the goal',
      onBack: () => context.pop(),
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kNumberMergeGameId,
      tallThreshold: 860,
      body: _ClassicSection(
        difficulty: _pickerDifficulty,
        onDifficultyChanged: (d) => setState(() => _pickerDifficulty = d),
        onPlay: () => _startGame(_pickerDifficulty),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // GAME VIEW
  // ════════════════════════════════════════════════════════════════

  Widget _buildGame() {
    if (_gameOver) return _buildGameOverScreen();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        _dragDx = 0;
        _dragDy = 0;
      },
      onPanUpdate: (d) {
        _dragDx += d.delta.dx;
        _dragDy += d.delta.dy;
      },
      onPanEnd: (d) {
        final v = d.velocity.pixelsPerSecond;
        final dx = math.max(v.dx.abs() / 4, _dragDx.abs());
        final dy = math.max(v.dy.abs() / 4, _dragDy.abs());
        if (dx < 24 && dy < 24) return;

        final accDx = _dragDx;
        final accDy = _dragDy;
        final velX = v.dx;
        final velY = v.dy;

        if (dx > dy) {
          final velSignal = v.dx.abs() / 4;
          final distSignal = _dragDx.abs();
          final goRight = (velSignal > distSignal) ? (velX > 0) : (accDx > 0);
          _handleSwipeDirection(goRight ? 'right' : 'left');
        } else {
          final velSignal = v.dy.abs() / 4;
          final distSignal = _dragDy.abs();
          final goDown = (velSignal > distSignal) ? (velY > 0) : (accDy > 0);
          _handleSwipeDirection(goDown ? 'down' : 'up');
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kBgTop, _kBgBot],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBackground(
                factory: (t) => _MergeBgPainter(t),
                period: const Duration(seconds: 10),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  _buildGameHud(),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: _inUndoWindow
                        ? RewardedUndoButton(
                            key: ValueKey('undo_$_prevScore'),
                            onUndo: _performUndo,
                            onExpired: _onUndoExpired,
                            accentColor: _kGolden,
                          )
                        : const SizedBox.shrink(),
                  ),
                  Expanded(child: Center(child: _buildBoard())),
                  if (_won && !_continueAfterWin) _buildWinBanner(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameHud() {
    return GameHudBar(
      leading: GameBackButton(onTap: _backOrHome),
      centerContent: _ScoreBoardPill(
        difficulty: _activeDifficulty!,
        score: _score,
        best: _bestScore,
      ),
      trailing: GameRestartButton(
        gameName: '2048 Merge',
        accentColor: _kGolden,
        onRestart: _newGame,
      ),
    );
  }

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, c) {
        final side = math.min(c.maxWidth - 24, c.maxHeight);
        return SizedBox(
          width: side,
          height: side,
          child: _Board(
            side: side,
            tiles: _tiles,
          ),
        );
      },
    );
  }

  Widget _buildWinBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kGolden, _kOrange],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _kGolden.withValues(alpha: 0.40),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '🎉  Target reached!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _continueAfterWin = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Keep going →',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 320.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildGameOverScreen() {
    final difficulty = _activeDifficulty!;
    final continueAction = rewardedContinueAction(
      context: context,
      label: 'Watch Ad to Continue',
      color: difficulty.color,
      onRewarded: _continueGame,
    );
    return game_result.GenericGameResultScreen(
      gameId: kNumberMergeGameId,
      score: _score,
      headline: 'Game Over',
      badgeContent: '😢',
      badgeColor: difficulty.color,
      showNewBestBadge: _isNewBestScore,
      actions: [
        ?continueAction,
        game_result.GameResultAction(
          label: 'Play Again',
          icon: Icons.refresh_rounded,
          onTap: _newGame,
          filled: continueAction == null,
          color: difficulty.color,
          actionId: 'play_again',
        ),
        game_result.GameResultAction(
          label: 'Change Mode',
          icon: Icons.tune_rounded,
          onTap: _backOrHome,
          filled: false,
          actionId: 'change_mode',
        ),
        game_result.GameResultAction(
          label: 'Home',
          icon: Icons.home_rounded,
          onTap: () => context.pop(),
          actionId: 'home',
          filled: false,
        ),
      ],
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(
            label: 'SCORE',
            value: _score,
            color: difficulty.color,
          ),
          game_result.StatItem(
            label: 'BEST',
            value: _bestScore,
            color: const Color(0xFF8B7BA7),
          ),
        ],
      ),
    );
  }

}

// ════════════════════════════════════════════════════════════════
// PICKER — Classic section (difficulty card + attached play button)
// ════════════════════════════════════════════════════════════════

class _ClassicSection extends StatelessWidget {
  final _Difficulty difficulty;
  final ValueChanged<_Difficulty> onDifficultyChanged;
  final VoidCallback onPlay;

  const _ClassicSection({
    required this.difficulty,
    required this.onDifficultyChanged,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return GameSinglePickerBody(
      difficulties: _Difficulty.values.map((d) => GameDifficultyData(
        label: d.label,
        color: d.color,
        kind: d.kind,
        hint: d.hint,
        bestScore: ScoreService().getHighScore(kNumberMergeGameId, subKey: d.subKey),
        bestLabel: (s) => 'Best $s',
      )).toList(),
      activeIndex: _Difficulty.values.indexOf(difficulty),
      onChanged: (i) => onDifficultyChanged(_Difficulty.values[i]),
      playLabel: 'Play Classic',
      playSubLabel: 'Target ${difficulty.target}',
      onPlay: onPlay,
      accentColor: _kGolden,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// GAME — board + HUD widgets
// ════════════════════════════════════════════════════════════════

class _Board extends StatelessWidget {
  final double side;
  final List<_Tile> tiles;

  const _Board({
    required this.side,
    required this.tiles,
  });

  @override
  Widget build(BuildContext context) {
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
          color: _kBoardBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Empty cells — precisely positioned so they're always equal size.
            for (int r = 0; r < n; r++)
              for (int c = 0; c < n; c++)
                Positioned(
                  left: tileLeft(c),
                  top: tileTop(r),
                  width: cellSize,
                  height: cellSize,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _kEmptyCell,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
            // Animated tiles — same coordinate system, AnimatedPositioned
            // keyed by stable tile.id so Flutter interpolates per-tile slides.
            for (final tile in tiles)
              AnimatedPositioned(
                key: ValueKey(tile.id),
                duration: const Duration(milliseconds: 130),
                curve: Curves.easeOutCubic,
                left: tileLeft(tile.col),
                top: tileTop(tile.row),
                width: cellSize,
                height: cellSize,
                child: _TileView(tile: tile, cellSize: cellSize),
              ),
          ],
        ),
    );
  }
}

class _TileView extends StatelessWidget {
  final _Tile tile;
  final double cellSize;
  const _TileView({required this.tile, required this.cellSize});

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(tile.value);
    Widget body = Container(
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(6),
        boxShadow: tile.value >= 8
            ? [
                BoxShadow(
                  color: style.bg.withValues(alpha: 0.30),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${tile.value}',
        style: TextStyle(
          color: style.fg,
          fontSize: _tileFont(tile.value),
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: -0.5,
        ),
      ),
    );

    if (tile.justSpawned) {
      body = body.animate().scale(
            begin: const Offset(0, 0),
            end: const Offset(1, 1),
            duration: 180.ms,
            curve: Curves.easeOutBack,
          );
    }
    if (tile.mergedOut) {
      body = Opacity(opacity: 0, child: body);
    }
    return body;
  }
}

// ── ScoreBoard pill — mirrors TicTacToe's tab + pill design ────────────────

class _ScoreBoardPill extends StatelessWidget {
  final _Difficulty difficulty;
  final int score;
  final int best;
  const _ScoreBoardPill({
    required this.difficulty,
    required this.score,
    required this.best,
  });

  @override
  Widget build(BuildContext context) {
    final color = difficulty.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Difficulty tab
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
        // Score + Best pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8475C2).withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _scoreColumn('SCORE', score, color),
              const SizedBox(width: 18),
              Container(
                width: 1,
                height: 28,
                color: const Color(0xFFE2DAEE),
              ),
              const SizedBox(width: 18),
              _scoreColumn('BEST', best, _kTextDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scoreColumn(String label, int value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.85),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Text(
            '$value',
            key: ValueKey<int>(value),
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Decorative background — scattered ghost tiles
// ════════════════════════════════════════════════════════════════

/// Animated 2048 background — scattered tile ghosts gently float (Y-bob),
/// rotate slightly, and pulse opacity. Each tile gets a unique phase so the
/// composition feels organic.
class _MergeBgPainter extends AnimatedBgPainter {
  const _MergeBgPainter(super.t);

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final phase = t * 2 * math.pi;
    final items = <(String, Color, double, double, double)>[
      // (label, color, xRel, yRel, itemPhase)
      ('2',  Color(0xFFEEE4DA), 0.08, 0.09, 0.0),
      ('4',  Color(0xFFEDE0C8), 0.82, 0.07, 0.7),
      ('8',  Color(0xFFF2B179), 0.18, 0.84, 1.4),
      ('16', Color(0xFFF59563), 0.75, 0.82, 2.1),
      ('64', Color(0xFFF65E3B), 0.88, 0.45, 2.8),
      ('2',  Color(0xFFEEE4DA), 0.04, 0.55, 3.5),
      ('4',  Color(0xFFEDE0C8), 0.60, 0.93, 4.2),
      ('8',  Color(0xFFF2B179), 0.40, 0.05, 4.9),
    ];

    for (final (label, color, xRel, yRel, p) in items) {
      const tileSize = 52.0;
      final wave = math.sin(phase + p);
      final yBob = wave * 6.0; // ±6 px float
      final rot = math.sin(phase * 0.7 + p) * 0.10; // ±~6° tilt
      final alphaPulse = 0.22 + math.sin(phase * 1.3 + p) * 0.06;

      final cx = size.width * xRel;
      final cy = size.height * yRel + yBob;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: tileSize,
        height: tileSize,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
      canvas.drawRRect(
        rrect,
        Paint()..color = color.withValues(alpha: alphaPulse.clamp(0.0, 1.0)),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: label.length > 1 ? 14 : 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF776E65).withValues(alpha: 0.30),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }
}
