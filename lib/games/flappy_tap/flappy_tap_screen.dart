import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
import '../shared/rewarded_continue_action.dart';
import 'flappy_tap_stats.dart';
import 'flappy_tap_tutorial.dart';

// ── Picker palette ─────────────────────────────────────────────────────────
const Color _kBgTop    = Color(0xFFE8F8FF);
const Color _kBgBot    = Color(0xFFD0EEFF);
// ── Flappy Tap brand colors ────────────────────────────────────────────────
const Color _kFlappyAccent = Color(0xFF4ECDC4);
const Color _kFlappyDark   = Color(0xFF2AA39A);

// ── Difficulty palette ─────────────────────────────────────────────────────
const Color _kEasyColor   = Color(0xFF22C55E);
const Color _kMediumColor = Color(0xFFF59E0B);
const Color _kHardColor   = Color(0xFFEF4444);

// ── Sky / ground colors for the canvas ────────────────────────────────────
const Color _kSkyTop    = Color(0xFF4A9FD4);
const Color _kSkyMid    = Color(0xFF71B9E8);
const Color _kSkyBot    = Color(0xFFADD8F0);
const Color _kPipeColor = Color(0xFF4CAF50);
const Color _kPipeDark  = Color(0xFF388E3C);
const Color _kGroundBr  = Color(0xFF8B6914);
const Color _kGrassGr   = Color(0xFF5CB85C);


// ── Game physics constants ─────────────────────────────────────────────────
const double _kGravity    = 800.0; // px/s²
const double _kJumpForce  = -340.0; // px/s (negative = upward)
const double _kPipeWidth  = 72.0;
const double _kGroundH    = 60.0;
const double _kBirdRadius = 22.0;
const double _kBirdXRel   = 0.22; // fraction of screen width

// ── Difficulty enum ────────────────────────────────────────────────────────
enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label => ['EASY', 'MEDIUM', 'HARD'][index];
  Color  get color => [_kEasyColor, _kMediumColor, _kHardColor][index];

  double get pipeSpeed      => [110.0, 160.0, 210.0][index];
  double get gapHeight      => [200.0, 160.0, 140.0][index];
  double get spawnInterval  => [3.0, 2.4, 2.0][index];
  int    get pointsPerPipe  => [5, 10, 20][index];
  String get subKey         => ['easy', 'medium', 'hard'][index];

  String get hint => [
        'Wide gaps · slow pipes · perfect for first timers',
        'Classic Flappy speed · room for errors but stay focused',
        'Blistering pace · tiny gaps · pure reflexes required',
      ][index];

  DifficultyKind get kind => [
        DifficultyKind.easy,
        DifficultyKind.medium,
        DifficultyKind.hard,
      ][index];
}

// ── Pipe data ──────────────────────────────────────────────────────────────
class _Pipe {
  double x;
  final double gapCenterY;
  bool scored = false;

  _Pipe({required this.x, required this.gapCenterY});
}

// ── Cloud data ─────────────────────────────────────────────────────────────
class _Cloud {
  double x;
  final double y;
  final double radius;
  final double speed;

  _Cloud({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
  });
}

// ════════════════════════════════════════════════════════════════
// Root screen — picker → game transition
// ════════════════════════════════════════════════════════════════

class FlappyTapScreen extends StatefulWidget {
  const FlappyTapScreen({super.key});

  @override
  State<FlappyTapScreen> createState() => _FlappyTapScreenState();
}

