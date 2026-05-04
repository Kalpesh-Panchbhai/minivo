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
import 'color_tap_stats.dart';
import 'color_tap_tutorial.dart';

// ── Palette ────────────────────────────────────────────────────────────────
const Color _kBgTop    = Color(0xFFFFF4EC);
const Color _kBgBot    = Color(0xFFFFE8D5);
const Color _kAccent   = Color(0xFFFF6B35);
const Color _kAccentLt = Color(0xFFFF922B);
const Color _kCardBg   = Colors.white;
const Color _kHintText = Color(0xFF8B4400);

// ── Game colors ────────────────────────────────────────────────────────────
const Color _kRed    = Color(0xFFEF4444);
const Color _kBlue   = Color(0xFF3B82F6);
const Color _kGreen  = Color(0xFF22C55E);
const Color _kYellow = Color(0xFFEAB308);
const Color _kPurple = Color(0xFF8B5CF6);
const Color _kOrange = Color(0xFFF97316);

// ── Difficulty palette ─────────────────────────────────────────────────────
const Color _kEasyColor   = Color(0xFF22C55E);
const Color _kMediumColor = Color(0xFFF59E0B);
const Color _kHardColor   = Color(0xFFEF4444);

// ── Difficulty ─────────────────────────────────────────────────────────────
enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label       => ['EASY', 'MEDIUM', 'HARD'][index];
  Color  get color       => [_kEasyColor, _kMediumColor, _kHardColor][index];
  int    get timeMs      => [3000, 2000, 1500][index];
  int    get points      => [10, 15, 20][index];
  String get subKey      => ['easy', 'medium', 'hard'][index];
  String get hint => [
        '4 colors • 3 seconds per round.',
        '5 colors • 2 seconds per round.',
        '6 colors • 1.5 seconds per round.',
      ][index];
  DifficultyKind get kind => [
        DifficultyKind.easy,
        DifficultyKind.medium,
        DifficultyKind.hard,
      ][index];

  List<Color> get palette => [
        [_kRed, _kBlue, _kGreen, _kYellow],
        [_kRed, _kBlue, _kGreen, _kYellow, _kPurple],
        [_kRed, _kBlue, _kGreen, _kYellow, _kPurple, _kOrange],
      ][index];

  List<String> get paletteNames => [
        ['RED', 'BLUE', 'GREEN', 'YELLOW'],
        ['RED', 'BLUE', 'GREEN', 'YELLOW', 'PURPLE'],
        ['RED', 'BLUE', 'GREEN', 'YELLOW', 'PURPLE', 'ORANGE'],
      ][index];
}

// ════════════════════════════════════════════════════════════════
// Root screen
// ════════════════════════════════════════════════════════════════

class ColorTapScreen extends StatefulWidget {
  const ColorTapScreen({super.key});

  @override
  State<ColorTapScreen> createState() => _ColorTapScreenState();
}

