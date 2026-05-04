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
const Color _kBgTop    = Color(0xFFD0E8FF);
const Color _kBgBot    = Color(0xFFADD3FF);
const Color _kAccent   = Color(0xFF339AF0);
const Color _kAccentDk = Color(0xFF1971C2);
const Color _kCardBg   = Colors.white;
const Color _kHintText = Color(0xFF1A4C80);

// ── Difficulty palette ─────────────────────────────────────────────────────
const Color _kEasyColor   = Color(0xFF22C55E);
const Color _kMediumColor = Color(0xFFF59E0B);
const Color _kHardColor   = Color(0xFFEF4444);

// ── Emoji categories (random category picked each game) ────────────────────
const _kEmojiCategories = <String, List<String>>{
  'Animals': [
    '🐶','🐱','🦊','🐸','🦁','🐻','🐼','🐧','🐨','🐯',
    '🦄','🐮','🐷','🐙','🦀','🦋','🐝','🦚','🦜','🦩',
  ],
  'Fruits': [
    '🍎','🍊','🍋','🍇','🍓','🍒','🍑','🥭','🍍','🥝',
    '🍌','🍉','🍈','🫐','🍏','🍐','🥥','🍅','🥑','🍆',
  ],
  'Plants & Nature': [
    '🌸','🌺','🌻','🌹','🌷','🌴','🌵','🌿','🍁','🍄',
    '🌾','🎋','🎍','🪷','🌼','🌱','🪴','🍃','🪻','🌲',
  ],
  'Space & Weather': [
    '🌙','⭐','🌟','☀️','🌈','⚡','❄️','🌊','🔥','🌪️',
    '🪐','🌍','🌕','☁️','🌠','🌌','🌀','⛄','🌋','🏔️',
  ],
  'Food & Drinks': [
    '🍕','🍔','🌮','🍣','🍜','🍩','🍦','🧁','🎂','🍫',
    '🍿','🧃','🍵','☕','🧋','🥤','🍺','🧇','🥞','🍟',
  ],
  'Sports & Activities': [
    '⚽','🏀','🎾','🏈','⚾','🎱','🏓','🏊','🚴','🧗',
    '🎯','🏹','🎮','🎲','♟️','🎸','🎺','🎻','🥊','🤿',
  ],
  'Travel & Places': [
    '✈️','🚀','🚂','🚢','🏝️','🏕️','🗼','🗽','🏯','⛩️',
    '🎡','🎢','🎠','🏟️','🌉','🗿','🕌','🛸','🚁','🏖️',
  ],
};

List<String> _pickEmojiPool(math.Random rng) {
  final keys = _kEmojiCategories.keys.toList();
  final category = keys[rng.nextInt(keys.length)];
  return List<String>.from(_kEmojiCategories[category]!);
}