class _FlappyTapScreenState extends State<FlappyTapScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── Picker state ──────────────────────────────────────────────────────────
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.values[DifficultyKind.defaultIndex];
  bool _isFavorite = false;

  // ── Bird state ────────────────────────────────────────────────────────────
  double _birdY    = 0.0; // pixels from top
  double _birdVy   = 0.0; // pixels/s, positive = downward

  // ── Pipe state ────────────────────────────────────────────────────────────
  final List<_Pipe> _pipes = [];
  double _sinceLastSpawn = 0.0;

  // ── Cloud state ───────────────────────────────────────────────────────────
  final List<_Cloud> _clouds = [];

  // ── Animation state ───────────────────────────────────────────────────────
  double _wingPhase   = 0.0;
  double _groundOffset = 0.0;

  // ── Death flash ───────────────────────────────────────────────────────────
  late final AnimationController _flashCtrl;
  double get _deathFlashAlpha => _flashCtrl.value * 0.55;

  // ── Score state ───────────────────────────────────────────────────────────
  int _score     = 0;
  int _bestScore = 0;
  bool _isNewBestScore = false;
  bool _gameOver = false;

  // ── Canvas dimensions ─────────────────────────────────────────────────────
  double _canvasW = 0.0;
  double _canvasH = 0.0;

  // ── Ticker ────────────────────────────────────────────────────────────────
  late final Ticker _ticker;
  DateTime? _lastTime;

  // ── Repaint notifier ─────────────────────────────────────────────────────
  final _repaint = ValueNotifier<int>(0);

  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isFavorite = ScoreService().isFavorite(kFlappyTapGameId);
    _ticker = createTicker(_onTick);
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flashCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _flashCtrl.dispose();
    _repaint.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_activeDifficulty == null || _gameOver) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _stopTicker();
    } else if (state == AppLifecycleState.resumed) {
      if (!_ticker.isActive && !_gameOver) _startTicker();
    }
  }

  // ── Ticker control ───────────────────────────────────────────────────────

  void _startTicker() {
    _lastTime = null;
    _ticker.start();
  }

  void _stopTicker() {
    _ticker.stop();
    _lastTime = null;
  }

  void _onTick(Duration elapsed) {
    if (_lastTime == null) {
      _lastTime = DateTime.now();
      return;
    }
    if (!mounted || _gameOver) return;
    if (GameWrapper.of(context).state == GameState.paused) return;

    final now = DateTime.now();
    final dt = now.difference(_lastTime!).inMicroseconds / 1e6;
    _lastTime = now;
    _update(dt.clamp(0.0, 0.05));
  }

  // ── Utility ──────────────────────────────────────────────────────────────

  int _bestFor(_Difficulty d) =>
      ScoreService().getHighScore(kFlappyTapGameId, subKey: d.subKey);

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kFlappyTapGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kFlappyTapGameId);
    if (info == null) return;
    showHowToPlaySheet(
      context,
      title: info.name,
      howToPlay: info.howToPlay,
      accent: _kFlappyAccent,
      steps: flappyTapSteps(),
      gameId: kFlappyTapGameId,
    );
  }

  // ── Cloud initialisation ─────────────────────────────────────────────────

  void _initClouds() {
    _clouds.clear();
    if (_canvasW == 0 || _canvasH == 0) return;
    final skyH = _canvasH * 0.35;
    const count = 4;
    for (int i = 0; i < count; i++) {
      _clouds.add(_Cloud(
        x: _canvasW * (i / count) + _rng.nextDouble() * (_canvasW / count),
        y: _canvasH * 0.05 + _rng.nextDouble() * skyH,
        radius: 28 + _rng.nextDouble() * 22,
        speed: 20 + _rng.nextDouble() * 20,
      ));
    }
  }

  // ── Game start / restart ─────────────────────────────────────────────────

  void _startGame(_Difficulty diff) {
    _stopTicker();
    _pipes.clear();

    final startY = _canvasH > 0
        ? (_canvasH - _kGroundH) / 2.0
        : 300.0;

    setState(() {
      _activeDifficulty = diff;
      _pickerDifficulty = diff;
      _birdY  = startY;
      _birdVy = 0.0;
      _score  = 0;
      _bestScore = _bestFor(diff);
      _isNewBestScore = false;
      _gameOver = false;
      _sinceLastSpawn = 0.0;
      _wingPhase = 0.0;
      _groundOffset = 0.0;
    });

    _initClouds();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GameWrapper.of(context).setDifficultyAndMode(difficulty: diff.label, subKey: diff.subKey);
        GameWrapper.of(context).startGame();
        GameWrapper.of(context).updateScore(0);
        _startTicker();
      }
    });
  }

  void _newGame() => _startGame(_activeDifficulty ?? _pickerDifficulty);

  /// Resume after a rewarded "Continue" — clear pipes near the bird and
  /// respawn at center with zero velocity, keeping the score.
  void _continueGame() {
    if (_activeDifficulty == null) return;
    final startY = _canvasH > 0 ? (_canvasH - _kGroundH) / 2.0 : 300.0;
    setState(() {
      _pipes.clear();
      _birdY = startY;
      _birdVy = 0.0;
      _gameOver = false;
      _sinceLastSpawn = 0.0;
    });
    GameWrapper.of(context).continueAfterGameOver();
    _startTicker();
  }

  void _backToPicker() {
    _stopTicker();
    setState(() {
      _activeDifficulty = null;
      _gameOver = false;
    });
    GameWrapper.of(context).restartGame();
  }

  void _backOrHome() {
    final wrapper = GameWrapper.of(context);
    wrapper.handleExit(() {
      _stopTicker();
      if (context.canPop()) context.pop(); else context.go('/home');
    });
  }

  // ── Jump ─────────────────────────────────────────────────────────────────

  void _jump() {
    if (_activeDifficulty == null || _gameOver) return;
    setState(() => _birdVy = _kJumpForce);
    AudioService().playScore(); // reuse score sound as flap sound
  }

  // ── Game update ───────────────────────────────────────────────────────────

  void _update(double dt) {
    final diff = _activeDifficulty;
    if (diff == null || _gameOver || _canvasH == 0) return;

    final playH = _canvasH - _kGroundH;
    final birdX = _canvasW * _kBirdXRel;
    // ── Wing animation ─────────────────────────────────────────────────────
    _wingPhase = (_wingPhase + 6.0 * dt) % (2 * math.pi);

    // ── Ground scroll ──────────────────────────────────────────────────────
    _groundOffset = (_groundOffset + diff.pipeSpeed * dt) % 60.0;

    // ── Cloud movement ─────────────────────────────────────────────────────
    for (final cloud in _clouds) {
      cloud.x -= cloud.speed * dt;
      if (cloud.x + cloud.radius * 2 < 0) {
        cloud.x = _canvasW + cloud.radius;
        // ignore: parameter_assignments
      }
    }

    // ── Spawn pipes ────────────────────────────────────────────────────────
    _sinceLastSpawn += dt;
    if (_sinceLastSpawn >= diff.spawnInterval) {
      _sinceLastSpawn = 0;
      final minGapCenter = diff.gapHeight / 2 + 20;
      final maxGapCenter = playH - diff.gapHeight / 2 - 20;
      final gapCenterY = minGapCenter +
          _rng.nextDouble() * (maxGapCenter - minGapCenter);
      _pipes.add(_Pipe(x: _canvasW, gapCenterY: gapCenterY));
    }

    // ── Move pipes + check scored ─────────────────────────────────────────
    for (final pipe in _pipes) {
      pipe.x -= diff.pipeSpeed * dt;
      if (!pipe.scored && pipe.x + _kPipeWidth < birdX - _kBirdRadius) {
        pipe.scored = true;
        _score += diff.pointsPerPipe;
        if (_score > _bestScore) {
          _bestScore = _score;
          _isNewBestScore = true;
        }
        ScoreService().saveScore(
          kFlappyTapGameId, _score, subKey: diff.subKey,
        );
        GameWrapper.of(context).updateScore(_score);
      }
    }

    // Remove off-screen pipes
    _pipes.removeWhere((p) => p.x + _kPipeWidth < 0);

    // ── Apply gravity + clamp ─────────────────────────────────────────────
    _birdVy += _kGravity * dt;
    _birdY  += _birdVy * dt;

    // Ceiling
    if (_birdY - _kBirdRadius < 0) {
      _birdY  = _kBirdRadius;
      _birdVy = 0;
    }

    // Ground collision
    if (_birdY + _kBirdRadius >= playH) {
      _birdY = playH - _kBirdRadius;
      _endGame();
      return;
    }

    // ── Pipe collision ────────────────────────────────────────────────────
    for (final pipe in _pipes) {
      if (!_pipeHitsBird(pipe, birdX, diff.gapHeight)) continue;
      _endGame();
      return;
    }

    // ── Trigger repaint ───────────────────────────────────────────────────
    _repaint.value++;
  }

  bool _pipeHitsBird(_Pipe pipe, double birdX, double gapHeight) {
    final pipeLeft  = pipe.x;
    final pipeRight = pipe.x + _kPipeWidth;
    if (birdX + _kBirdRadius < pipeLeft) return false;
    if (birdX - _kBirdRadius > pipeRight) return false;

    final gapTop    = pipe.gapCenterY - gapHeight / 2;
    final gapBottom = pipe.gapCenterY + gapHeight / 2;
    if (_birdY - _kBirdRadius >= gapTop &&
        _birdY + _kBirdRadius <= gapBottom) {
      return false;
    }
    return true;
  }

  void _endGame() {
    _stopTicker();
    AudioService().playGameOver();
    // Trigger death flash: animate from 1.0 → 0.0
    _flashCtrl.value = 1.0;
    _flashCtrl.animateTo(0.0, duration: const Duration(milliseconds: 400));
    setState(() => _gameOver = true);

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      if (mounted) GameWrapper.of(context).endGame();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) GameWrapper.of(context).endGame();
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    GameWrapper.of(context);

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
        factory: (t) => _FlappyBgPainter(t),
        period: const Duration(seconds: 12),
      ),
      iconRingColors: const [_kFlappyAccent, _kFlappyDark, _kFlappyAccent],
      iconChild: ClipOval(
        child: GameRegistry.getById(kFlappyTapGameId)
                ?.buildBrandedLogo(size: 84) ??
            const SizedBox.shrink(),
      ),
      title: 'Flappy Tap',
      subtitle: 'Tap • Dodge • Fly',
      onBack: () => context.pop(),
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kFlappyTapGameId,
      tallThreshold: 860,
      body: _PickerSection(
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

    final diff = _activeDifficulty!;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _jump(),
      child: Stack(
        children: [
          // Full-screen canvas
          Positioned.fill(child: _buildCanvas()),
          // Death flash overlay
          if (_deathFlashAlpha > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.white.withValues(alpha: _deathFlashAlpha),
                ),
              ),
            ),
          // HUD overlaid at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildGameHud(diff),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameHud(_Difficulty diff) {
    return GameHudBar(
      leading: GameBackButton(onTap: _backOrHome),
      centerContent: _ScoreBoardPill(
        difficulty: diff,
        score: _score,
        best: _bestScore,
      ),
      trailing: GameRestartButton(
        gameName: 'Flappy Tap',
        accentColor: _kFlappyAccent,
        onRestart: _newGame,
        onDialogOpened: _stopTicker,
        onDialogDismissed: () {
          if (!_gameOver) _startTicker();
        },
      ),
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (_canvasW != w || _canvasH != h) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && (_canvasW != w || _canvasH != h)) {
              setState(() {
                _canvasW = w;
                _canvasH = h;
                if (_birdY == 0.0 && h > 0) {
                  _birdY = (h - _kGroundH) / 2.0;
                }
              });
              // Init clouds once dimensions are known
              if (_clouds.isEmpty) _initClouds();
            }
          });
        }

        final diff = _activeDifficulty!;

        return ValueListenableBuilder<int>(
          valueListenable: _repaint,
          builder: (context2, value, child) => CustomPaint(
            size: Size(w, h),
            painter: _FlappyPainter(
              birdY: _birdY,
              birdVy: _birdVy,
              canvasW: w,
              canvasH: h,
              pipes: List.unmodifiable(_pipes),
              clouds: List.unmodifiable(_clouds),
              gapHeight: diff.gapHeight,
              score: _score,
              wingPhase: _wingPhase,
              groundOffset: _groundOffset,
              isDead: _gameOver,
            ),
          ),
        );
      },
    );
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
      gameId: kFlappyTapGameId,
      score: _score,
      headline: 'Game Over',
      badgeContent: '🐦',
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
          onTap: _backToPicker,
          filled: false,
          actionId: 'change_mode',
        ),
        game_result.GameResultAction(
          label: 'Home',
          icon: Icons.home_rounded,
          onTap: () => context.go('/home'),
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
          game_result.StatItem(
            label: 'PIPES',
            value: _score ~/ difficulty.pointsPerPipe,
            color: _kFlappyDark,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PICKER — Difficulty selector + play button
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
        bestScore: ScoreService().getHighScore(kFlappyTapGameId, subKey: d.subKey),
        bestLabel: (s) => 'Best $s',
      )).toList(),
      activeIndex: _Difficulty.values.indexOf(difficulty),
      onChanged: (i) => onDifficultyChanged(_Difficulty.values[i]),
      playLabel: 'Play Flappy Tap',
      playSubLabel: '${difficulty.pointsPerPipe} pts per pipe',
      onPlay: onPlay,
      accentColor: _kFlappyAccent,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// HUD — Score pill
