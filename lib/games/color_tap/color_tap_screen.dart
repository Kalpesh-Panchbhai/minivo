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
import '../shared/game_difficulty_picker.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import 'color_tap_stats.dart';
import 'color_tap_tutorial.dart';

// ── Palette ────────────────────────────────────────────────────────────────
const Color _kBgTop    = Color(0xFFFFDEC0);
const Color _kBgBot    = Color(0xFFFFC898);
const Color _kAccent   = Color(0xFFFF6B35);
const Color _kAccentLt = Color(0xFFFF922B);
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
  bool _isMatch = false;

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

  // Combo tracking (visual only)
  int _comboCount = 0;
  bool _showCombo = false;
  Timer? _comboTimer;

  // Score popup
  bool _showScorePopup = false;
  int _lastPointsEarned = 0;
  Timer? _scorePopupTimer;

  // Background hue shift animation
  late AnimationController _bgHueCtrl;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kColorTapGameId);
    _timerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _bgHueCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _timerCtrl.dispose();
    _bgHueCtrl.dispose();
    _roundTimer?.cancel();
    _feedbackTimer?.cancel();
    _shakeTimer?.cancel();
    _comboTimer?.cancel();
    _scorePopupTimer?.cancel();
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
    _comboTimer?.cancel();
    _scorePopupTimer?.cancel();
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
      _comboCount = 0;
      _showCombo = false;
      _showScorePopup = false;
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
    final newCombo = _comboCount + 1;
    setState(() {
      _score = newScore;
      _showCorrect = true;
      _comboCount = newCombo;
      _showCombo = newCombo >= 3;
      _showScorePopup = true;
      _lastPointsEarned = diff.points;
    });
    _comboTimer?.cancel();
    _comboTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showCombo = false);
    });
    _scorePopupTimer?.cancel();
    _scorePopupTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showScorePopup = false);
    });
    GameWrapper.of(context).updateScore(_score);
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && !_gameOver) _nextRound(diff);
    });
  }

  void _onCorrectSkip(_Difficulty diff) {
    AudioService().playScore();
    final newCombo = _comboCount + 1;
    setState(() {
      _showSkip = true;
      _comboCount = newCombo;
      _showCombo = newCombo >= 3;
    });
    _comboTimer?.cancel();
    _comboTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _showCombo = false);
    });
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
      _comboCount = 0;
      _showCombo = false;
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
      _comboCount = 0;
      _showCombo = false;
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
    return AnimatedBuilder(
      animation: _bgHueCtrl,
      builder: (_, child) {
        // Slowly shift bg gradient hue for ambience
        final hueShift = math.sin(_bgHueCtrl.value * 2 * math.pi) * 0.5;
        final topColor = Color.lerp(
          _kBgTop,
          const Color(0xFFFFF0E8),
          (hueShift + 1) / 2,
        )!;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [topColor, _kBgBot],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: child,
        );
      },
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
                const SizedBox(height: 12),
                // Target label
                _TargetLabel(colorName: _targetColorName, color: _targetColor),
                const SizedBox(height: 12),
                // Timer bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: AnimatedBuilder(
                    animation: _timerCtrl,
                    builder: (_, _) => _TimerBar(
                      progress: 1.0 - _timerCtrl.value,
                      color: diff.color,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Main circle + overlays
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: _GameCircle(
                          color: _circleColor,
                          showCorrect: _showCorrect,
                          showWrong: _showWrong,
                          showSkip: _showSkip,
                          shakeWrong: _shakeWrong,
                          onTap: _onTap,
                        ),
                      ),
                      // Score popup floating up on correct tap
                      if (_showScorePopup)
                        Positioned(
                          top: 12,
                          child: _ScorePopup(points: _lastPointsEarned),
                        ),
                      // Combo badge
                      if (_showCombo)
                        Positioned(
                          top: 8,
                          right: 24,
                          child: _ComboBadge(count: _comboCount),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Skip button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: _SkipButton(onTap: _onSkip, accentColor: _kAccent),
                ),
                const SizedBox(height: 20),
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
    return GameSinglePickerBody(
      difficulties: _Difficulty.values.map((d) => GameDifficultyData(
        label: d.label,
        color: d.color,
        kind: d.kind,
        hint: d.hint,
        bestScore: ScoreService().getHighScore(kColorTapGameId, subKey: d.subKey),
        bestLabel: (s) => 'Best $s pts',
      )).toList(),
      activeIndex: _Difficulty.values.indexOf(difficulty),
      onChanged: (i) => onDifficultyChanged(_Difficulty.values[i]),
      playLabel: 'Play Color Tap',
      playSubLabel: '${difficulty.points} pts per match',
      onPlay: onPlay,
      accentColor: _kAccent,
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: anim,
                    curve: Curves.easeOutBack,
                  ),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  key: ValueKey('heart_${i}_$active'),
                  color: active ? _kRed : _kRed.withValues(alpha: 0.25),
                  size: 14,
                ),
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
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (child, anim) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      child: Container(
        key: ValueKey(colorName),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.15),
              color.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.8),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.20),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated color swatch dot
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.50),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'TAP IF: $colorName',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
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
    final isCritical = progress < 0.20;
    final isLow = progress < 0.35;
    final barColor = progress > 0.50
        ? color
        : progress > 0.25
            ? Color.lerp(color, _kYellow, (0.50 - progress) / 0.25)!
            : Color.lerp(_kYellow, _kRed, (0.25 - progress) / 0.25)!;

    final glowColor = isCritical ? _kRed : (isLow ? _kYellow : color);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: isCritical
            ? [
                BoxShadow(
                  color: _kRed.withValues(alpha: 0.35),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Track
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            // Fill bar with gradient
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                height: 10,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(barColor, Colors.white, 0.35)!,
                      barColor,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withValues(alpha: isLow ? 0.60 : 0.35),
                      blurRadius: isLow ? 10 : 6,
                      spreadRadius: isLow ? 1 : 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            // Shine stripe on top of fill
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                height: 4,
                margin: const EdgeInsets.only(top: 1, left: 2, right: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
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
    with TickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Ripple on tap
  bool _showRipple = false;
  late AnimationController _rippleCtrl;
  late Animation<double> _rippleAnim;

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

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _rippleAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(_GameCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shakeWrong && !oldWidget.shakeWrong) {
      _shakeCtrl.forward(from: 0);
    }
    if ((widget.showCorrect && !oldWidget.showCorrect) ||
        (widget.showSkip && !oldWidget.showSkip) ||
        (widget.showWrong && !oldWidget.showWrong)) {
      _showRipple = true;
      _rippleCtrl.forward(from: 0).then((_) {
        if (mounted) setState(() => _showRipple = false);
      });
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _pulseCtrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  Color get _feedbackColor {
    if (widget.showCorrect) return _kGreen;
    if (widget.showWrong) return _kRed;
    if (widget.showSkip) return _kAccent;
    return widget.color;
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
              scale: _pressed ? 0.91 : 1.0,
              duration: const Duration(milliseconds: 90),
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulse ring
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, _) => Transform.scale(
                        scale: _pulseAnim.value,
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.transparent,
                            border: Border.all(
                              color: widget.color.withValues(alpha: 0.22),
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Glow layer
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withValues(
                              alpha: widget.showCorrect || widget.showWrong ? 0.55 : 0.35,
                            ),
                            blurRadius: widget.showCorrect ? 48 : 28,
                            spreadRadius: widget.showCorrect ? 8 : 2,
                          ),
                        ],
                      ),
                    ),
                    // Main circle — rich gradient
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: size * 0.86,
                      height: size * 0.86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color.lerp(
                                widget.showCorrect
                                    ? _kGreen
                                    : widget.showWrong
                                        ? _kRed
                                        : widget.color,
                                Colors.white,
                                0.38)!,
                            widget.showCorrect
                                ? _kGreen
                                : widget.showWrong
                                    ? _kRed
                                    : widget.color,
                            Color.lerp(
                                widget.showCorrect
                                    ? _kGreen
                                    : widget.showWrong
                                        ? _kRed
                                        : widget.color,
                                Colors.black,
                                0.20)!,
                          ],
                          stops: const [0.0, 0.58, 1.0],
                          center: const Alignment(-0.35, -0.35),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (widget.showWrong ? _kRed : widget.color)
                                .withValues(alpha: 0.50),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                    ),
                    // Gloss shine on the circle
                    Positioned(
                      top: size * 0.09,
                      left: size * 0.20,
                      child: Container(
                        width: size * 0.25,
                        height: size * 0.12,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.30),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                    // Ripple effect on tap
                    if (_showRipple)
                      AnimatedBuilder(
                        animation: _rippleAnim,
                        builder: (_, _) {
                          final rAlpha = (1 - _rippleAnim.value) * 0.50;
                          return Container(
                            width: size * 0.86 * (0.80 + _rippleAnim.value * 0.60),
                            height: size * 0.86 * (0.80 + _rippleAnim.value * 0.60),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _feedbackColor.withValues(alpha: rAlpha),
                                width: 3,
                              ),
                            ),
                          );
                        },
                      ),
                    // Feedback icons
                    if (widget.showCorrect)
                      Icon(Icons.check_rounded, color: Colors.white, size: size * 0.35)
                          .animate()
                          .scale(
                            begin: const Offset(0.3, 0.3),
                            end: const Offset(1.0, 1.0),
                            duration: 180.ms,
                            curve: Curves.easeOutBack,
                          ),
                    if (widget.showWrong)
                      Icon(Icons.close_rounded, color: Colors.white, size: size * 0.35)
                          .animate()
                          .scale(
                            begin: const Offset(0.3, 0.3),
                            end: const Offset(1.0, 1.0),
                            duration: 180.ms,
                            curve: Curves.easeOutBack,
                          ),
                    if (widget.showSkip)
                      Icon(Icons.skip_next_rounded, color: Colors.white, size: size * 0.32)
                          .animate()
                          .scale(
                            begin: const Offset(0.3, 0.3),
                            end: const Offset(1.0, 1.0),
                            duration: 180.ms,
                            curve: Curves.easeOutBack,
                          ),
                    // Tap hint text when idle
                    if (!widget.showCorrect && !widget.showWrong && !widget.showSkip)
                      Text(
                        'TAP',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: size * 0.14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 4,
                            ),
                          ],
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

