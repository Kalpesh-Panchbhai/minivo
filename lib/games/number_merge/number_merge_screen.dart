import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/audio_service.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../game_registry.dart';
import '../game_wrapper.dart';
import 'number_merge_logic.dart';
import 'number_merge_stats.dart';

// ── Design tokens (mirrors TicTacToe's palette language) ─────────────────────
const Color _kBgTop    = Color(0xFFFFFBF0);  // warm golden cream
const Color _kBgBot    = Color(0xFFFFF5E0);  // soft warm peach
const Color _kCardBg   = Colors.white;
const Color _kTextDark = Color(0xFF2D2600);  // deep warm brown
const Color _kTextMid  = Color(0xFF9E8B5C);  // muted warm gold

// ── 2048 brand colors ──────────────────────────────────────────────────────
const Color _kGolden = Color(0xFFEDC22E);   // 2048 tile gold
const Color _kOrange = Color(0xFFF67C5F);   // warm orange accent

// ── Difficulty palette ─────────────────────────────────────────────────────
const Color _kEasyColor   = Color(0xFF22C55E);
const Color _kMediumColor = Color(0xFFF59E0B);
const Color _kHardColor   = Color(0xFFEF4444);

// ── Tile color palette (original 2048) ────────────────────────────────────
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
  double get twoProb => [0.90, 0.80, 0.65][index]; // probability of spawning 2 vs 4
  String get subKey  => ['easy', 'medium', 'hard'][index];
  String get desc    =>
      ['Reach 1024 — great for beginners',
       'Reach 2048 — the classic challenge',
       'Reach 4096 — only for the brave'][index];
}

// ════════════════════════════════════════════════════════════════
// Root screen — handles picker → game transition (mirrors TicTacToeScreen)
// ════════════════════════════════════════════════════════════════

class NumberMergeScreen extends StatefulWidget {
  const NumberMergeScreen({super.key});

  @override
  State<NumberMergeScreen> createState() => _NumberMergeScreenState();
}

