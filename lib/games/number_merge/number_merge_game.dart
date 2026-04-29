import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../game_wrapper.dart';
import 'number_merge_logic.dart';

// ── Original 2048 color palette ──────────────────────────────────────────────

const _kBoardBg = Color(0xFFBBADA0);
const _kEmptyCell = Color(0xFFCDC1B4);
const _kPageBg = Color(0xFFFAF8EF);
const _kTextDark = Color(0xFF776E65);
const _kTextLight = Color(0xFFF9F6F2);

const Map<int, _TileStyle> _kTileStyles = {
  0:    _TileStyle(_kEmptyCell, Colors.transparent),
  2:    _TileStyle(Color(0xFFEEE4DA), _kTextDark),
  4:    _TileStyle(Color(0xFFEDE0C8), _kTextDark),
  8:    _TileStyle(Color(0xFFF2B179), _kTextLight),
  16:   _TileStyle(Color(0xFFF59563), _kTextLight),
  32:   _TileStyle(Color(0xFFF67C5F), _kTextLight),
  64:   _TileStyle(Color(0xFFF65E3B), _kTextLight),
  128:  _TileStyle(Color(0xFFEDCF72), _kTextLight),
  256:  _TileStyle(Color(0xFFEDCC61), _kTextLight),
  512:  _TileStyle(Color(0xFFEDC850), _kTextLight),
  1024: _TileStyle(Color(0xFFEDC53F), _kTextLight),
  2048: _TileStyle(Color(0xFFEDC22E), _kTextLight),
};

_TileStyle _styleFor(int value) =>
    _kTileStyles[value] ?? const _TileStyle(Color(0xFF3C3A32), _kTextLight);

class _TileStyle {
  final Color bg;
  final Color fg;
  const _TileStyle(this.bg, this.fg);
}

// ── Font size heuristic based on digit count ─────────────────────────────────

double _tileFont(int value) {
  if (value < 100) return 32;
  if (value < 1000) return 26;
  if (value < 10000) return 20;
  return 16;
}

// ────────────────────────────────────────────────────────────────────────────
// NumberMergeGame — the actual playfield + custom HUD
// ────────────────────────────────────────────────────────────────────────────

class NumberMergeGame extends StatefulWidget {
  const NumberMergeGame({super.key});

  @override
  State<NumberMergeGame> createState() => _NumberMergeGameState();
}