// ── Pair colors (matched-card border tint per emoji) ───────────────────────
const _kPairColors = [
  Color(0xFF4DABF7), Color(0xFFFF8787), Color(0xFFFF922B),
  Color(0xFF51CF66), Color(0xFFCC5DE8), Color(0xFFFFD43B),
  Color(0xFF20C997), Color(0xFFF06595), Color(0xFFA9E34B),
  Color(0xFF74C0FC), Color(0xFFFF6B6B), Color(0xFF9775FA),
];

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
  final int pairColorIdx;
  bool faceUp;
  bool matched;
  bool mismatch; // transient red-flash state

  _Card({required this.id, required this.emoji, required this.pairColorIdx})
      : faceUp = false,
        matched = false,
        mismatch = false;
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
  int _flippedCount = 0;
  int? _firstFlipIdx;
  bool _lockInput = false;
  int _score = 0;
  int _bestScore = 0;
  bool _isNewBest = false;
  int _matchesFound = 0;
  int _flipCount = 0;          // total flips used
  int _consecutiveMatches = 0; // best combo tracker
  int _bestCombo = 0;
  bool _gameOver = false;
  bool _showMismatchOverlay = false;


  // Flip animation controllers — one per card
  List<AnimationController> _flipCtrl = [];

  // Bounce-in controllers — one per card (entry animation)
  List<AnimationController> _bounceCtrl = [];

  // Match pop controllers — one per card
  List<AnimationController> _matchCtrl = [];

  // Win celebration controller
  late AnimationController _celebrationCtrl;

  Timer? _flipBackTimer;
  Timer? _mismatchOverlayTimer;

  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kMemoryMatchGameId);
    _celebrationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void dispose() {
    _flipBackTimer?.cancel();
    _mismatchOverlayTimer?.cancel();
    for (final c in _flipCtrl) { c.dispose(); }
    for (final c in _bounceCtrl) { c.dispose(); }
    for (final c in _matchCtrl) { c.dispose(); }
    _celebrationCtrl.dispose();
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
    _mismatchOverlayTimer?.cancel();
    for (final c in _flipCtrl) { c.dispose(); }
    for (final c in _bounceCtrl) { c.dispose(); }
    for (final c in _matchCtrl) { c.dispose(); }
    _celebrationCtrl.reset();

    final pool = _pickEmojiPool(_rng)..shuffle(_rng);
    final emojis = pool.take(diff.pairCount).toList();
    final cardEmojis = [...emojis, ...emojis];
    cardEmojis.shuffle(_rng);

    final cards = List.generate(
      cardEmojis.length,
      (i) {
        final emoji = cardEmojis[i];
        final colorIdx = emojis.indexOf(emoji) % _kPairColors.length;
        return _Card(id: i, emoji: emoji, pairColorIdx: colorIdx);
      },
    );

    final controllers = List.generate(
      cards.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 320),
      ),
    );

    // Bounce-in controllers with staggered delays
    final bounceControllers = List.generate(
      cards.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 420),
      ),
    );

    final matchControllers = List.generate(
      cards.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );

    setState(() {
      _activeDifficulty = diff;
      _pickerDifficulty = diff;
      _cards = cards;
      _flipCtrl = controllers;
      _bounceCtrl = bounceControllers;
      _matchCtrl = matchControllers;
      _flippedCount = 0;
      _firstFlipIdx = null;
      _lockInput = false;
      _score = 0;
      _bestScore = _bestFor(diff);
      _isNewBest = false;
      _matchesFound = 0;
      _flipCount = 0;
      _consecutiveMatches = 0;
      _bestCombo = 0;
      _gameOver = false;
      _showMismatchOverlay = false;
    });

    ScoreService().incrementGamePlayCount(kMemoryMatchGameId);

    // Stagger bounce-in animations
    for (int i = 0; i < bounceControllers.length; i++) {
      final delay = Duration(milliseconds: (i * 40).clamp(0, 600));
      Future.delayed(delay, () {
        if (mounted) bounceControllers[i].forward();
      });
    }

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

    setState(() {
      card.faceUp = true;
      _flipCount++;
    });
    _flipCtrl[index].forward(from: 0);

    if (_flippedCount == 0) {
      _firstFlipIdx = index;
      _flippedCount = 1;
    } else {
      final firstIdx = _firstFlipIdx!;
      final secondIdx = index;
      _flippedCount = 0;
      _firstFlipIdx = null;
      _lockInput = true;

      final first = _cards[firstIdx];
      final second = card;

      if (first.emoji == second.emoji) {
        // Match!
        AudioService().playScore();
        final newMatches = _matchesFound + 1;
        final totalPairs = diff.pairCount;
        final newCombo = _consecutiveMatches + 1;
        final newBestCombo = newCombo > _bestCombo ? newCombo : _bestCombo;

        // Flip-efficiency score: calculated at completion
        // Show running +200 per match; final score adjusted at end
        final runningScore = newMatches * 200;

        setState(() {
          first.matched = true;
          second.matched = true;
          _score = runningScore;
          _matchesFound = newMatches;
          _consecutiveMatches = newCombo;
          _bestCombo = newBestCombo;
          _lockInput = false;
        });

        // Fire match pop on both cards
        _matchCtrl[firstIdx].forward(from: 0);
        _matchCtrl[secondIdx].forward(from: 0);

        GameWrapper.of(context).updateScore(_score);

        if (newMatches == totalPairs) {
          // Apply flip-efficiency penalty now that game is complete
          final minFlips = totalPairs * 2;
          final extraFlips = (_flipCount - minFlips).clamp(0, 9999);
          final penalty = extraFlips * 10;
          final floor = totalPairs * 50;
          final finalScore = (runningScore - penalty).clamp(floor, 99999);

          if (finalScore > _bestScore) {
            _bestScore = finalScore;
            _isNewBest = true;
            ScoreService().saveScore(kMemoryMatchGameId, finalScore, subKey: diff.subKey);
          }
          setState(() => _score = finalScore);
          GameWrapper.of(context).updateScore(finalScore);

          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _celebrationCtrl.forward();
              Future.delayed(const Duration(milliseconds: 800), () {
                if (mounted) _endGame();
              });
            }
          });
        }
      } else {
        // Mismatch — flash red, show dim overlay, then flip back
        _consecutiveMatches = 0;

        setState(() {
          first.mismatch = true;
          second.mismatch = true;
          _showMismatchOverlay = true;
        });

        _mismatchOverlayTimer?.cancel();
        _mismatchOverlayTimer = Timer(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          setState(() => _showMismatchOverlay = false);
        });

        _flipBackTimer?.cancel();
        _flipBackTimer = Timer(Duration(milliseconds: diff.flipBackMs), () {
          if (!mounted) return;
          _flipCtrl[firstIdx].reverse();
          _flipCtrl[index].reverse();
          setState(() {
            first.faceUp = false;
            first.mismatch = false;
            second.faceUp = false;
            second.mismatch = false;
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
    _mismatchOverlayTimer?.cancel();
    GameWrapper.of(context).restartGame();
    setState(() {
      _activeDifficulty = null;
      _gameOver = false;
      _score = 0;
      _matchesFound = 0;
      _flipCount = 0;
      _consecutiveMatches = 0;
      _bestCombo = 0;
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
    return Stack(
      children: [
        Container(
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
                    flipCount: _flipCount,
                  ),
                  trailing: GameRestartButton(
                    gameName: 'Memory Match',
                    accentColor: _kAccent,
                    onRestart: _newGame,
                    iconColor: const Color(0xFF0B3D78),
                  ),
                ),
                // Progress bar
                _ProgressBar(
                  matched: _matchesFound,
                  total: diff.pairCount,
                  color: diff.color,
                ),
                // Best combo indicator
                if (_bestCombo >= 2) _ComboIndicator(combo: _bestCombo),
                const SizedBox(height: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _CardGrid(
                      cards: _cards,
                      flipControllers: _flipCtrl,
                      bounceControllers: _bounceCtrl,
                      matchControllers: _matchCtrl,
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
        ),
        // Mismatch dim overlay
        if (_showMismatchOverlay)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _showMismatchOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 80),
              child: Container(color: Colors.red.withValues(alpha: 0.08)),
            ),
          ),
        // Win celebration
        AnimatedBuilder(
          animation: _celebrationCtrl,
          builder: (context2, child2) {
            if (_celebrationCtrl.value == 0) return const SizedBox.shrink();
            return Positioned.fill(
              child: _WinCelebrationOverlay(progress: _celebrationCtrl.value),
            );
          },
        ),
      ],
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
            label: 'FLIPS',
            value: _flipCount,
            color: _kAccentDk,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PROGRESS BAR
// ════════════════════════════════════════════════════════════════

class _ProgressBar extends StatelessWidget {
  final int matched;
  final int total;
  final Color color;

  const _ProgressBar({
    required this.matched,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : matched / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$matched / $total pairs',
                style: TextStyle(
                  color: _kAccentDk.withValues(alpha: 0.75),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: color.withValues(alpha: 0.85),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: _kAccent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  widthFactor: progress,
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, Color.lerp(color, Colors.white, 0.30)!],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.45),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// COMBO INDICATOR
// ════════════════════════════════════════════════════════════════

class _ComboIndicator extends StatelessWidget {
  final int combo;
  const _ComboIndicator({required this.combo});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(combo),
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFF922B).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: const Color(0xFFFF922B).withValues(alpha: 0.40),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
            Text(
              'Best combo: $combo',
              style: const TextStyle(
                color: Color(0xFFB45309),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// WIN CELEBRATION OVERLAY
// ════════════════════════════════════════════════════════════════

class _WinCelebrationOverlay extends StatelessWidget {
  final double progress;
  const _WinCelebrationOverlay({required this.progress});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ConfettiPainter(progress),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  static final _rng = math.Random(42);
  static final _particles = List.generate(60, (i) {
    return _ConfettiParticle(
      x: _rng.nextDouble(),
      startY: -0.05 - _rng.nextDouble() * 0.3,
      speedY: 0.35 + _rng.nextDouble() * 0.45,
      speedX: (_rng.nextDouble() - 0.5) * 0.18,
      size: 5 + _rng.nextDouble() * 8,
      color: _ConfettiPainter._randomColor(_rng),
      rotation: _rng.nextDouble() * math.pi * 2,
      rotSpeed: (_rng.nextDouble() - 0.5) * 8,
      delay: _rng.nextDouble() * 0.4,
      shape: _rng.nextInt(3),
    );
  });

  static Color _randomColor(math.Random rng) {
    final colors = [
      const Color(0xFFFFD43B), const Color(0xFF74C0FC), const Color(0xFF51CF66),
      const Color(0xFFFF6B6B), const Color(0xFFCC5DE8), const Color(0xFFFF922B),
      const Color(0xFFA9E34B), const Color(0xFFF06595),
    ];
    return colors[rng.nextInt(colors.length)];
  }

  const _ConfettiPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final pt = ((t - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (pt <= 0) continue;

      final x = (p.x + p.speedX * pt) * size.width;
      final y = (p.startY + p.speedY * pt) * size.height;
      final alpha = (1.0 - math.max(0.0, pt - 0.7) / 0.3).clamp(0.0, 1.0);

      final paint = Paint()..color = p.color.withValues(alpha: alpha.toDouble());

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.rotSpeed * pt);

      switch (p.shape) {
        case 0:
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
            paint,
          );
        case 1:
          canvas.drawCircle(Offset.zero, p.size * 0.45, paint);
        default:
          final path = Path()
            ..moveTo(0, -p.size * 0.5)
            ..lineTo(p.size * 0.5, p.size * 0.5)
            ..lineTo(-p.size * 0.5, p.size * 0.5)
            ..close();
          canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

class _ConfettiParticle {
  final double x;
  final double startY;
  final double speedY;
  final double speedX;
  final double size;
  final Color color;
  final double rotation;
  final double rotSpeed;
  final double delay;
  final int shape;

  const _ConfettiParticle({
    required this.x,
    required this.startY,
    required this.speedY,
    required this.speedX,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotSpeed,
    required this.delay,
    required this.shape,
  });
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

// ════════════════════════════════════════════════════════════════
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
  final int flipCount;

  const _ScorePill({
    required this.difficulty,
    required this.score,
    required this.best,
    required this.matches,
    required this.totalPairs,
    required this.flipCount,
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
              _flipCol(flipCount),
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

  Widget _flipCol(int flips) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'FLIPS',
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
            '$flips',
            key: ValueKey<int>(flips),
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
  final List<AnimationController> bounceControllers;
  final List<AnimationController> matchControllers;
  final int cols;
  final int rows;
  final ValueChanged<int> onCardTap;

  const _CardGrid({
    required this.cards,
    required this.flipControllers,
    required this.bounceControllers,
    required this.matchControllers,
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
                bounceController: bounceControllers[i],
                matchController: matchControllers[i],
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
  final AnimationController bounceController;
  final AnimationController matchController;  // NEW
  final VoidCallback onTap;

  const _FlipCard({
    required this.card,
    required this.controller,
    required this.bounceController,
    required this.matchController,  // NEW
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([bounceController, matchController]),
      builder: (_, child) {
        final bounceAnim = CurvedAnimation(
          parent: bounceController,
          curve: Curves.easeOutBack,
        );
        final bounceScale = bounceController.status == AnimationStatus.completed
            ? 1.0
            : Tween<double>(begin: 0.0, end: 1.0).evaluate(bounceAnim);

        // Pop burst: 1.0 → 1.18 → 1.0 over match animation
        final matchAnim = CurvedAnimation(parent: matchController, curve: Curves.easeOut);
        final matchScale = matchController.isAnimating || matchController.isCompleted
            ? TweenSequence<double>([
                TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 40),
                TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 60),
              ]).evaluate(matchAnim)
            : 1.0;

        return Transform.scale(
          scale: bounceScale * matchScale,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              child!,
              // Sparkle overlay during match pop
              if (card.matched && matchController.isAnimating)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: matchController,
                    builder: (context2, child2) => CustomPaint(
                      painter: _SparkleOverlayPainter(
                        progress: matchController.value,
                        color: _kPairColors[card.pairColorIdx % _kPairColors.length],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedBuilder(
          animation: controller,
          builder: (ctx, child3) {
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
    final isMismatch = card.mismatch;
    final pairColor = _kPairColors[card.pairColorIdx % _kPairColors.length];
    final glowColor = isMatched
        ? const Color(0xFF22C55E)
        : isMismatch
            ? const Color(0xFFEF4444)
            : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: faceUp ? const Color(0xFFFAFDFF) : null,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          if (glowColor != null)
            BoxShadow(
              color: glowColor.withValues(alpha: isMatched ? 0.55 : 0.45),
              blurRadius: isMatched ? 14 : 10,
              spreadRadius: isMatched ? 2 : 1,
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.13),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
        ],
        border: isMatched
            ? Border.all(color: const Color(0xFF22C55E), width: 2.5)
            : isMismatch
                ? Border.all(color: const Color(0xFFEF4444), width: 2.0)
                : faceUp
                    ? Border.all(color: pairColor.withValues(alpha: 0.55), width: 2.0)
                    : null,
        gradient: faceUp
            ? null
            : const LinearGradient(
                colors: [Color(0xFF4C3F91), Color(0xFF3949AB), Color(0xFF1A237E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: faceUp ? _FaceSide(card: card) : const _BackSide(),
      ),
    );
  }
}

class _FaceSide extends StatelessWidget {
  final _Card card;
  const _FaceSide({required this.card});

  @override
  Widget build(BuildContext context) {
    final isMatched = card.matched;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Inner glow for matched
        if (isMatched)
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF22C55E).withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        Center(
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: isMatched
                  ? Text(card.emoji, style: const TextStyle(fontSize: 32))
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 1.0, end: 1.08, duration: 700.ms, curve: Curves.easeInOut)
                  : Text(card.emoji, style: const TextStyle(fontSize: 32)),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackSide extends StatelessWidget {
  const _BackSide();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CardBackPainter());
  }
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Subtle dot grid
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.20);
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

    // Subtle diagonal cross pattern
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    const spacing = 12.0;
    var offset = -size.height;
    while (offset < size.width + size.height) {
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset + size.height, size.height),
        linePaint,
      );
      offset += spacing;
    }

    // Top-left highlight edge for 3D feel
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.width * 0.1),
    );
    canvas.drawRRect(rRect, highlightPaint);
  }

  @override
  bool shouldRepaint(_CardBackPainter old) => false;
}

class _SparkleOverlayPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0
  final Color color;

  const _SparkleOverlayPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width * 0.9;
    final paint = Paint()..style = PaintingStyle.fill;

    // 8 sparkle dots radiating outward
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi + progress * 0.5;
      final dist = maxR * progress;
      final dx = cx + math.cos(angle) * dist;
      final dy = cy + math.sin(angle) * dist;
      final radius = (1.0 - progress) * size.width * 0.09;
      paint.color = color.withValues(alpha: (1.0 - progress) * 0.85);
      canvas.drawCircle(Offset(dx, dy), radius.clamp(0, 20), paint);
    }

    // 4 small star dots at 45° offset
    for (int i = 0; i < 4; i++) {
      final angle = (i / 4 + 0.125) * 2 * math.pi;
      final dist = maxR * 0.55 * progress;
      final dx = cx + math.cos(angle) * dist;
      final dy = cy + math.sin(angle) * dist;
      final radius = (1.0 - progress) * size.width * 0.06;
      paint.color = Colors.white.withValues(alpha: (1.0 - progress) * 0.75);
      canvas.drawCircle(Offset(dx, dy), radius.clamp(0, 12), paint);
    }
  }

  @override
  bool shouldRepaint(_SparkleOverlayPainter old) => old.progress != progress;
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
      (0.08, 0.10, 56.0, 72.0, 0.0, false),
      (0.87, 0.15, 46.0, 60.0, 1.1, true),
      (0.12, 0.70, 52.0, 68.0, 2.2, false),
      (0.85, 0.72, 42.0, 55.0, 3.3, true),
      (0.50, 0.05, 40.0, 52.0, 4.4, false),
      (0.04, 0.42, 36.0, 47.0, 5.5, true),
      (0.72, 0.42, 44.0, 58.0, 0.7, false),
      (0.30, 0.88, 48.0, 63.0, 2.9, true),
      (0.92, 0.55, 34.0, 44.0, 4.1, false),
      (0.55, 0.60, 38.0, 50.0, 1.6, true),
    ];

    for (final (xRel, yRel, cw, ch, p, faceUp) in items) {
      final yBob = math.sin(phase + p) * 8;
      final rot = math.sin(phase * 0.6 + p) * 0.10;
      final alpha = 0.14 + (math.sin(phase * 0.8 + p) + 1) / 2 * 0.10;

      final cx = size.width * xRel;
      final cy = size.height * yRel + yBob;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);

      final rect = Rect.fromCenter(center: Offset.zero, width: cw, height: ch);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(cw * 0.15));

      if (faceUp) {
        // White card face with subtle border
        canvas.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: alpha));
        canvas.drawRRect(rr, Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      } else {
        // Blue card back with dot pattern hint
        canvas.drawRRect(rr, Paint()..color = _kAccentDk.withValues(alpha: alpha));
        canvas.drawRRect(rr, Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
      }

      canvas.restore();
    }
  }
}
