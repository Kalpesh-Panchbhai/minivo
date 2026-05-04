import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

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
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/spinning_slider.dart';
import 'memory_match_stats.dart';
import 'memory_match_tutorial.dart';

// ── Palette ────────────────────────────────────────────────────────────────
const Color _kBgTop    = Color(0xFFEBF5FF);
const Color _kBgBot    = Color(0xFFD5EAFF);
const Color _kAccent   = Color(0xFF339AF0);
const Color _kAccentDk = Color(0xFF1971C2);
const Color _kCardBg   = Colors.white;
const Color _kHintText = Color(0xFF1A4C80);

// ── Difficulty palette ─────────────────────────────────────────────────────
const Color _kEasyColor   = Color(0xFF22C55E);
const Color _kMediumColor = Color(0xFFF59E0B);
const Color _kHardColor   = Color(0xFFEF4444);

// ── Emoji sets ─────────────────────────────────────────────────────────────
const _kEmojis6  = ['🐶', '🐱', '🦊', '🐸', '🦁', '🐻'];
const _kEmojis8  = ['🐶', '🐱', '🦊', '🐸', '🦁', '🐻', '🐼', '🐧'];
const _kEmojis12 = ['🐶', '🐱', '🦊', '🐸', '🦁', '🐻', '🐼', '🐧', '🦋', '🌸', '🍎', '🎸'];

// ── Difficulty ─────────────────────────────────────────────────────────────
enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label   => ['EASY', 'MEDIUM', 'HARD'][index];
  Color  get color   => [_kEasyColor, _kMediumColor, _kHardColor][index];
  String get subKey  => ['easy', 'medium', 'hard'][index];
  int    get cols    => [4, 4, 6][index];
  int    get rows    => [3, 4, 4][index];
  int    get pairCount => (cols * rows) ~/ 2;
  int    get flipBackMs => [1000, 700, 500][index];
  List<String> get emojis => [_kEmojis6, _kEmojis8, _kEmojis12][index];
  String get hint => [
        '4×3 grid • 6 pairs to find.',
        '4×4 grid • 8 pairs, faster flip-back.',
        '6×4 grid • 12 pairs, very fast flip-back.',
      ][index];
  DifficultyKind get kind => [
        DifficultyKind.easy,
        DifficultyKind.medium,
        DifficultyKind.hard,
      ][index];
}

// ── Card model ─────────────────────────────────────────────────────────────
class _Card {
  final int id;
  final String emoji;
  bool faceUp;
  bool matched;

  _Card({required this.id, required this.emoji})
      : faceUp = false,
        matched = false;
}

// ════════════════════════════════════════════════════════════════
// Root screen
// ════════════════════════════════════════════════════════════════