class _ColorTapScreenState extends State<ColorTapScreen>
    with TickerProviderStateMixin {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.medium;

  bool _isFavorite = false;

  // Game state
  final _rng = math.Random();
  int _score = 0;
  int _bestScore = 0;
  bool _isNewBest = false;
  int _lives = 3;
  bool _gameOver = false;

  // Current round
  Color _circleColor = _kRed;
  Color _targetColor = _kRed;
  String _targetColorName = 'RED';
  bool _isMatch = false; // whether circle == target for this round

  // Timer
  late AnimationController _timerCtrl;
  Timer? _roundTimer;

  // Feedback flash
  bool _showCorrect = false;
  bool _showWrong = false;
  bool _showSkip = false;
  Timer? _feedbackTimer;

  // Circle shake on wrong
  bool _shakeWrong = false;
  Timer? _shakeTimer;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kColorTapGameId);
    _timerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _timerCtrl.dispose();
    _roundTimer?.cancel();
    _feedbackTimer?.cancel();
    _shakeTimer?.cancel();
    super.dispose();
  }

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kColorTapGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kColorTapGameId);
    if (info == null) return;
    showHowToPlaySheet(
      context,
      title: info.name,
      howToPlay: info.howToPlay,
      accent: _kAccent,
      steps: colorTapSteps(),
    );
  }

  int _bestFor(_Difficulty d) =>
      ScoreService().getHighScore(kColorTapGameId, subKey: d.subKey);

  // ── Game logic ────────────────────────────────────────────────────────────

  void _startGame(_Difficulty diff) {
    _roundTimer?.cancel();
    _feedbackTimer?.cancel();
    _shakeTimer?.cancel();
    _timerCtrl.dispose();
    _timerCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: diff.timeMs),
    );

    setState(() {
      _activeDifficulty = diff;
      _pickerDifficulty = diff;
      _score = 0;
      _bestScore = _bestFor(diff);
      _isNewBest = false;
      _lives = 3;
      _gameOver = false;
      _showCorrect = false;
      _showWrong = false;
      _showSkip = false;
      _shakeWrong = false;
    });

    ScoreService().incrementGamePlayCount(kColorTapGameId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GameWrapper.of(context).startGame();
        GameWrapper.of(context).updateScore(0);
      }
    });

    _nextRound(diff);
  }

  void _nextRound(_Difficulty diff) {
    if (!mounted || _gameOver) return;
    _roundTimer?.cancel();

    final palette = diff.palette;
    final names = diff.paletteNames;

    // Pick circle color
    final circleIdx = _rng.nextInt(palette.length);
    // Pick target color — 50% chance of matching, 50% different
    final bool shouldMatch = _rng.nextBool();
    int targetIdx;
    if (shouldMatch || palette.length == 1) {
      targetIdx = circleIdx;
    } else {
      do {
        targetIdx = _rng.nextInt(palette.length);
      } while (targetIdx == circleIdx);
    }

    setState(() {
      _circleColor = palette[circleIdx];
      _targetColor = palette[targetIdx];
      _targetColorName = names[targetIdx];
      _isMatch = (circleIdx == targetIdx);
      _showCorrect = false;
      _showWrong = false;
      _showSkip = false;
      _shakeWrong = false;
    });

    _timerCtrl.duration = Duration(milliseconds: diff.timeMs);
    _timerCtrl.forward(from: 0);

    _roundTimer = Timer(Duration(milliseconds: diff.timeMs), () {
      if (!mounted || _gameOver) return;
      // Time ran out without action
      _onWrongAction(diff);
    });
  }

  void _onTap() {
    final diff = _activeDifficulty;
    if (diff == null || _gameOver) return;
    _roundTimer?.cancel();
    _timerCtrl.stop();

    if (_isMatch) {
      _onCorrectTap(diff);
    } else {
      _onWrongAction(diff);
    }
  }

  void _onSkip() {
    final diff = _activeDifficulty;
    if (diff == null || _gameOver) return;
    _roundTimer?.cancel();
    _timerCtrl.stop();

    if (!_isMatch) {
      _onCorrectSkip(diff);
    } else {
      _onWrongAction(diff);
    }
  }

  void _onCorrectTap(_Difficulty diff) {
    AudioService().playScore();
    final newScore = _score + diff.points;
    if (newScore > _bestScore) {
      _bestScore = newScore;
      _isNewBest = true;
      ScoreService().saveScore(kColorTapGameId, newScore, subKey: diff.subKey);
    }
    setState(() {
      _score = newScore;
      _showCorrect = true;
    });
    GameWrapper.of(context).updateScore(_score);
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && !_gameOver) _nextRound(diff);
    });
  }

  void _onCorrectSkip(_Difficulty diff) {
    AudioService().playScore();
    setState(() => _showSkip = true);
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted && !_gameOver) _nextRound(diff);
    });
  }

  void _onWrongAction(_Difficulty diff) {
    AudioService().playGameOver();
    final newLives = _lives - 1;
    setState(() {
      _lives = newLives;
      _showWrong = true;
      _shakeWrong = true;
    });
    _shakeTimer?.cancel();
    _shakeTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _shakeWrong = false);
    });

    if (newLives <= 0) {
      _feedbackTimer?.cancel();
      _feedbackTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) _endGame();
      });
    } else {
      _feedbackTimer?.cancel();
      _feedbackTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted && !_gameOver) _nextRound(diff);
      });
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
    _roundTimer?.cancel();
    _feedbackTimer?.cancel();
    _timerCtrl.stop();
    GameWrapper.of(context).restartGame();
    setState(() {
      _activeDifficulty = null;
      _gameOver = false;
      _score = 0;
      _lives = 3;
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
        factory: (t) => _ColorTapBgPainter(t),
        period: const Duration(seconds: 12),
      ),
      iconRingColors: const [_kAccent, _kAccentLt, _kAccent],
      iconChild: ClipOval(
        child: GameRegistry.getById(kColorTapGameId)
                ?.buildBrandedLogo(size: 84) ??
            const SizedBox.shrink(),
      ),
      title: 'Color Tap',
      subtitle: 'Match • Reflex • Speed',
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
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBackground(
              factory: (t) => _ColorTapBgPainter(t),
              period: const Duration(seconds: 12),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 4),
                // HUD
                GameHudBar(
                  leading: GameBackButton(
                    onTap: _backToPicker,
                    iconColor: const Color(0xFF7A2E00),
                  ),
                  centerContent: _ScorePill(
                    difficulty: diff,
                    score: _score,
                    best: _bestScore,
                    lives: _lives,
                  ),
                  trailing: GameRestartButton(
                    gameName: 'Color Tap',
                    accentColor: _kAccent,
                    onRestart: _newGame,
                    iconColor: const Color(0xFF7A2E00),
                    onDialogOpened: () {
                      _roundTimer?.cancel();
                      _timerCtrl.stop();
                    },
                    onDialogDismissed: () {
                      if (!_gameOver) {
                        _timerCtrl.forward(from: _timerCtrl.value);
                        final diff2 = _activeDifficulty;
                        if (diff2 != null) {
                          final remaining =
                              (1.0 - _timerCtrl.value) * diff2.timeMs;
                          _roundTimer = Timer(
                            Duration(milliseconds: remaining.round()),
                            () {
                              if (!mounted || _gameOver) return;
                              _onWrongAction(diff2);
                            },
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Target label
                _TargetLabel(colorName: _targetColorName, color: _targetColor),
                const SizedBox(height: 16),
                // Timer bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: AnimatedBuilder(
                    animation: _timerCtrl,
                    builder: (_, _) => _TimerBar(
                      progress: 1.0 - _timerCtrl.value,
                      color: diff.color,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Main circle
                Expanded(
                  child: Center(
                    child: _GameCircle(
                      color: _circleColor,
                      showCorrect: _showCorrect,
                      showWrong: _showWrong,
                      showSkip: _showSkip,
                      shakeWrong: _shakeWrong,
                      onTap: _onTap,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Skip button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: _SkipButton(onTap: _onSkip, accentColor: _kAccent),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // GAME OVER
  // ════════════════════════════════════════════════════════════════

  Widget _buildGameOver() {
    final diff = _activeDifficulty!;
    return game_result.GenericGameResultScreen(
      headline: 'Game Over',
      badgeContent: '🎨',
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
            label: 'LIVES LEFT',
            value: _lives.clamp(0, 3),
            color: _kRed,
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
    final best = ScoreService().getHighScore(kColorTapGameId, subKey: difficulty.subKey);
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
                      'Play Color Tap',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      '${widget.difficulty.points} pts per match',
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
// GAME UI COMPONENTS
// ════════════════════════════════════════════════════════════════

class _ScorePill extends StatelessWidget {
  final _Difficulty difficulty;
  final int score;
  final int best;
  final int lives;

  const _ScorePill({
    required this.difficulty,
    required this.score,
    required this.best,
    required this.lives,
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
              const SizedBox(width: 12),
              Container(width: 1, height: 28, color: const Color(0xFFFFD5B8)),
              const SizedBox(width: 12),
              _scoreCol('BEST', best, const Color(0xFF8B7BA7)),
              const SizedBox(width: 12),
              Container(width: 1, height: 28, color: const Color(0xFFFFD5B8)),
              const SizedBox(width: 12),
              _livesCol(lives),
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

  Widget _livesCol(int lives) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'LIVES',
          style: TextStyle(
            color: Color(0xFF9E3900),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final active = i < lives;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Icon(
                active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: active ? _kRed : _kRed.withValues(alpha: 0.25),
                size: 14,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _TargetLabel extends StatelessWidget {
  final String colorName;
  final Color color;
  const _TargetLabel({required this.colorName, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: anim, child: child),
      ),
      child: Container(
        key: ValueKey(colorName),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: 0.40), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'TARGET: $colorName',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerBar extends StatelessWidget {
  final double progress; // 1.0 = full, 0.0 = empty
  final Color color;
  const _TimerBar({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    final barColor = progress > 0.5
        ? color
        : progress > 0.25
            ? _kYellow
            : _kRed;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        children: [
          Container(
            height: 8,
            color: Colors.black12,
          ),
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: barColor.withValues(alpha: 0.40),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCircle extends StatefulWidget {
  final Color color;
  final bool showCorrect;
  final bool showWrong;
  final bool showSkip;
  final bool shakeWrong;
  final VoidCallback onTap;

  const _GameCircle({
    required this.color,
    required this.showCorrect,
    required this.showWrong,
    required this.showSkip,
    required this.shakeWrong,
    required this.onTap,
  });

  @override
  State<_GameCircle> createState() => _GameCircleState();
}

class _GameCircleState extends State<_GameCircle>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void didUpdateWidget(_GameCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shakeWrong && !oldWidget.shakeWrong) {
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = math.min(c.maxWidth, c.maxHeight) * 0.72;
        return AnimatedBuilder(
          animation: _shakeAnim,
          builder: (_, child) {
            final shakeX = widget.shakeWrong
                ? math.sin(_shakeAnim.value * math.pi * 5) * 10
                : 0.0;
            return Transform.translate(
              offset: Offset(shakeX, 0),
              child: child,
            );
          },
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) {
              setState(() => _pressed = false);
              widget.onTap();
            },
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedScale(
              scale: _pressed ? 0.93 : 1.0,
              duration: const Duration(milliseconds: 100),
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow
                    Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color.withValues(alpha: 0.20),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.35),
                            blurRadius: 32,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    // Main circle
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: size * 0.88,
                      height: size * 0.88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color.lerp(widget.color, Colors.white, 0.30)!,
                            widget.color,
                          ],
                          center: const Alignment(-0.3, -0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.45),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                    // Feedback overlay
                    if (widget.showCorrect)
                      Icon(Icons.check_rounded, color: Colors.white, size: size * 0.35)
                          .animate()
                          .scale(
                            begin: const Offset(0.4, 0.4),
                            end: const Offset(1.0, 1.0),
                            duration: 200.ms,
                            curve: Curves.easeOutBack,
                          ),
                    if (widget.showWrong)
                      Icon(Icons.close_rounded, color: Colors.white, size: size * 0.35)
                          .animate()
                          .scale(
                            begin: const Offset(0.4, 0.4),
                            end: const Offset(1.0, 1.0),
                            duration: 200.ms,
                            curve: Curves.easeOutBack,
                          ),
                    if (widget.showSkip)
                      Icon(Icons.skip_next_rounded, color: Colors.white, size: size * 0.32)
                          .animate()
                          .scale(
                            begin: const Offset(0.4, 0.4),
                            end: const Offset(1.0, 1.0),
                            duration: 200.ms,
                            curve: Curves.easeOutBack,
                          ),
                    // Tap hint text when no feedback
                    if (!widget.showCorrect && !widget.showWrong && !widget.showSkip)
                      Text(
                        'TAP',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontSize: size * 0.14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SkipButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color accentColor;
  const _SkipButton({required this.onTap, required this.accentColor});

  @override
  State<_SkipButton> createState() => _SkipButtonState();
}

class _SkipButtonState extends State<_SkipButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.skip_next_rounded, color: widget.accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'SKIP',
                style: TextStyle(
                  color: widget.accentColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
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
// Animated background — floating colored circles
// ════════════════════════════════════════════════════════════════

class _ColorTapBgPainter extends AnimatedBgPainter {
  const _ColorTapBgPainter(super.t);

  static const List<(Color, double, double, double, double)> _circles = [
    (_kRed,    0.10, 0.12, 52.0, 0.0),
    (_kBlue,   0.85, 0.20, 38.0, 0.9),
    (_kGreen,  0.15, 0.72, 44.0, 1.8),
    (_kYellow, 0.82, 0.78, 34.0, 2.7),
    (_kPurple, 0.48, 0.08, 30.0, 3.6),
    (_kOrange, 0.06, 0.45, 26.0, 4.5),
  ];

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final phase = t * 2 * math.pi;
    for (final (color, xRel, yRel, r, p) in _circles) {
      final yBob = math.sin(phase + p) * 8;
      final alpha = 0.04 + (math.sin(phase * 0.9 + p) + 1) / 2 * 0.05;
      final cx = size.width * xRel;
      final cy = size.height * yRel + yBob;
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
  }
}