// ════════════════════════════════════════════════════════════════

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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: color,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(10)),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _kFlappyAccent.withValues(alpha: 0.18),
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
                color: _kFlappyAccent.withValues(alpha: 0.20),
              ),
              const SizedBox(width: 18),
              _scoreColumn('BEST', best, _kFlappyDark),
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
// CUSTOM PAINTER — Flappy Tap canvas
// ════════════════════════════════════════════════════════════════

class _FlappyPainter extends CustomPainter {
  final double birdY;
  final double birdVy;
  final double canvasW;
  final double canvasH;
  final List<_Pipe> pipes;
  final List<_Cloud> clouds;
  final double gapHeight;
  final int score;
  final double wingPhase;
  final double groundOffset;
  final bool isDead;

  const _FlappyPainter({
    required this.birdY,
    required this.birdVy,
    required this.canvasW,
    required this.canvasH,
    required this.pipes,
    required this.clouds,
    required this.gapHeight,
    required this.score,
    required this.wingPhase,
    required this.groundOffset,
    required this.isDead,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Sky gradient background (3-stop richer gradient) ──────────────────
    final skyRect = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = LinearGradient(
          colors: const [_kSkyTop, _kSkyMid, _kSkyBot],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(skyRect),
    );

    // ── Clouds (moving, realistic) ────────────────────────────────────────
    for (final cloud in clouds) {
      _drawCloud(canvas, cloud.x, cloud.y, cloud.radius);
    }

    // ── Pipes ─────────────────────────────────────────────────────────────
    for (final pipe in pipes) {
      _drawPipe(canvas, pipe, h, gapHeight);
    }

    // ── Ground ────────────────────────────────────────────────────────────
    _drawGround(canvas, w, h, groundOffset);

    // ── Bird ─────────────────────────────────────────────────────────────
    final birdX = w * _kBirdXRel;
    _drawBird(canvas, birdX, birdY, birdVy, isDead, wingPhase);

    // Score is shown in the HUD pill overlay, not on canvas.
  }

  void _drawCloud(Canvas canvas, double cx, double cy, double radius) {
    final r = radius;

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(cx + 3, cy + 5), r * 0.8, shadowPaint);

    // Bottom/base layer — slightly grey-tinted for 3D depth
    final greyPaint = Paint()
      ..color = const Color(0xFFE8F4F8).withValues(alpha: 0.70);
    canvas.drawCircle(
        Offset(cx, cy + r * 0.3), r * 0.75, greyPaint);
    canvas.drawCircle(
        Offset(cx + r * 0.6, cy + r * 0.25), r * 0.6, greyPaint);
    canvas.drawCircle(
        Offset(cx - r * 0.6, cy + r * 0.25), r * 0.55, greyPaint);

    // Top white puffs — main cloud body
    final whitePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(cx, cy), r, whitePaint);
    canvas.drawCircle(
        Offset(cx + r * 0.65, cy + r * 0.1), r * 0.7, whitePaint);
    canvas.drawCircle(
        Offset(cx - r * 0.6, cy + r * 0.15), r * 0.65, whitePaint);