class MemoryMatchScreen extends StatefulWidget {
  const MemoryMatchScreen({super.key});

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen>
    with TickerProviderStateMixin {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.medium;

  bool _isFavorite = false;

  // Game state
  List<_Card> _cards = [];
  int _flippedCount = 0;        // how many cards currently face-up (pending match)
  int? _firstFlipIdx;           // index of first flipped card
  bool _lockInput = false;      // true while animating flip-back
  int _score = 0;
  int _bestScore = 0;
  bool _isNewBest = false;
  int _matchesFound = 0;
  bool _gameOver = false;

  // Track first-flip pairs for bonus scoring
  final Set<String> _pairEverFlipped = {}; // emoji strings already attempted

  // Flip animation controllers — one per card
  List<AnimationController> _flipCtrl = [];

  Timer? _flipBackTimer;

  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kMemoryMatchGameId);
  }

  @override
  void dispose() {
    _flipBackTimer?.cancel();
    for (final c in _flipCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kMemoryMatchGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kMemoryMatchGameId);
    if (info == null) return;
    showHowToPlaySheet(
      context,
      title: info.name,
      howToPlay: info.howToPlay,
      accent: _kAccent,
      steps: memoryMatchSteps(),
    );
  }

  int _bestFor(_Difficulty d) =>
      ScoreService().getHighScore(kMemoryMatchGameId, subKey: d.subKey);

  // ── Game logic ────────────────────────────────────────────────────────────

  void _startGame(_Difficulty diff) {
    _flipBackTimer?.cancel();
    for (final c in _flipCtrl) { c.dispose(); }

    // Build card list — each emoji appears twice, shuffled
    final emojis = diff.emojis.take(diff.pairCount).toList();
    final cardEmojis = [...emojis, ...emojis];
    cardEmojis.shuffle(_rng);

    final cards = List.generate(
      cardEmojis.length,
      (i) => _Card(id: i, emoji: cardEmojis[i]),
    );

    final controllers = List.generate(
      cards.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );

    setState(() {
      _activeDifficulty = diff;
      _pickerDifficulty = diff;
      _cards = cards;
      _flipCtrl = controllers;
      _flippedCount = 0;
      _firstFlipIdx = null;
      _lockInput = false;
      _score = 0;
      _bestScore = _bestFor(diff);
      _isNewBest = false;
      _matchesFound = 0;
      _gameOver = false;
      _pairEverFlipped.clear();
    });

    ScoreService().incrementGamePlayCount(kMemoryMatchGameId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GameWrapper.of(context).startGame();
        GameWrapper.of(context).updateScore(0);
      }
    });
  }

  void _onCardTap(int index) {
    final diff = _activeDifficulty;
    if (diff == null || _lockInput || _gameOver) return;
    final card = _cards[index];
    if (card.faceUp || card.matched) return;

    AudioService().playTap();

    // Flip the card
    setState(() => card.faceUp = true);
    _flipCtrl[index].forward(from: 0);

    if (_flippedCount == 0) {
      // First card of pair
      _firstFlipIdx = index;
      _flippedCount = 1;
    } else {
      // Second card — check match
      final firstIdx = _firstFlipIdx!;
      _flippedCount = 0;
      _firstFlipIdx = null;
      _lockInput = true;

      final first = _cards[firstIdx];
      final second = card;

      if (first.emoji == second.emoji) {
        // Match!
        AudioService().playScore();
        // Calculate score: first attempt = +20, repeat attempt = +10
        final isFirstAttempt = !_pairEverFlipped.contains(first.emoji);
        final pts = isFirstAttempt ? 20 : 10;
        _pairEverFlipped.add(first.emoji);

        final newScore = _score + pts;
        final newMatches = _matchesFound + 1;
        final totalPairs = diff.pairCount;

        // All pairs matched? Bonus
        final completionBonus = (newMatches == totalPairs) ? 50 : 0;
        final finalScore = newScore + completionBonus;

        if (finalScore > _bestScore) {
          _bestScore = finalScore;
          _isNewBest = true;
          ScoreService().saveScore(kMemoryMatchGameId, finalScore, subKey: diff.subKey);
        }

        setState(() {
          first.matched = true;
          second.matched = true;
          _score = finalScore;
          _matchesFound = newMatches;
          _lockInput = false;
        });
        GameWrapper.of(context).updateScore(_score);

        if (newMatches == totalPairs) {
          // Game complete
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) _endGame();
          });
        }
      } else {
        // No match — flip back after delay
        _pairEverFlipped.add(first.emoji);
        _flipBackTimer?.cancel();
        _flipBackTimer = Timer(Duration(milliseconds: diff.flipBackMs), () {
          if (!mounted) return;
          _flipCtrl[firstIdx].reverse();
          _flipCtrl[index].reverse();
          setState(() {
            first.faceUp = false;
            second.faceUp = false;
            _lockInput = false;
          });
        });
      }
    }
  }

  void _endGame() {
    setState(() => _gameOver = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GameWrapper.of(context).endGame();
    });
  }

  void _newGame() => _startGame(_activeDifficulty ?? _pickerDifficulty);

  void _backToPicker() {
    _flipBackTimer?.cancel();
    GameWrapper.of(context).restartGame();
    setState(() {
      _activeDifficulty = null;
      _gameOver = false;
      _score = 0;
      _matchesFound = 0;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_activeDifficulty == null) return _buildPicker();
    if (_gameOver) return _buildGameOver();
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
        factory: (t) => _MemoryBgPainter(t),
        period: const Duration(seconds: 14),
      ),
      iconRingColors: const [_kAccent, _kAccentDk, _kAccent],
      iconChild: ClipOval(
        child: GameRegistry.getById(kMemoryMatchGameId)
                ?.buildBrandedLogo(size: 84) ??
            const SizedBox.shrink(),
      ),
      title: 'Memory Match',
      subtitle: 'Flip • Match • Remember',
      onBack: () => context.pop(),
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      tallThreshold: 860,
      body: _PickerSection(
        difficulty: _pickerDifficulty,
        onDifficultyChanged: (d) => setState(() => _pickerDifficulty = d),
        onPlay: () => _startGame(_pickerDifficulty),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // GAME
  // ════════════════════════════════════════════════════════════════

  Widget _buildGame() {
    final diff = _activeDifficulty!;
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
              leading: GameBackButton(
                onTap: _backToPicker,
                iconColor: const Color(0xFF0B3D78),
              ),
              centerContent: _ScorePill(
                difficulty: diff,
                score: _score,
                best: _bestScore,
                matches: _matchesFound,
                totalPairs: diff.pairCount,
              ),
              trailing: GameRestartButton(
                gameName: 'Memory Match',
                accentColor: _kAccent,
                onRestart: _newGame,
                iconColor: const Color(0xFF0B3D78),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _CardGrid(
                  cards: _cards,
                  flipControllers: _flipCtrl,
                  cols: diff.cols,
                  rows: diff.rows,
                  onCardTap: _onCardTap,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // GAME OVER
  // ════════════════════════════════════════════════════════════════

  Widget _buildGameOver() {
    final diff = _activeDifficulty!;
    return game_result.GenericGameResultScreen(
      headline: 'Well Done!',
      badgeContent: '🧠',
      badgeColor: diff.color,
      showNewBestBadge: _isNewBest,
      actions: [
        game_result.GameResultAction(
          label: 'Play Again',
          icon: Icons.refresh_rounded,
          onTap: _newGame,
          filled: true,
          color: diff.color,
        ),
        game_result.GameResultAction(
          label: 'Change Mode',
          icon: Icons.tune_rounded,
          onTap: _backToPicker,
          filled: false,
        ),
        game_result.GameResultAction(
          label: 'Home',
          icon: Icons.home_rounded,
          onTap: () => context.go('/home'),
          filled: false,
        ),
      ],
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(
            label: 'SCORE',
            value: _score,
            color: diff.color,
          ),
          game_result.StatItem(
            label: 'BEST',
            value: _bestScore,
            color: const Color(0xFF8B7BA7),
          ),
          game_result.StatItem(
            label: 'PAIRS',
            value: _matchesFound,
            color: _kAccentDk,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PICKER SECTION
// ════════════════════════════════════════════════════════════════

class _PickerSection extends StatelessWidget {
  final _Difficulty difficulty;
  final ValueChanged<_Difficulty> onDifficultyChanged;
  final VoidCallback onPlay;

  const _PickerSection({
    required this.difficulty,
    required this.onDifficultyChanged,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: _kAccent.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _kAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.tune_rounded, size: 16, color: _kAccent),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'DIFFICULTY',
                      style: TextStyle(
                        color: _kAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DifficultyLabel(difficulty: difficulty),
                const SizedBox(height: 14),
                SpinningSlider(
                  stopCount: _Difficulty.values.length,
                  activeIndex: _Difficulty.values.indexOf(difficulty),
                  activeColor: difficulty.color,
                  stopColors: const [_kEasyColor, _kMediumColor, _kHardColor],
                  onChanged: (i) => onDifficultyChanged(_Difficulty.values[i]),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Padding(
                    key: ValueKey(difficulty),
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      difficulty.hint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _kHintText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _BestScorePill(difficulty: difficulty),
              ],
            ),
          ),
        ),
        _PlayButton(difficulty: difficulty, onTap: onPlay)
            .animate()
            .fadeIn(delay: 220.ms, duration: 320.ms)
            .slideY(begin: 0.08, end: 0, duration: 320.ms),
      ],
    );
  }
}

class _DifficultyLabel extends StatelessWidget {
  final _Difficulty difficulty;
  const _DifficultyLabel({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: anim, child: child),
      ),
      child: Container(
        key: ValueKey(difficulty.label),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: difficulty.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: difficulty.color.withValues(alpha: 0.30),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedDifficultyIcon(kind: difficulty.kind, size: 32),
            const SizedBox(width: 12),
            Text(
              difficulty.label,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: difficulty.color,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BestScorePill extends StatelessWidget {
  final _Difficulty difficulty;
  const _BestScorePill({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final best = ScoreService().getHighScore(kMemoryMatchGameId, subKey: difficulty.subKey);
    final color = difficulty.color;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: Container(
        key: ValueKey('best_${difficulty.label}_$best'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: best > 0
              ? color.withValues(alpha: 0.14)
              : const Color(0xFF8B7BA7).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: best > 0
                ? color.withValues(alpha: 0.40)
                : const Color(0xFF8B7BA7).withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              best > 0 ? Icons.emoji_events_rounded : Icons.flag_outlined,
              size: 14,
              color: best > 0 ? color : const Color(0xFF8B7BA7),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                best > 0 ? 'Best $best pts' : 'Set your first best!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: best > 0 ? color : const Color(0xFF6B5E7E),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    final lighter = Color.lerp(color, Colors.white, 0.22)!;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, lighter],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(22),
              bottomRight: Radius.circular(22),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.36),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Play Memory Match',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      '${widget.difficulty.cols}×${widget.difficulty.rows} grid • ${widget.difficulty.pairCount} pairs',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// GAME UI: Score pill
// ════════════════════════════════════════════════════════════════

class _ScorePill extends StatelessWidget {
  final _Difficulty difficulty;
  final int score;
  final int best;
  final int matches;
  final int totalPairs;

  const _ScorePill({
    required this.difficulty,
    required this.score,
    required this.best,
    required this.matches,
    required this.totalPairs,
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
              AnimatedDifficultyIcon(kind: difficulty.kind, size: 14, prominent: false),
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
              _scoreCol('SCORE', score, color),
              const SizedBox(width: 10),
              Container(width: 1, height: 28, color: const Color(0xFFB8D8FF)),
              const SizedBox(width: 10),
              _scoreCol('BEST', best, const Color(0xFF8B7BA7)),
              const SizedBox(width: 10),
              Container(width: 1, height: 28, color: const Color(0xFFB8D8FF)),
              const SizedBox(width: 10),
              _pairsCol(matches, totalPairs),
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

  Widget _pairsCol(int found, int total) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'PAIRS',
          style: TextStyle(
            color: Color(0xFF1A4C80),
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
            '$found/$total',
            key: ValueKey<int>(found),
            style: const TextStyle(
              color: _kAccentDk,
              fontSize: 18,
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
// CARD GRID
// ════════════════════════════════════════════════════════════════

class _CardGrid extends StatelessWidget {
  final List<_Card> cards;
  final List<AnimationController> flipControllers;
  final int cols;
  final int rows;
  final ValueChanged<int> onCardTap;

  const _CardGrid({
    required this.cards,
    required this.flipControllers,
    required this.cols,
    required this.rows,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final gridW = c.maxWidth;
        final gridH = c.maxHeight;
        const gap = 8.0;
        final cardW = (gridW - gap * (cols - 1)) / cols;
        final cardH = (gridH - gap * (rows - 1)) / rows;

        return Stack(
          children: List.generate(cards.length, (i) {
            final col = i % cols;
            final row = i ~/ cols;
            final x = col * (cardW + gap);
            final y = row * (cardH + gap);

            return Positioned(
              left: x,
              top: y,
              width: cardW,
              height: cardH,
              child: _FlipCard(
                card: cards[i],
                controller: flipControllers[i],
                onTap: () => onCardTap(i),
              ),
            );
          }),
        );
      },
    );
  }
}

class _FlipCard extends StatelessWidget {
  final _Card card;
  final AnimationController controller;
  final VoidCallback onTap;

  const _FlipCard({
    required this.card,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, _) {
          // 3D flip: scaleX goes 1→0→1, with color swap at midpoint
          final anim = controller.value;
          final scaleX = (anim < 0.5)
              ? 1.0 - anim * 2
              : (anim - 0.5) * 2;
          final showFront = anim >= 0.5 || card.faceUp;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(scaleX, 1.0, 1.0),
            child: _CardFace(
              card: card,
              faceUp: showFront,
            ),
          );
        },
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  final _Card card;
  final bool faceUp;

  const _CardFace({required this.card, required this.faceUp});

  @override
  Widget build(BuildContext context) {
    final isMatched = card.matched;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: faceUp ? Colors.white : _kAccent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          if (isMatched)
            BoxShadow(
              color: const Color(0xFF22C55E).withValues(alpha: 0.45),
              blurRadius: 12,
              spreadRadius: 2,
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
        ],
        border: isMatched
            ? Border.all(color: const Color(0xFF22C55E), width: 2)
            : faceUp
                ? Border.all(color: _kAccent.withValues(alpha: 0.30), width: 1.5)
                : null,
        gradient: faceUp
            ? null
            : const LinearGradient(
                colors: [_kAccent, _kAccentDk],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: faceUp ? _FaceSide(card: card) : _BackSide(),
      ),
    );
  }
}

class _FaceSide extends StatelessWidget {
  final _Card card;
  const _FaceSide({required this.card});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            card.emoji,
            style: const TextStyle(fontSize: 32),
          ),
        ),
      ),
    );
  }
}

class _BackSide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CardBackPainter());
  }
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22);
    const cols = 3;
    const rows = 4;
    final rr = math.min(size.width, size.height) * 0.06;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final dx = size.width * (c + 1) / (cols + 1);
        final dy = size.height * (r + 1) / (rows + 1);
        canvas.drawCircle(Offset(dx, dy), rr, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_CardBackPainter old) => false;
}

// ════════════════════════════════════════════════════════════════
// Animated background — floating card shapes
// ════════════════════════════════════════════════════════════════

class _MemoryBgPainter extends AnimatedBgPainter {
  const _MemoryBgPainter(super.t);

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final phase = t * 2 * math.pi;

    final items = [
      (0.08, 0.10, 36.0, 48.0, 0.0, false),
      (0.87, 0.15, 28.0, 38.0, 1.1, true),
      (0.12, 0.70, 32.0, 43.0, 2.2, false),
      (0.85, 0.72, 26.0, 35.0, 3.3, true),
      (0.50, 0.05, 24.0, 32.0, 4.4, false),
      (0.04, 0.40, 20.0, 27.0, 5.5, true),
    ];

    for (final (xRel, yRel, cw, ch, p, faceUp) in items) {
      final yBob = math.sin(phase + p) * 6;
      final rot = math.sin(phase * 0.6 + p) * 0.08;
      final alpha = 0.04 + (math.sin(phase * 0.8 + p) + 1) / 2 * 0.04;

      final cx = size.width * xRel;
      final cy = size.height * yRel + yBob;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);

      final rect = Rect.fromCenter(center: Offset.zero, width: cw, height: ch);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(cw * 0.15));

      if (faceUp) {
        canvas.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: alpha));
      } else {
        canvas.drawRRect(rr, Paint()..color = _kAccent.withValues(alpha: alpha));
      }

      canvas.restore();
    }
  }
}