class _NumberMergeScreenState extends State<NumberMergeScreen>
    with TickerProviderStateMixin {
  // null = showing picker; non-null = playing
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.medium;

  bool _isFavorite = false;

  // ── Board state ──────────────────────────────────────────────────────────
  final _rng = Random();
  MergeBoard _board = MergeBoard.empty();
  int _score = 0;
  int _bestScore = 0;

  final Set<int> _spawnedIndices = {};
  final Set<int> _mergedIndices  = {};

  bool _won = false;
  bool _continueAfterWin = false;
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kNumberMergeGameId);
    _bestScore = _loadBest(_Difficulty.medium);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

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
    var board = MergeBoard.empty();
    board = board.spawnTile(_rng);
    board = board.spawnTile(_rng);

    setState(() {
      _activeDifficulty = diff;
      _pickerDifficulty = diff;
      _board = board;
      _score = 0;
      _bestScore = _loadBest(diff);
      _spawnedIndices.clear();
      _mergedIndices.clear();
      _won = false;
      _continueAfterWin = false;
      _gameOver = false;
    });

    // Tell GameWrapper we started
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

  // ── Swipe handling ────────────────────────────────────────────────────────

  void _handleSlide(SlideResult result) {
    if (!result.moved) return;
    if (_gameOver) return;

    final prev = _board.cells;
    final next = result.board;

    // Detect merged tiles
    final merged = <int>{};
    for (int i = 0; i < 16; i++) {
      if (next[i] != 0 && next[i] != prev[i] && prev[i] != 0) merged.add(i);
    }

    // Spawn new tile with difficulty-adjusted probability
    final diff = _activeDifficulty!;
    final spawned = _spawnWithProb(MergeBoard.from(next), diff.twoProb);
    final spawnedIdx = <int>{};
    for (int i = 0; i < 16; i++) {
      if (spawned.cells[i] != 0 && next[i] == 0) spawnedIdx.add(i);
    }

    final newScore = _score + result.scoreGained;
    if (newScore > _bestScore) _bestScore = newScore;

    // Persist per-difficulty best
    ScoreService().saveScore(kNumberMergeGameId, newScore, subKey: diff.subKey);

    if (result.scoreGained > 0) AudioService().playScore();

    setState(() {
      _board = spawned;
      _score = newScore;
      _spawnedIndices..clear()..addAll(spawnedIdx);
      _mergedIndices..clear()..addAll(merged);
    });

    GameWrapper.of(context).updateScore(newScore);

    // Win check
    if (!_won && spawned.cells.any((v) => v >= diff.target)) {
      setState(() => _won = true);
    }

    // Game-over check
    if (spawned.isGameOver) {
      setState(() => _gameOver = true);
      GameWrapper.of(context).endGame();
    }
  }

  MergeBoard _spawnWithProb(MergeBoard board, double twoProb) {
    final empty = board.emptyIndices;
    if (empty.isEmpty) return board;
    final index = empty[_rng.nextInt(empty.length)];
    final value = _rng.nextDouble() < twoProb ? 2 : 4;
    final next = List<int>.from(board.cells);
    next[index] = value;
    return MergeBoard.from(next);
  }

  void _onSwipe(DragEndDetails d) {
    if (_activeDifficulty == null || _gameOver) return;
    final v = d.velocity.pixelsPerSecond;
    final dx = v.dx.abs(), dy = v.dy.abs();
    if (dx < 150 && dy < 150) return;
    SlideResult r;
    if (dx > dy) {
      r = v.dx > 0 ? _board.slideRight() : _board.slideLeft();
    } else {
      r = v.dy > 0 ? _board.slideDown() : _board.slideUp();
    }
    _handleSlide(r);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
      child: Stack(
        children: [
          const _MergeBg(),
          SafeArea(
            child: _activeDifficulty == null
                ? _buildPicker()
                : _buildGame(),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // MODE PICKER
  // ════════════════════════════════════════════════════════════════

  Widget _buildPicker() {
    return LayoutBuilder(
      builder: (context, c) {
        final isTall = c.maxHeight >= 800;
        return Column(
          children: [
            _buildPickerHeader(),
            Expanded(
              child: isTall
                  ? _buildPickerBodyTall()
                  : _buildPickerBodyScroll(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPickerHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _NavButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => context.pop()),
          const Spacer(),
          _NavButton(
            icon: Icons.help_outline_rounded,
            onTap: _showHelp,
          ),
          const SizedBox(width: 10),
          _NavButton(
            icon: _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            iconColor: _isFavorite ? const Color(0xFFE85D75) : null,
            onTap: _toggleFavorite,
          ),
        ],
      ),
    );
  }

  Widget _buildPickerBodyTall() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 2),
          const _MergeMascotAndTitle(),
          const Spacer(flex: 3),
          _DifficultyCard(
            selected: _pickerDifficulty,
            onChanged: (d) => setState(() => _pickerDifficulty = d),
          ),
          const SizedBox(height: 12),
          _PlayButton(
            difficulty: _pickerDifficulty,
            onTap: () => _startGame(_pickerDifficulty),
          ).animate().fadeIn(delay: 280.ms, duration: 320.ms)
           .slideY(begin: 0.08, end: 0, duration: 320.ms),
          const SizedBox(height: 6),
          Center(
            child: _HowToPlayLink(onTap: _showHelp),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerBodyScroll() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _MergeMascotAndTitle(),
          const SizedBox(height: 22),
          _DifficultyCard(
            selected: _pickerDifficulty,
            onChanged: (d) => setState(() => _pickerDifficulty = d),
          ),
          const SizedBox(height: 12),
          _PlayButton(
            difficulty: _pickerDifficulty,
            onTap: () => _startGame(_pickerDifficulty),
          ),
          const SizedBox(height: 8),
          Center(child: _HowToPlayLink(onTap: _showHelp)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // GAME VIEW
  // ════════════════════════════════════════════════════════════════

  Widget _buildGame() {
    return Column(
      children: [
        _buildGameHud(),
        const SizedBox(height: 8),
        Expanded(child: _buildBoardArea()),
        if (_won && !_continueAfterWin) _buildWinBanner(),
        if (_gameOver) _buildGameOverBanner(),
        const SizedBox(height: 8),
      ],
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
          _ScoreChip(label: 'BEST',  value: _bestScore),
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
          onHorizontalDragEnd: _onSwipe,
          onVerticalDragEnd: _onSwipe,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFBBADA0),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: kBoardSize,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 16,
              itemBuilder: (_, i) => _buildTile(i),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTile(int index) {
    final value = _board.cells[index];
    final style = _styleFor(value);
    final isSpawned = _spawnedIndices.contains(index);
    final isMerged  = _mergedIndices.contains(index);

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
      tile = tile.animate().scale(
        begin: const Offset(0, 0), end: const Offset(1, 1),
        duration: 180.ms, curve: Curves.easeOutBack,
      );
    } else if (isMerged) {
      tile = tile.animate()
          .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 100.ms)
          .then()
          .scale(begin: const Offset(1.15, 1.15), end: const Offset(1, 1), duration: 100.ms);
    }

    return tile;
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
                style: TextStyle(color: const Color(0xFF9F6B6B), fontWeight: FontWeight.w800, fontSize: 13),
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

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  const _NavButton({required this.icon, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _kGolden.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: iconColor ?? _kTextDark),
      ),
    );
  }
}

class _MergeMascotAndTitle extends StatelessWidget {
  const _MergeMascotAndTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Icon with gradient ring (mirrors TicTacToe's _MascotAndTitle)
        Container(
          width: 110, height: 110,
          decoration: BoxDecoration(
            gradient: const SweepGradient(
              colors: [_kGolden, _kOrange, _kGolden],
              stops: [0.0, 0.5, 1.0],
            ),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(4),
          child: Container(
            decoration: const BoxDecoration(
              color: _kCardBg,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(10),
            child: Container(
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
          ),
        ).animate().scale(
          begin: const Offset(0.8, 0.8), end: const Offset(1, 1),
          duration: 500.ms, curve: Curves.easeOutBack,
        ),
        const SizedBox(height: 16),
        const Text(
          '2048 Merge',
          style: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w900,
            color: _kTextDark, letterSpacing: -0.5,
          ),
        ).animate().fadeIn(delay: 120.ms, duration: 320.ms),
        const SizedBox(height: 6),
        Text(
          'Slide tiles • Merge numbers • Reach the goal',
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500,
            color: _kTextMid, letterSpacing: 0.2,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
      ],
    );
  }
}

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
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: _kTextDark,
                ),
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

class _HowToPlayLink extends StatelessWidget {
  final VoidCallback onTap;
  const _HowToPlayLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline_rounded, size: 14, color: _kTextMid),
            const SizedBox(width: 4),
            Text(
              'How to play?',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: _kTextMid,
                decoration: TextDecoration.underline,
                decorationColor: _kTextMid,
              ),
            ),
          ],
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
// ANIMATED BACKGROUND — scattered 2, 4, 8 tiles
// ════════════════════════════════════════════════════════════════

class _MergeBg extends StatelessWidget {
  const _MergeBg();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _MergeBgPainter(),
      ),
    );
  }
}

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

    RRect rrect(Offset center, double size) =>
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: size, height: size),
          Radius.circular(size * 0.18),
        );

    for (final (label, color, center) in items) {
      final tileSize = 52.0;
      // Tile background
      canvas.drawRRect(
        rrect(center, tileSize),
        Paint()..color = color.withValues(alpha: 0.25),
      );
      // Tile number
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