    // Top highlights — brighter puffs for 3D look
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95);
    canvas.drawCircle(
        Offset(cx + r * 0.2, cy - r * 0.3), r * 0.55, highlightPaint);
    canvas.drawCircle(
        Offset(cx - r * 0.2, cy - r * 0.2), r * 0.5, highlightPaint);
  }

  void _drawPipe(Canvas canvas, _Pipe pipe, double h, double gapH) {
    final playH = h - _kGroundH;
    final gapTop    = pipe.gapCenterY - gapH / 2;
    final gapBottom = pipe.gapCenterY + gapH / 2;

    const capH     = 22.0;
    const capExtra = 5.0;

    // Pipe body gradient paint (3D left-lighter, right-darker effect)
    final bodyRect = Rect.fromLTRB(
        pipe.x, 0, pipe.x + _kPipeWidth, h);
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: const [Color(0xFF66BB6A), _kPipeColor, Color(0xFF2E7D32)],
        stops: const [0.0, 0.45, 1.0],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bodyRect);

    final capPaint = Paint()..color = _kPipeDark;
    final capBorderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Top pipe body
    if (gapTop > 0) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(pipe.x, 0, pipe.x + _kPipeWidth, gapTop),
          bottomLeft: const Radius.circular(4),
          bottomRight: const Radius.circular(4),
        ),
        bodyPaint,
      );
      // Top pipe cap
      final topCapRect = Rect.fromLTRB(
        pipe.x - capExtra, gapTop - capH,
        pipe.x + _kPipeWidth + capExtra, gapTop,
      );
      final topCapRRect = RRect.fromRectAndRadius(
          topCapRect, const Radius.circular(5));
      canvas.drawRRect(topCapRRect, capPaint);
      canvas.drawRRect(topCapRRect, capBorderPaint);
    }

    // Bottom pipe body
    if (gapBottom < playH) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(pipe.x, gapBottom, pipe.x + _kPipeWidth, playH),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        bodyPaint,
      );
      // Bottom pipe cap
      final botCapRect = Rect.fromLTRB(
        pipe.x - capExtra, gapBottom,
        pipe.x + _kPipeWidth + capExtra, gapBottom + capH,
      );
      final botCapRRect = RRect.fromRectAndRadius(
          botCapRect, const Radius.circular(5));
      canvas.drawRRect(botCapRRect, capPaint);
      canvas.drawRRect(botCapRRect, capBorderPaint);
    }

    // Highlight stripe on each pipe body
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (gapTop > 20) {
      canvas.drawLine(
        Offset(pipe.x + 10, 8),
        Offset(pipe.x + 10, gapTop - capH - 4),
        highlightPaint,
      );
    }
    if (gapBottom < playH - 20) {
      canvas.drawLine(
        Offset(pipe.x + 10, gapBottom + capH + 4),
        Offset(pipe.x + 10, playH - 4),
        highlightPaint,
      );
    }
  }

  void _drawGround(Canvas canvas, double w, double h, double groundOffset) {
    final groundTop = h - _kGroundH;

    // Brown ground base
    canvas.drawRect(
      Rect.fromLTRB(0, groundTop, w, h),
      Paint()..color = _kGroundBr,
    );

    // Grass strip at top of ground
    canvas.drawRect(
      Rect.fromLTRB(0, groundTop, w, groundTop + 10),
      Paint()..color = _kGrassGr,
    );

    // Scrolling dirt detail dashes
    final dirtPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.10)
      ..strokeWidth = 1.5;
    const tileW = 60.0;
    final startX = -(groundOffset % tileW);
    for (double x = startX; x < w; x += tileW) {
      canvas.drawLine(
        Offset(x + 8, groundTop + 18),
        Offset(x + 26, groundTop + 18),
        dirtPaint,
      );
      // Stone oval
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + 42, groundTop + 26),
          width: 12,
          height: 7,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.06),
      );
    }
  }

  void _drawBird(Canvas canvas, double cx, double cy, double vy,
      bool isDead, double wingPhase) {
    final r = _kBirdRadius;

    // Tilt: dead bird points beak down; alive tilts with velocity
    final tilt = isDead
        ? math.pi / 2
        : (vy / 500.0).clamp(-0.4, 0.7);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(tilt);

    // Shadow below bird
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(4, r * 0.8),
        width: r * 1.8,
        height: r * 0.6,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );

    // Body — golden yellow oval (wider than tall like a real bird)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: r * 2.2,
        height: r * 2.0,
      ),
      Paint()..color = const Color(0xFFFFD700),
    );

    // Belly highlight
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(3, 4),
        width: r * 1.4,
        height: r * 1.2,
      ),
      Paint()..color = const Color(0xFFFFF0A0),
    );

    // Wing — animated up/down
    final wingY = -4.0 - 8.0 * math.sin(wingPhase);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-4, wingY),
        width: r * 1.4,
        height: r * 0.7,
      ),
      Paint()..color = const Color(0xFFE6B800),
    );

    // Eye white
    canvas.drawCircle(
      Offset(r * 0.5, -r * 0.25),
      r * 0.32,
      Paint()..color = Colors.white,
    );
    // Pupil
    canvas.drawCircle(
      Offset(r * 0.55, -r * 0.22),
      r * 0.16,
      Paint()..color = const Color(0xFF1A1A2E),
    );
    // Shine
    canvas.drawCircle(
      Offset(r * 0.60, -r * 0.30),
      r * 0.07,
      Paint()..color = Colors.white,
    );

    // Tail feathers (left side of bird)
    final tailPath = Path()
      ..moveTo(-r * 0.85, 0)
      ..lineTo(-r * 1.6, -r * 0.35)
      ..lineTo(-r * 1.35, r * 0.20)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = const Color(0xFFE6B800));
    // Second tail feather (slightly offset for depth)
    final tailPath2 = Path()
      ..moveTo(-r * 0.80, r * 0.10)
      ..lineTo(-r * 1.5, r * 0.45)
      ..lineTo(-r * 1.15, r * 0.55)
      ..close();
    canvas.drawPath(tailPath2, Paint()..color = const Color(0xFFD4A000));

    // Beak
    final beakPath = Path()
      ..moveTo(r * 0.7, 0)
      ..lineTo(r * 1.3, -r * 0.12)
      ..lineTo(r * 1.3, r * 0.18)
      ..close();
    canvas.drawPath(beakPath, Paint()..color = const Color(0xFFFF8C00));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FlappyPainter old) =>
      old.birdY != birdY ||
      old.birdVy != birdVy ||
      old.pipes != pipes ||
      old.clouds != clouds ||
      old.score != score ||
      old.wingPhase != wingPhase ||
      old.groundOffset != groundOffset ||
      old.isDead != isDead;
}