class _NumberMergeGameState extends State<NumberMergeGame>
    with TickerProviderStateMixin {
  final _rng = Random();

  late MergeBoard _board;
  int _score = 0;
  int _bestScore = 0;

  // Tracks which indices were newly spawned (scale-in animation this frame)
  final Set<int> _spawnedIndices = {};
  // Tracks which indices just merged (pop animation this frame)
  final Set<int> _mergedIndices = {};
  bool _won = false;
  bool _continueAfterWin = false;
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
    var board = MergeBoard.empty();
    board = board.spawnTile(_rng);
    board = board.spawnTile(_rng);
    setState(() {
      _board = board;
      _score = 0;
      _spawnedIndices.clear();
      _mergedIndices.clear();
      _won = false;
      _continueAfterWin = false;
      _gameOver = false;
    });

    // Sync score with GameWrapper if present
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final wrapper = GameWrapper.of(context);
        wrapper.startGame();
        wrapper.updateScore(0);
      }
    });
  }

  void _handleSlide(SlideResult result) {
    if (!result.moved) return;

    final prev = _board.cells;
    final next = result.board;

    // Detect merged tiles (value doubled at a position that was non-zero before)
    final merged = <int>{};
    for (int i = 0; i < 16; i++) {
      if (next[i] != 0 && next[i] != prev[i] && prev[i] != 0) {
        merged.add(i);
      }
    }

    // Spawn a new tile
    final spawned = MergeBoard.from(next).spawnTile(_rng);
    final spawnedIdx = <int>{};
    for (int i = 0; i < 16; i++) {
      if (spawned.cells[i] != 0 && next[i] == 0) spawnedIdx.add(i);
    }

    final newScore = _score + result.scoreGained;

    // Persist high score
    if (newScore > _bestScore) _bestScore = newScore;

    setState(() {
      _board = spawned;
      _score = newScore;
      _spawnedIndices
        ..clear()
        ..addAll(spawnedIdx);
      _mergedIndices
        ..clear()
        ..addAll(merged);
    });

    // Update GameWrapper score
    final wrapper = GameWrapper.of(context);
    wrapper.updateScore(newScore);

    // Check win condition
    if (!_won && spawned.hasWon) {
      setState(() => _won = true);
    }

    // Check game over
    if (spawned.isGameOver) {
      setState(() => _gameOver = true);
      wrapper.endGame();
    }
  }

  void _onSwipe(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    final dx = velocity.dx.abs();
    final dy = velocity.dy.abs();

    // Require minimum velocity to avoid accidental slides
    if (dx < 150 && dy < 150) return;

    SlideResult result;
    if (dx > dy) {
      result = velocity.dx > 0 ? _board.slideRight() : _board.slideLeft();
    } else {
      result = velocity.dy > 0 ? _board.slideDown() : _board.slideUp();
    }
    _handleSlide(result);
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    SlideResult? result;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        result = _board.slideLeft();
      case LogicalKeyboardKey.arrowRight:
        result = _board.slideRight();
      case LogicalKeyboardKey.arrowUp:
        result = _board.slideUp();
      case LogicalKeyboardKey.arrowDown:
        result = _board.slideDown();
    }
    if (result != null) _handleSlide(result);
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _onKey,
      child: Container(
        color: _kPageBg,
        child: SafeArea(
          child: Column(
            children: [
              _buildHud(),
              const SizedBox(height: 8),
              Expanded(child: _buildBoardArea()),
              if (_won && !_continueAfterWin) _buildWinBanner(),
              if (_gameOver) _buildGameOverBanner(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── HUD ───────────────────────────────────────────────────────────────────

  Widget _buildHud() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Row(
        children: [
          // Back button
          _HudButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => context.go('/home'),
          ),
          const SizedBox(width: 8),
          // Title logo
          const _GameLogo2048(),
          const Spacer(),
          // Score chips
          _ScoreChip(label: 'SCORE', value: _score),
          const SizedBox(width: 6),
          _ScoreChip(label: 'BEST', value: _bestScore),
          const SizedBox(width: 8),
          // New game button
          _HudButton(
            icon: Icons.refresh_rounded,
            onTap: _newGame,
          ),
        ],
      ),
    );
  }

  // ── Board ─────────────────────────────────────────────────────────────────

  Widget _buildBoardArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AspectRatio(
        aspectRatio: 1,
        child: GestureDetector(
          onHorizontalDragEnd: _onSwipe,
          onVerticalDragEnd: _onSwipe,
          child: Container(
            decoration: BoxDecoration(
              color: _kBoardBg,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: _buildGrid(),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: kBoardSize,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 16,
      itemBuilder: (_, index) => _buildTile(index),
    );
  }

  Widget _buildTile(int index) {
    final value = _board.cells[index];
    final style = _styleFor(value);
    final isSpawned = _spawnedIndices.contains(index);
    final isMerged = _mergedIndices.contains(index);

    Widget tile = Container(
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: value == 0
          ? const SizedBox.shrink()
          : Center(
              child: Text(
                '$value',
                style: TextStyle(
                  color: style.fg,
                  fontSize: _tileFont(value),
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
    );

    if (isSpawned) {
      tile = tile
          .animate()
          .scale(
            begin: const Offset(0, 0),
            end: const Offset(1, 1),
            duration: 180.ms,
            curve: Curves.easeOutBack,
          );
    } else if (isMerged) {
      tile = tile
          .animate()
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.15, 1.15),
            duration: 100.ms,
          )
          .then()
          .scale(
            begin: const Offset(1.15, 1.15),
            end: const Offset(1, 1),
            duration: 100.ms,
          );
    }

    return tile;
  }

  // ── Win banner ────────────────────────────────────────────────────────────

  Widget _buildWinBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEDC22E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text(
            '🎉  You reached 2048!',
            style: TextStyle(
              color: _kTextLight,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _continueAfterWin = true),
            child: const Text(
              'Keep going →',
              style: TextStyle(
                color: _kTextLight,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                decoration: TextDecoration.underline,
                decorationColor: _kTextLight,
              ),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOutCubic);
  }

  // ── Game over banner ──────────────────────────────────────────────────────

  Widget _buildGameOverBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF9F6B6B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text(
            '😢  Game Over!',
            style: TextStyle(
              color: _kTextLight,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _newGame,
            child: const Text(
              'Try again →',
              style: TextStyle(
                color: _kTextLight,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                decoration: TextDecoration.underline,
                decorationColor: _kTextLight,
              ),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOutCubic);
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _GameLogo2048 extends StatelessWidget {
  const _GameLogo2048();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEDC22E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        '2048',
        style: TextStyle(
          color: _kTextLight,
          fontWeight: FontWeight.w900,
          fontSize: 18,
          height: 1,
          letterSpacing: -0.5,
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
        color: _kBoardBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFEEE4DA),
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
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
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HudButton({required this.icon, required this.onTap});

  @override
  State<_HudButton> createState() => _HudButtonState();
}

class _HudButtonState extends State<_HudButton> {
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _kBoardBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(widget.icon, size: 20, color: _kTextLight),
        ),
      ),
    );
  }
}