class _SkipButtonState extends State<_SkipButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _rippleCtrl;
  late Animation<double> _rippleAnim;

  @override
  void initState() {
    super.initState();
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _rippleAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        _rippleCtrl.forward(from: 0);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                widget.accentColor.withValues(alpha: 0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.40),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.14),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ripple overlay
                AnimatedBuilder(
                  animation: _rippleAnim,
                  builder: (_, _) {
                    return Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.accentColor.withValues(
                              alpha: (1 - _rippleAnim.value) * 0.12),
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.skip_next_rounded,
                      color: widget.accentColor,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SKIP',
                      style: TextStyle(
                        color: widget.accentColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SCORE POPUP
// ════════════════════════════════════════════════════════════════

class _ScorePopup extends StatelessWidget {
  final int points;
  const _ScorePopup({required this.points});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Text(
        '+$points',
        style: const TextStyle(
          color: _kGreen,
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              color: Color(0x4422C55E),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 100.ms)
          .slideY(begin: 0, end: -1.0, duration: 600.ms, curve: Curves.easeOut)
          .fadeOut(delay: 250.ms, duration: 350.ms),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// COMBO BADGE
// ════════════════════════════════════════════════════════════════

class _ComboBadge extends StatelessWidget {
  final int count;
  const _ComboBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.50),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded,
              color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            '${count}x COMBO',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              shadows: [
                Shadow(
                  color: Color(0x55000000),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1.0, 1.0),
          duration: 200.ms,
          curve: Curves.easeOutBack,
        )
        .fadeIn(duration: 150.ms);
  }
}

// ════════════════════════════════════════════════════════════════
// Animated background — floating colored circles
// ════════════════════════════════════════════════════════════════

class _ColorTapBgPainter extends AnimatedBgPainter {
  const _ColorTapBgPainter(super.t);

  static const List<(Color, double, double, double, double)> _circles = [
    (_kRed,    0.10, 0.12, 80.0, 0.0),
    (_kBlue,   0.85, 0.20, 65.0, 0.9),
    (_kGreen,  0.15, 0.72, 72.0, 1.8),
    (_kYellow, 0.82, 0.78, 58.0, 2.7),
    (_kPurple, 0.48, 0.08, 55.0, 3.6),
    (_kOrange, 0.06, 0.45, 50.0, 4.5),
    (_kRed,    0.70, 0.50, 42.0, 5.4),
    (_kBlue,   0.35, 0.90, 48.0, 0.3),
  ];

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final phase = t * 2 * math.pi;
    for (final (color, xRel, yRel, r, p) in _circles) {
      final yBob = math.sin(phase + p) * 8;
      final alpha = 0.12 + (math.sin(phase * 0.9 + p) + 1) / 2 * 0.12;
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