// ════════════════════════════════════════════════════════════════
// PICKER ANIMATED BACKGROUND — drifting clouds + mini birds
// ════════════════════════════════════════════════════════════════

class _FlappyBgPainter extends AnimatedBgPainter {
  const _FlappyBgPainter(super.t);

  // Clouds: [xFrac, yFrac, radiusFrac, speedFrac]
  static const _clouds = [
    [0.10, 0.12, 0.09, 0.08],
    [0.55, 0.07, 0.07, 0.05],
    [0.80, 0.20, 0.10, 0.06],
    [0.30, 0.28, 0.06, 0.09],
    [0.70, 0.35, 0.08, 0.04],
  ];

  // Mini birds: [xFrac, yFrac, ampFrac, speedFrac, phaseFrac]
  // Keep y in the top 40% so birds are visible above the picker card.
  static const _birds = [
    [0.10, 0.32, 0.03, 0.12, 0.0],
    [0.75, 0.20, 0.025, 0.08, 0.5],
    [0.50, 0.38, 0.025, 0.10, 0.3],
  ];

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;

    // Moving clouds
    for (final c in _clouds) {
      final xBase = c[0];
      final y = c[1] * h;
      final r = c[2] * w;
      final speed = c[3];
      // x drifts right → left, wraps
      final x = ((xBase + speed * t) % 1.2 - 0.1) * w;
      _drawCloud(canvas, x, y, r);
    }

    // Mini drifting birds
    for (final b in _birds) {
      final xBase = b[0];
      final yBase = b[1] * h;
      final amp = b[2] * h;
      final speed = b[3];
      final phase = b[4] * math.pi * 2;
      final x = ((xBase + speed * t) % 1.1 - 0.05) * w;
      final y = yBase + amp * math.sin(t * math.pi * 2 + phase);
      _drawMiniBird(canvas, x, y, w * 0.038);
    }
  }

  void _drawCloud(Canvas canvas, double cx, double cy, double r) {
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(cx + 2, cy + 4), r * 0.8, shadow);

    final grey = Paint()..color = const Color(0xFFE8F4F8).withValues(alpha: 0.60);
    canvas.drawCircle(Offset(cx, cy + r * 0.28), r * 0.72, grey);
    canvas.drawCircle(Offset(cx + r * 0.58, cy + r * 0.22), r * 0.58, grey);
    canvas.drawCircle(Offset(cx - r * 0.58, cy + r * 0.22), r * 0.52, grey);

    final white = Paint()..color = Colors.white.withValues(alpha: 0.80);
    canvas.drawCircle(Offset(cx, cy), r, white);
    canvas.drawCircle(Offset(cx + r * 0.62, cy + r * 0.08), r * 0.68, white);
    canvas.drawCircle(Offset(cx - r * 0.58, cy + r * 0.12), r * 0.62, white);
    canvas.drawCircle(Offset(cx + r * 0.18, cy - r * 0.28), r * 0.52, white);
  }

  void _drawMiniBird(Canvas canvas, double cx, double cy, double r) {
    // Body
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: r * 2.2, height: r * 2.0),
      Paint()..color = const Color(0xFFFFD700).withValues(alpha: 0.70),
    );
    // Wing
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - r * 0.2, cy - r * 0.2),
          width: r * 1.4, height: r * 0.65),
      Paint()..color = const Color(0xFFE6B800).withValues(alpha: 0.70),
    );
    // Eye
    canvas.drawCircle(Offset(cx + r * 0.45, cy - r * 0.20), r * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.90));
    canvas.drawCircle(Offset(cx + r * 0.48, cy - r * 0.18), r * 0.11,
        Paint()..color = const Color(0xFF1A1A2E).withValues(alpha: 0.80));
    // Beak
    final beak = Path()
      ..moveTo(cx + r * 0.70, cy)
      ..lineTo(cx + r * 1.20, cy - r * 0.10)
      ..lineTo(cx + r * 1.20, cy + r * 0.16)
      ..close();
    canvas.drawPath(beak,
        Paint()..color = const Color(0xFFFF8C00).withValues(alpha: 0.75));
  }
}
